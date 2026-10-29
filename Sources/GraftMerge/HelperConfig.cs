using System.Text.Json;

namespace GraftMerge;

public sealed record HelperConfig(
    string DataFolder,
    string KeysFolder = "",
    string BaseGame = "",
    string Update = "",
    string Language = "USen",
    string TitleText = "",
    string GameName = "this game",
    IReadOnlyList<GameSignatures>? OtherGames = null,
    IReadOnlyList<SetupEntry>? Setup = null)
{
    public IReadOnlyList<GameSignatures> OtherGames { get; } = OtherGames ?? [];

    public static HelperConfig Load(string path)
    {
        HelperConfig? config;
        try {
            using var stream = File.OpenRead(path);
            config = JsonSerializer.Deserialize(stream, HelperJson.Default.HelperConfig);
        }
        catch (Exception ex) when (ex is IOException or JsonException or UnauthorizedAccessException) {
            throw new HelperException($"The configuration at {path} could not be read: {ex.Message}");
        }

        if (config is not { DataFolder.Length: > 0 }) {
            throw new HelperException($"The configuration at {path} has no data folder.");
        }

        return config;
    }

    public void RequireGameFiles()
    {
        var missing = new List<string>();
        if (KeysFolder.Length == 0) {
            missing.Add("the keys folder");
        }
        if (BaseGame.Length == 0) {
            missing.Add("the base game file");
        }
        if (Update.Length == 0) {
            missing.Add("the update file");
        }

        if (missing.Count > 0) {
            throw new HelperException($"Reading {GameName}'s files needs {string.Join(", ", missing)}. Choose the keys folder in Graft's Settings and the game files in Game Info.");
        }
    }
}
