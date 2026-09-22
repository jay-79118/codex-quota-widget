using System.Diagnostics;
using System.Globalization;
using System.Text.Json;

namespace CodexQuotaBoard;

internal sealed record QuotaSnapshot(
    string FiveHourPercent,
    string FiveHourReset,
    string WeeklyPercent,
    string WeeklyReset,
    string Status)
{
    internal static QuotaSnapshot Loading { get; } = new("—", "正在读取", "—", "正在读取", "正在读取额度…");

    internal static QuotaSnapshot Error { get; } = new("—", "暂不可用", "—", "暂不可用", "读取失败，请点击刷新");

    internal string ToDataJson() => JsonSerializer.Serialize(new
    {
        fiveHourPercent = FiveHourPercent,
        fiveHourReset = FiveHourReset,
        weeklyPercent = WeeklyPercent,
        weeklyReset = WeeklyReset,
        status = Status
    });

    internal static QuotaSnapshot FromResponse(JsonElement result)
    {
        if (result.ValueKind != JsonValueKind.Object) return Error;
        JsonElement limits = default;
        if (result.TryGetProperty("rateLimitsByLimitId", out var buckets) &&
            buckets.ValueKind == JsonValueKind.Object &&
            buckets.TryGetProperty("codex", out var codex))
            limits = codex;
        else if (result.TryGetProperty("rateLimits", out var fallback))
            limits = fallback;

        if (limits.ValueKind != JsonValueKind.Object ||
            (!limits.TryGetProperty("primary", out _) &&
             !limits.TryGetProperty("secondary", out _))) return Error;

        var (fivePercent, fiveReset) = ReadWindow(limits, "primary");
        var (weekPercent, weekReset) = ReadWindow(limits, "secondary");
        return new(fivePercent, fiveReset, weekPercent, weekReset,
            DateTime.Now.ToString("HH:mm", CultureInfo.CurrentCulture) + " 更新");
    }

    private static (string Percent, string Reset) ReadWindow(JsonElement limits, string name)
    {
        if (limits.ValueKind != JsonValueKind.Object ||
            !limits.TryGetProperty(name, out var window) ||
            !window.TryGetProperty("usedPercent", out var used) ||
            !used.TryGetDouble(out var usedValue)) return ("—", "恢复时间未知");

        string percent = Math.Clamp(100 - usedValue, 0, 100).ToString("0", CultureInfo.InvariantCulture) + "%";
        string reset = "恢复时间未知";
        if (window.TryGetProperty("resetsAt", out var epoch) && epoch.TryGetInt64(out long seconds))
        {
            try { reset = DateTimeOffset.FromUnixTimeSeconds(seconds).ToLocalTime().ToString("M/d HH:mm"); }
            catch (ArgumentOutOfRangeException) { }
        }
        return (percent, reset);
    }
}

internal static class QuotaReader
{
    internal static async Task<QuotaSnapshot> ReadAsync()
    {
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(12));
        using var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = FindCodex(),
                Arguments = "app-server --stdio",
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardInput = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            }
        };
        try
        {
            if (!process.Start()) return QuotaSnapshot.Error;
            process.StandardInput.AutoFlush = true;
            _ = process.StandardError.ReadToEndAsync();
            await process.StandardInput.WriteLineAsync("{\"method\":\"initialize\",\"id\":1,\"params\":{\"clientInfo\":{\"name\":\"codex-quota-board\",\"version\":\"0.1.0\"}}");

            while (true)
            {
                string? line = await process.StandardOutput.ReadLineAsync(timeout.Token);
                if (line is null) return QuotaSnapshot.Error;
                JsonDocument message;
                try { message = JsonDocument.Parse(line); }
                catch (JsonException) { continue; }
                using (message)
                {
                    JsonElement root = message.RootElement;
                    if (!root.TryGetProperty("id", out var id) || id.ValueKind != JsonValueKind.Number) continue;
                    if (id.GetInt32() == 1)
                    {
                        if (root.TryGetProperty("error", out _)) return QuotaSnapshot.Error;
                        await process.StandardInput.WriteLineAsync("{\"method\":\"initialized\",\"params\":{}}");
                        await process.StandardInput.WriteLineAsync("{\"method\":\"account/rateLimits/read\",\"id\":2}");
                    }
                    else if (id.GetInt32() == 2)
                    {
                        if (root.TryGetProperty("error", out _) || !root.TryGetProperty("result", out var result))
                            return QuotaSnapshot.Error;
                        return QuotaSnapshot.FromResponse(result);
                    }
                }
            }
        }
        catch (Exception) { return QuotaSnapshot.Error; }
        finally
        {
            try { if (!process.HasExited) process.Kill(entireProcessTree: true); }
            catch (Exception) { }
        }
    }

    private static string FindCodex()
    {
        string root = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "OpenAI", "Codex", "bin");
        try
        {
            return Directory.EnumerateDirectories(root)
                .Select(directory => Path.Combine(directory, "codex.exe"))
                .Where(File.Exists)
                .OrderByDescending(File.GetLastWriteTimeUtc)
                .FirstOrDefault() ?? "codex";
        }
        catch (IOException) { return "codex"; }
        catch (UnauthorizedAccessException) { return "codex"; }
    }
}
