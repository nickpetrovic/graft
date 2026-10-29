using System.Text.Json;
using Microsoft.Extensions.Logging;

namespace GraftMerge;

public sealed class StderrLogger : ILogger
{
    private static readonly Lock WriteLock = new();
    private static string? _firstError;
    private static string? _lastWarning;

    public static string? FirstError {
        get {
            lock (WriteLock) {
                return _firstError;
            }
        }
    }

    public static string? LastWarning {
        get {
            lock (WriteLock) {
                return _lastWarning;
            }
        }
    }

    public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;

    public bool IsEnabled(LogLevel logLevel) => logLevel >= LogLevel.Information;

    public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter)
    {
        if (!IsEnabled(logLevel)) {
            return;
        }

        var message = formatter(state, exception);
        var summary = message.Split('\n')[0].Trim() + (exception is null ? "" : $" {exception.Message}");
        lock (WriteLock) {
            if (logLevel >= LogLevel.Error) {
                _firstError ??= summary;
            }
            else if (logLevel == LogLevel.Warning) {
                _lastWarning = summary;
            }
        }

        Event(logLevel switch {
            LogLevel.Warning => "warning",
            LogLevel.Error or LogLevel.Critical => "error",
            _ => "info"
        }, message);
    }

    public static void Event(string kind, string message)
    {
        var line = JsonSerializer.SerializeToUtf8Bytes(new HelperEvent(kind, message), HelperJson.Default.HelperEvent);
        lock (WriteLock) {
            using var stderr = Console.OpenStandardError();
            stderr.Write(line);
            stderr.WriteByte((byte)'\n');
            stderr.Flush();
        }
    }
}
