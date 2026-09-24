// Compile-only stand-ins for Windows App SDK types. The real package build is a separate CI step.
namespace Microsoft.Windows.Widgets.Providers;

public interface IWidgetProvider
{
    void CreateWidget(WidgetContext context);
    void DeleteWidget(string widgetId, string customState);
    void Activate(WidgetContext context);
    void Deactivate(string widgetId);
    void OnWidgetContextChanged(WidgetContextChangedArgs args);
    void OnActionInvoked(WidgetActionInvokedArgs args);
}

public sealed class WidgetContext
{
    public string Id { get; init; } = "test";
    public string DefinitionId { get; init; } = "CodexQuotaWidget";
}

public sealed class WidgetInfo
{
    public WidgetContext WidgetContext { get; init; } = new();
}

public sealed class WidgetContextChangedArgs
{
    public WidgetContext WidgetContext { get; init; } = new();
}

public sealed class WidgetActionInvokedArgs
{
    public string Verb { get; init; } = "";
}

public sealed class WidgetUpdateRequestOptions(string id)
{
    public string Id { get; } = id;
    public string? Template { get; set; }
    public string? Data { get; set; }
}

public sealed class WidgetManager
{
    public static WidgetManager GetDefault() => new();
    public IReadOnlyList<WidgetInfo> GetWidgetInfos() => [];
    public void UpdateWidget(WidgetUpdateRequestOptions options) { }
}
