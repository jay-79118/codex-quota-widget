using WidgetHelper;

namespace CodexQuotaBoard;

internal static class Program
{
    [MTAThread]
    private static void Main(string[] args)
    {
        if (args.Length == 0 || args[0] != "-RegisterProcessAsComServer") return;

        WinRT.ComWrappersSupport.InitializeComWrappers();
        using var registration = RegistrationManager<QuotaWidgetProvider>.RegisterProvider();
        QuotaWidgetProvider.WaitForLastWidgetRemoval();
    }
}
