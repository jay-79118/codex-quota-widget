using System.Diagnostics;
using System.ComponentModel;
using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace CodexQuotaBoard;

internal sealed record QuotaSnapshot(
    string FiveHourPercent,
    string FiveHourReset,
    string WeeklyPercent,
    string WeeklyReset,
    string Status,
    long CheckedAt = 0,
    long FiveHourResetAt = 0,
    long WeeklyResetAt = 0,
    string? FailureCode = null)
{
    internal static QuotaSnapshot Loading { get; } = new("—", "正在读取", "—", "正在读取", "正在读取额度…");

    internal static QuotaSnapshot Error { get; } = Failure("unknown", "读取失败，请点击刷新");

    internal static QuotaSnapshot Failure(string code, string message) =>
        new("—", "暂不可用", "—", "暂不可用", message, FailureCode: code);

    private static string CachePath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "CodexQuotaWidget", "board-quota-cache.json");

    internal static QuotaSnapshot? LoadLastGood()
    {
        try
        {
            var saved = JsonSerializer.Deserialize<QuotaSnapshot>(File.ReadAllText(CachePath));
            long now = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
            return saved is { CheckedAt: > 0 } && saved.CheckedAt <= now + 60_000 ? saved : null;
        }
        catch (Exception) { return null; }
    }

    internal void SaveLastGood()
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(CachePath)!);
            string temporary = CachePath + "." + Guid.NewGuid().ToString("N") + ".tmp";
            try
            {
                File.WriteAllText(temporary, JsonSerializer.Serialize(this));
                File.Move(temporary, CachePath, overwrite: true);
            }
            finally { if (File.Exists(temporary)) File.Delete(temporary); }
        }
        catch (Exception) { /* Cache failure must not hide fresh quota data. */ }
    }

    internal QuotaSnapshot AsStale(string reason)
    {
        long now = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        string checkedTime = DateTimeOffset.FromUnixTimeMilliseconds(CheckedAt)
            .ToLocalTime().ToString("M/d HH:mm", CultureInfo.CurrentCulture);
        return this with
        {
            FiveHourPercent = FiveHourResetAt > now ? FiveHourPercent : "—",
            FiveHourReset = FiveHourResetAt > now ? FiveHourReset : "恢复时间未知",
            WeeklyPercent = WeeklyResetAt > now ? WeeklyPercent : "—",
            WeeklyReset = WeeklyResetAt > now ? WeeklyReset : "恢复时间未知",
            Status = reason + " · 上次 " + checkedTime
        };
    }

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
        if (result.ValueKind != JsonValueKind.Object)
            return Failure("invalid-result", "额度响应格式异常");
        JsonElement limits = default;
        if (result.TryGetProperty("rateLimitsByLimitId", out var buckets) &&
            buckets.ValueKind == JsonValueKind.Object &&
            buckets.TryGetProperty("codex", out var codex) &&
            codex.ValueKind == JsonValueKind.Object)
            limits = codex;
        else if (result.TryGetProperty("rateLimits", out var fallback))
            limits = fallback;

        if (limits.ValueKind != JsonValueKind.Object ||
            (!limits.TryGetProperty("primary", out _) &&
             !limits.TryGetProperty("secondary", out _)))
            return Failure("missing-limits", "未找到 Codex 额度数据");

        var (fivePercent, fiveReset, fiveResetAt) = ReadWindow(limits, "primary");
        var (weekPercent, weekReset, weekResetAt) = ReadWindow(limits, "secondary");
        if (fivePercent == "—" || weekPercent == "—")
            return Failure("incomplete-limits", "五小时或一周额度不完整");
        return new(fivePercent, fiveReset, weekPercent, weekReset,
            DateTime.Now.ToString("HH:mm", CultureInfo.CurrentCulture) + " 更新",
            DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(), fiveResetAt, weekResetAt);
    }

    private static (string Percent, string Reset, long ResetAt) ReadWindow(JsonElement limits, string name)
    {
        if (limits.ValueKind != JsonValueKind.Object ||
            !limits.TryGetProperty(name, out var window) ||
            window.ValueKind != JsonValueKind.Object ||
            !window.TryGetProperty("usedPercent", out var used) ||
            used.ValueKind != JsonValueKind.Number ||
            !used.TryGetDouble(out var usedValue) || !double.IsFinite(usedValue))
            return ("—", "恢复时间未知", 0);

        string percent = Math.Clamp(100 - usedValue, 0, 100).ToString("0", CultureInfo.InvariantCulture) + "%";
        string reset = "恢复时间未知";
        long resetAt = 0;
        if (window.TryGetProperty("resetsAt", out var epoch) &&
            epoch.ValueKind == JsonValueKind.Number &&
            epoch.TryGetInt64(out long seconds))
        {
            try
            {
                reset = DateTimeOffset.FromUnixTimeSeconds(seconds).ToLocalTime().ToString("M/d HH:mm");
                resetAt = seconds;
            }
            catch (ArgumentOutOfRangeException) { }
        }
        return (percent, reset, resetAt);
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
            if (!process.Start())
                return QuotaSnapshot.Failure("launch-failed", "无法启动 Codex");
            process.StandardInput.AutoFlush = true;
            _ = process.StandardError.ReadToEndAsync();
            await WriteMessageAsync(process, new
            {
                method = "initialize",
                id = 1,
                @params = new
                {
                    clientInfo = new { name = "codex-quota-board", version = "0.1.5" }
                }
            });

            while (true)
            {
                string? line = await process.StandardOutput.ReadLineAsync(timeout.Token);
                if (line is null)
                    return QuotaSnapshot.Failure("codex-exited", "Codex 提前退出");
                JsonDocument message;
                try { message = JsonDocument.Parse(line); }
                catch (JsonException) { continue; }
                using (message)
                {
                    JsonElement root = message.RootElement;
                    if (root.ValueKind != JsonValueKind.Object ||
                        !root.TryGetProperty("id", out var id) ||
                        id.ValueKind != JsonValueKind.Number ||
                        !id.TryGetInt32(out int requestId)) continue;
                    if (requestId == 1)
                    {
                        if (root.TryGetProperty("error", out _))
                            return QuotaSnapshot.Failure(ProtocolErrorCode(root, "initialize-rejected"),
                                "Codex 初始化失败");
                        await WriteMessageAsync(process, new { method = "initialized", @params = new { } });
                        await WriteMessageAsync(process, new { method = "account/rateLimits/read", id = 2 });
                    }
                    else if (requestId == 2)
                    {
                        if (root.TryGetProperty("error", out _))
                            return QuotaSnapshot.Failure(ProtocolErrorCode(root, "quota-rejected"),
                                "Codex 额度查询失败");
                        if (!root.TryGetProperty("result", out var result))
                            return QuotaSnapshot.Failure("missing-result", "额度响应格式异常");
                        return QuotaSnapshot.FromResponse(result);
                    }
                }
            }
        }
        catch (OperationCanceledException)
        {
            return QuotaSnapshot.Failure("timeout", "读取超时，请点击刷新");
        }
        catch (Win32Exception error)
        {
            return error.NativeErrorCode switch
            {
                2 or 3 => QuotaSnapshot.Failure("codex-not-found", "未找到 Codex 程序"),
                5 => QuotaSnapshot.Failure("access-denied", "Codex 程序无法访问"),
                _ => QuotaSnapshot.Failure("launch-failed", "无法启动 Codex")
            };
        }
        catch (UnauthorizedAccessException)
        {
            return QuotaSnapshot.Failure("access-denied", "Codex 程序无法访问");
        }
        catch (Exception)
        {
            return QuotaSnapshot.Failure("unexpected", "读取异常，请点击刷新");
        }
        finally
        {
            try { if (!process.HasExited) process.Kill(entireProcessTree: true); }
            catch (Exception) { }
        }
    }

    private static Task WriteMessageAsync(Process process, object message) =>
        process.StandardInput.WriteLineAsync(JsonSerializer.Serialize(message));

    internal static string ProtocolErrorCode(JsonElement response, string prefix)
    {
        if (response.TryGetProperty("error", out var error) &&
            error.ValueKind == JsonValueKind.Object &&
            error.TryGetProperty("code", out var code) &&
            code.ValueKind == JsonValueKind.String)
        {
            string? value = code.GetString();
            if (value is { Length: > 0 and <= 48 } &&
                Regex.IsMatch(value, "^[A-Za-z0-9_.-]+$"))
                return prefix + ":" + value;
        }
        return prefix;
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
