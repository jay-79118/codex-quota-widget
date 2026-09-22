using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

[assembly: AssemblyTitle("Codex Quota Widget")]
[assembly: AssemblyProduct("Codex Quota Widget")]
[assembly: AssemblyDescription("Windows launcher for the Codex quota widget")]
[assembly: AssemblyVersion("0.1.0.0")]

internal static class WidgetLauncher
{
    [STAThread]
    private static void Main()
    {
        try
        {
            string directory = AppDomain.CurrentDomain.BaseDirectory;
            string script = Path.Combine(directory, "CodexQuotaWidget.ps1");
            string data = Path.Combine(directory, "data.js");
            if (!File.Exists(script) || !File.Exists(data))
            {
                MessageBox.Show(
                    "请将 CodexQuotaWidget.exe、CodexQuotaWidget.ps1 和 data.js 放在同一文件夹。",
                    "Codex 额度小组件", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }

            string powershell = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.System),
                @"WindowsPowerShell\v1.0\powershell.exe");
            var start = new ProcessStartInfo
            {
                FileName = powershell,
                Arguments = "-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + script + "\"",
                WorkingDirectory = directory,
                UseShellExecute = false,
                CreateNoWindow = true,
                WindowStyle = ProcessWindowStyle.Hidden
            };
            Process process = Process.Start(start);
            if (process == null) throw new InvalidOperationException("PowerShell 启动失败。");
            process.Dispose();
        }
        catch (Exception error)
        {
            MessageBox.Show("启动失败：" + error.Message,
                "Codex 额度小组件", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}
