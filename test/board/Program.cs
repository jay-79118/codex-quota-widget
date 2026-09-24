using System.Text.Json;
using CodexQuotaBoard;

static void Require(bool condition, string message)
{
    if (!condition) throw new Exception(message);
}

using var fixtures = JsonDocument.Parse(File.ReadAllText(
    Path.Combine(AppContext.BaseDirectory, "quota-responses.json")));
var samples = fixtures.RootElement;
var good = QuotaSnapshot.FromResponse(samples.GetProperty("named"));
Require(good.FailureCode is null, "Valid quota response was rejected");
Require(good.FiveHourPercent == "75%" && good.WeeklyPercent == "40%",
    "Remaining percentages were calculated incorrectly");
Require(good.FiveHourResetAt == 1790000000 && good.WeeklyResetAt == 1790500000,
    "Reset timestamps were not preserved");
var stale = (good with
{
    CheckedAt = DateTimeOffset.UtcNow.AddMinutes(-2).ToUnixTimeMilliseconds(),
    FiveHourResetAt = 1,
    WeeklyResetAt = DateTimeOffset.UtcNow.AddDays(1).ToUnixTimeSeconds()
}).AsStale("读取超时");
Require(stale.FiveHourPercent == "—" && stale.WeeklyPercent == "40%" &&
    stale.Status.Contains("读取超时"), "Expired cached quota was displayed as current");

var fallback = QuotaSnapshot.FromResponse(samples.GetProperty("fallback"));
Require(fallback.FailureCode is null && fallback.FiveHourPercent == "0%" &&
    fallback.WeeklyPercent == "100%", "Legacy response or bounds failed");
var nullNamedFallback = QuotaSnapshot.FromResponse(samples.GetProperty("nullNamedFallback"));
Require(nullNamedFallback.FailureCode is null && nullNamedFallback.FiveHourPercent == "75%" &&
    nullNamedFallback.FiveHourResetAt == 0,
    "Null named bucket or malformed reset timestamp was not handled");

Require(QuotaSnapshot.FromResponse(samples.GetProperty("missing")).FailureCode == "missing-limits",
    "Missing buckets were not diagnosed");
Require(QuotaSnapshot.FromResponse(samples.GetProperty("partial")).FailureCode == "incomplete-limits",
    "Partial quota was not diagnosed");
Require(QuotaSnapshot.FromResponse(samples.GetProperty("malformed")).FailureCode == "incomplete-limits",
    "Malformed nested quota was not diagnosed");
Require(QuotaSnapshot.FromResponse(samples.GetProperty("invalid")).FailureCode == "invalid-result",
    "Invalid root was not diagnosed");

using (var document = JsonDocument.Parse("""
    {"error":{"code":"AUTH_REQUIRED","message":"private details must not be logged"}}
    """))
    Require(QuotaReader.ProtocolErrorCode(document.RootElement, "quota-rejected") ==
        "quota-rejected:AUTH_REQUIRED", "Safe protocol error code was lost");
using (var document = JsonDocument.Parse("""
    {"error":{"code":"unsafe/secret","message":"private details must not be logged"}}
    """))
    Require(QuotaReader.ProtocolErrorCode(document.RootElement, "quota-rejected") ==
        "quota-rejected", "Unsafe protocol error code reached diagnostics");

Console.WriteLine("Board quota parser passed");
