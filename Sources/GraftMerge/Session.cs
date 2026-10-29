using TkSharp;
using TkSharp.Core;
using TkSharp.Core.IO.Caching;
using TkSharp.Data.Embedded;
using TkSharp.Extensions.LibHac;
using TkSharp.Merging;

namespace GraftMerge;

public sealed class Session
{
    private readonly Lazy<GameFiles> _gameFiles;

    public HelperConfig Config { get; }

    public TkModManager Manager { get; }

    public TkExtensibleRomProvider RomProvider => _gameFiles.Value.RomProvider;

    public TkModReaderProvider Readers => _gameFiles.Value.Readers;

    public Session(HelperConfig config)
    {
        Config = config;
        Directory.CreateDirectory(config.DataFolder);
        Manager = TkModManager.Create(Path.Combine(config.DataFolder, "library"));
        Manager.CurrentProfile = Manager.GetCurrentProfile();
        _gameFiles = new Lazy<GameFiles>(OpenGameFiles);
    }

    private GameFiles OpenGameFiles()
    {
        Config.RequireGameFiles();

        using var checksums = TkEmbeddedDataSource.GetChecksumsBin();
        using var packFileLookup = TkEmbeddedDataSource.GetPackFileLookup();

        var romProvider = TkExtensibleRomProviderBuilder
            .Create(TkChecksums.FromStream(checksums), new TkPackFileLookup(packFileLookup))
            .WithKeysFolder(Config.KeysFolder)
            .WithPackagedBaseGame([Config.BaseGame])
            .WithPackagedUpdate([Config.Update])
            .WithExtractedGameDump([])
            .WithSdCard((string?)null)
            .WithNand([])
            .Build();

        TkChangelogBuilder.Init(romProvider, Config.DataFolder);
        return new GameFiles(romProvider, new TkModReaderProvider(Manager, romProvider));
    }

    private sealed record GameFiles(TkExtensibleRomProvider RomProvider, TkModReaderProvider Readers);
}
