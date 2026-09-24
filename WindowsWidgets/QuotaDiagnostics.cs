using System.Text.Json;

namespace CodexQuotaBoard;

internal static class QuotaDiagnostics
{
    private const long MaxBytes = 128 * 1024;
    private static readonly object Gate = new();

    private static string LogPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "CodexQuotaWidget", "board-diagnostics.jsonl");

    internal static void Record(string action, string code, long durationMs = 0)
    {
        try
        {
            lock (Gate)
            {
                string path = LogPath;
                Directory.CreateDirectory(Path.GetDirectoryName(path)!);
                if (File.Exists(path) && new FileInfo(path).Length >= MaxBytes)
                    File.Move(path, path + ".old", overwrite: true);
                string line = JsonSerializer.Serialize(new
                {
                    utc = DateTimeOffset.UtcNow.ToString("O"),
                    action,
                    code,
                    durationMs
                });
                File.AppendAllText(path, line + Environment.NewLine);
            }
        }
        catch (Exception)
        {
            // Logging must not stop the widget from refreshing.
        }
    }
}
