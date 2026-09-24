using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Windows.Forms;

[assembly: AssemblyTitle("Codex Quota Widget")]
[assembly: AssemblyProduct("Codex Quota Widget")]
[assembly: AssemblyDescription("Windows launcher for the Codex quota widget")]
[assembly: AssemblyVersion("0.1.1.0")]

internal static class WidgetLauncher
{
    [STAThread]
    private static void Main()
    {
        try
        {
            string directory = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "CodexQuotaWidget");
            Directory.CreateDirectory(directory);
            WriteResource("WidgetScript", Path.Combine(directory, "CodexQuotaWidget.ps1"));
            WriteResource("WidgetData", Path.Combine(directory, "data.js"));
            WriteResource("WidgetIcon", Path.Combine(directory, "CodexQuotaWidget.ico"));

            string settings = Path.Combine(directory, "settings.json");
            string previousSettings = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "settings.json");
            if (!File.Exists(settings) && File.Exists(previousSettings))
                File.Copy(previousSettings, settings);

            string script = Path.Combine(directory, "CodexQuotaWidget.ps1");
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

    private static void WriteResource(string name, string destination)
    {
        byte[] bytes;
        using (Stream stream = Assembly.GetExecutingAssembly().GetManifestResourceStream(name))
        {
            if (stream == null) throw new InvalidOperationException("缺少内置文件：" + name);
            using (var memory = new MemoryStream())
            {
                stream.CopyTo(memory);
                bytes = memory.ToArray();
            }
        }

        if (File.Exists(destination) && File.ReadAllBytes(destination).SequenceEqual(bytes)) return;
        string temporary = destination + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            File.WriteAllBytes(temporary, bytes);
            if (File.Exists(destination)) File.Replace(temporary, destination, null);
            else File.Move(temporary, destination);
        }
        finally
        {
            if (File.Exists(temporary)) File.Delete(temporary);
        }
    }
}
