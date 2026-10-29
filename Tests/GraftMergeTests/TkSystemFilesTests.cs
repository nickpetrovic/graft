using TkSharp.Core;

namespace GraftMerge.Tests;

public class TkSystemFilesTests
{
    [Theory]
    [InlineData("romfs/._Pack", true)]
    [InlineData("/Volumes/data/mods/Defogger/romfs/Env/._Fog.bgyml", true)]
    [InlineData("__MACOSX/romfs/Pack/Actor/Item.pack.zs", true)]
    [InlineData("romfs/.DS_Store", true)]
    [InlineData("exefs\\Thumbs.db", true)]
    [InlineData("romfs/Pack/Actor/Item.pack.zs", false)]
    [InlineData("exefs/main-1.2.1.pchtxt", false)]
    [InlineData("romfs/._", true)]
    public void MetadataFilesAreRecognized(string path, bool expected)
    {
        Assert.Equal(expected, TkSystemFiles.IsMetadata(path));
    }
}
