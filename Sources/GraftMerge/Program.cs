using System.Text.Json;
using GraftMerge;
using TkSharp.Core;

var configIndex = Array.IndexOf(args, "--config");
if (configIndex < 0 || configIndex + 1 >= args.Length || args.Length < 3) {
    Console.Error.WriteLine("usage: graft-merge --config <config.json> <list|install|uninstall|merge|read-patch|identify-updates> [arguments]");
    return 2;
}

var configPath = args[configIndex + 1];
var rest = args.Where((_, index) => index != configIndex && index != configIndex + 1).ToArray();

TkLog.Instance.Register(new StderrLogger());
using var stdout = Console.OpenStandardOutput();

try {
    var config = HelperConfig.Load(configPath);
    var result = await Commands.Run(rest[0], rest[1..], config);
    if (StderrLogger.FirstError is { } error) {
        throw new HelperException(error);
    }

    Write(result);
    return 0;
}
catch (Exception ex) {
    if (ex is not HelperException) {
        StderrLogger.Event("error", ex.ToString());
    }

    Write(new HelperFailure(ex is HelperException ? ex.Message : $"{ex.GetType().Name}: {ex.Message}"));
    return 1;
}

void Write(object result)
{
    JsonSerializer.Serialize(stdout, result, result.GetType(), HelperJson.Default);
    stdout.WriteByte((byte)'\n');
}
