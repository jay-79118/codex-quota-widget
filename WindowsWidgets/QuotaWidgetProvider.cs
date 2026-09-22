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
    private static readonly Timer RefreshTimer = new(_ => _ = RefreshAllAsync(), null,
        Timeout.InfiniteTimeSpan, Timeout.InfiniteTimeSpan);
    private static readonly string Template = File.ReadAllText(
        Path.Combine(AppContext.BaseDirectory, "Templates", "QuotaCard.json"));
    private static QuotaSnapshot snapshot = QuotaSnapshot.Loading;

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
                if (Widgets.Count > 0) RefreshTimer.Change(TimeSpan.FromMinutes(1), TimeSpan.FromMinutes(1));
            }
        }
        catch (Exception error) { Trace.WriteLine(error); }
    }

    public void CreateWidget(WidgetContext context)
    {
        if (context.DefinitionId != DefinitionId) return;
        lock (Gate)
        {
            Widgets.Add(context.Id);
            RefreshTimer.Change(TimeSpan.FromMinutes(1), TimeSpan.FromMinutes(1));
        }
        SendUpdate(context.Id);
        _ = RefreshAllAsync();
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
        _ = RefreshAllAsync();
    }

    public void Deactivate(string widgetId) { }

    public void OnWidgetContextChanged(WidgetContextChangedArgs args) => SendUpdate(args.WidgetContext.Id);

    public void OnActionInvoked(WidgetActionInvokedArgs args)
    {
        if (args.Verb == "refresh") _ = RefreshAllAsync();
    }

    private static async Task RefreshAllAsync()
    {
        if (!await RefreshGate.WaitAsync(0)) return;
        try
        {
            snapshot = await QuotaReader.ReadAsync();
            string[] ids;
            lock (Gate) ids = Widgets.ToArray();
            foreach (string id in ids) SendUpdate(id);
        }
        catch (Exception error) { Trace.WriteLine(error); }
        finally { RefreshGate.Release(); }
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
        catch (Exception error) { Trace.WriteLine(error); }
    }
}
