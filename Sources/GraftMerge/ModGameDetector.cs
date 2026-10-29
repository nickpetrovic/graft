namespace GraftMerge;

public sealed record GameSignatures(string Name, IReadOnlyList<string> Extensions, IReadOnlyList<string> Folders)
{
    public bool Matches(string path)
    {
        return Extensions.Any(extension => path.EndsWith(extension, StringComparison.OrdinalIgnoreCase))
            || Folders.Any(folder => path.StartsWith(folder, StringComparison.OrdinalIgnoreCase));
    }
}

public static class ModGameDetector
{
    public static string? OtherGame(IReadOnlyCollection<(string Path, bool KnownToGame)> files, IEnumerable<GameSignatures> otherGames)
    {
        if (files.Count == 0 || files.Any(file => file.KnownToGame)) {
            return null;
        }

        var paths = files.Select(file => file.Path.Replace('\\', '/').TrimStart('/')).ToArray();
        var threshold = Math.Max(1, (paths.Length + 1) / 2);
        return otherGames.FirstOrDefault(game => paths.Count(game.Matches) >= threshold)?.Name;
    }
}
