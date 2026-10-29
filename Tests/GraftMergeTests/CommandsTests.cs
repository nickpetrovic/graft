namespace GraftMerge.Tests;

public sealed class CommandsTests : IDisposable
{
    private readonly string _folder = Path.Combine(Path.GetTempPath(), $"graft-commands-{Guid.NewGuid():N}");

    public void Dispose()
    {
        if (Directory.Exists(_folder)) {
            Directory.Delete(_folder, recursive: true);
        }
    }

    private HelperConfig Config(IReadOnlyList<SetupEntry>? setup = null, string keysFolder = "") =>
        new(_folder, KeysFolder: keysFolder, Setup: setup);

    [Fact]
    public async Task AnEmptyLibraryListsNoMods()
    {
        var result = await Commands.Run("list", [], Config());

        Assert.Empty(Assert.IsType<ModList>(result).Mods);
    }

    [Fact]
    public async Task AMergeNeedsTheSetupForTheGameVersion()
    {
        var error = await Assert.ThrowsAsync<HelperException>(() => Commands.Run("merge", [Path.Combine(_folder, "merged")], Config()));

        Assert.Contains("mod setup", error.Message);
    }

    [Fact]
    public async Task ASetupThatNamesAModOutsideTheLibraryIsRefused()
    {
        var error = await Assert.ThrowsAsync<HelperException>(() =>
            Commands.Run("merge", [Path.Combine(_folder, "merged")], Config([new SetupEntry("missing", true, null)])));

        Assert.Contains("isn't in the library (missing)", error.Message);
    }

    [Fact]
    public async Task UnknownCommandsIdsAndMissingArgumentsAreReported()
    {
        Assert.Contains("Unknown command 'dance'", (await Assert.ThrowsAsync<HelperException>(() => Commands.Run("dance", [], Config()))).Message);
        Assert.Contains("'nope'", (await Assert.ThrowsAsync<HelperException>(() => Commands.Run("uninstall", ["nope"], Config()))).Message);
        Assert.Contains("Missing argument", (await Assert.ThrowsAsync<HelperException>(() => Commands.Run("install", [], Config()))).Message);
        Assert.Contains("does not exist", (await Assert.ThrowsAsync<HelperException>(() => Commands.Run("read-patch", [Path.Combine(_folder, "none.pchtxt")], Config()))).Message);
    }

    [Fact]
    public async Task IdentifyingUpdatesNeedsTheKeys()
    {
        Assert.Contains("Choose the keys folder", (await Assert.ThrowsAsync<HelperException>(() => Commands.Run("identify-updates", [], Config()))).Message);
        Assert.Contains("no prod.keys", (await Assert.ThrowsAsync<HelperException>(() => Commands.Run("identify-updates", [], Config(keysFolder: _folder)))).Message);
    }
}
