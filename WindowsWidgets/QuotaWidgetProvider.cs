using System.Diagnostics;
using System.Runtime.InteropServices;
using Microsoft.Windows.Widgets.Providers;

namespace CodexQuotaBoard;

[ComVisible(true)]
[ComDefaultInterface(typeof(IWidgetProvider))]
[Guid("D5BEB174-EA45-4756-87B3-00768D27287D")]
public sealed class QuotaWidgetProvider : IWidgetProvider
{
    private const string DefinitionId = "CodexQuotaWidget";
    private static readonly object Gate = new();
    private static readonly HashSet<string> Widgets = new();
    private static readonly SemaphoreSlim RefreshGate = new(1, 1);
    private static readonly ManualResetEvent LastWidgetRemoved = new(false);
    private static readonly Timer RefreshTimer = new(_ => RequestRefresh("timer"), null,
        Timeout.InfiniteTimeSpan, Timeout.InfiniteTimeSpan);
    private static int refreshPending;
    private static int consecutiveFailures;
    private static readonly string Template = File.ReadAllText(
        Path.Combine(AppContext.BaseDirectory, "Templates", "QuotaCard.json"));
    private static QuotaSnapshot? lastGood = QuotaSnapshot.LoadLastGood();
    private static QuotaSnapshot snapshot = lastGood?.AsStale("正在更新") ?? QuotaSnapshot.Loading;

    public QuotaWidgetProvider() => RecoverWidgets();

    internal static void WaitForLastWidgetRemoval() => LastWidgetRemoved.WaitOne();

    private static void RecoverWidgets()
    {
        try
        {
            foreach (var info in WidgetManager.GetDefault().GetWidgetInfos())
            {
                if (info.WidgetContext.DefinitionId != DefinitionId) continue;
                lock (Gate) Widgets.Add(info.WidgetContext.Id);
            }
            lock (Gate)
            {
                if (Widgets.Count > 0) RefreshTimer.Change(TimeSpan.FromMinutes(1), Timeout.InfiniteTimeSpan);
            }
        }
        catch (Exception error)
        {
            QuotaDiagnostics.Record("recover", error.GetType().Name);
        }
    }

    public void CreateWidget(WidgetContext context)
    {
        if (context.DefinitionId != DefinitionId) return;
        lock (Gate)
        {
            Widgets.Add(context.Id);
            RefreshTimer.Change(TimeSpan.FromMinutes(1), Timeout.InfiniteTimeSpan);
        }
        SendUpdate(context.Id);
        RequestRefresh("create");
    }

    public void DeleteWidget(string widgetId, string customState)
    {
        lock (Gate)
        {
            Widgets.Remove(widgetId);
            if (Widgets.Count == 0)
            {
                RefreshTimer.Change(Timeout.InfiniteTimeSpan, Timeout.InfiniteTimeSpan);
                LastWidgetRemoved.Set();
            }
        }
    }

    public void Activate(WidgetContext context)
    {
        lock (Gate) Widgets.Add(context.Id);
        SendUpdate(context.Id);
        RequestRefresh("activate");
    }

    public void Deactivate(string widgetId) { }

    public void OnWidgetContextChanged(WidgetContextChangedArgs args) => SendUpdate(args.WidgetContext.Id);

    public void OnActionInvoked(WidgetActionInvokedArgs args)
    {
        if (args.Verb == "refresh") RequestRefresh("manual");
    }

    private static void RequestRefresh(string source)
    {
        if (source == "manual") QuotaDiagnostics.Record("refresh-request", "manual");
        Interlocked.Exchange(ref refreshPending, 1);
        _ = DrainRefreshAsync();
    }

    private static async Task DrainRefreshAsync()
    {
        if (!await RefreshGate.WaitAsync(0)) return;
        try
        {
            while (Interlocked.Exchange(ref refreshPending, 0) != 0)
                await RefreshOnceAsync();
        }
        finally
        {
            RefreshGate.Release();
            if (Volatile.Read(ref refreshPending) != 0) _ = DrainRefreshAsync();
        }
    }

    private static async Task RefreshOnceAsync()
    {
        var watch = Stopwatch.StartNew();
        try
        {
            var latest = await QuotaReader.ReadAsync();
            if (latest.FailureCode is string code)
            {
                snapshot = lastGood?.AsStale(latest.Status) ?? latest;
                consecutiveFailures = Math.Min(consecutiveFailures + 1, 5);
                QuotaDiagnostics.Record("read", code, watch.ElapsedMilliseconds);
            }
            else
            {
                snapshot = latest;
                lastGood = latest;
                latest.SaveLastGood();
                consecutiveFailures = 0;
                QuotaDiagnostics.Record("read", "ok", watch.ElapsedMilliseconds);
            }
            string[] ids;
            lock (Gate) ids = Widgets.ToArray();
            foreach (string id in ids) SendUpdate(id);
        }
        catch (Exception error)
        {
            consecutiveFailures = Math.Min(consecutiveFailures + 1, 5);
            QuotaDiagnostics.Record("provider", error.GetType().Name, watch.ElapsedMilliseconds);
        }
        finally
        {
            int nextMinutes = consecutiveFailures == 0 ? 1 : Math.Min(16, 1 << consecutiveFailures);
            lock (Gate)
            {
                if (Widgets.Count > 0)
                    RefreshTimer.Change(TimeSpan.FromMinutes(nextMinutes), Timeout.InfiniteTimeSpan);
            }
        }
    }

    private static void SendUpdate(string id)
    {
        try
        {
            WidgetManager.GetDefault().UpdateWidget(new WidgetUpdateRequestOptions(id)
            {
                Template = Template,
                Data = snapshot.ToDataJson()
            });
        }
        catch (Exception error)
        {
            QuotaDiagnostics.Record("update", error.GetType().Name);
        }
    }
}
