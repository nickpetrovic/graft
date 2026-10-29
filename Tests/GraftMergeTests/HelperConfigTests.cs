using System.Text.Json;

namespace GraftMerge.Tests;

public class HelperConfigTests
{
    private static HelperConfig Load(string json)
    {
        var path = Path.Combine(Path.GetTempPath(), $"graft-config-{Guid.NewGuid():N}.json");
        File.WriteAllText(path, json);
        try {
            return HelperConfig.Load(path);
        }
        finally {
            File.Delete(path);
        }
    }

    [Fact]
    public void ListingModsNeedsNoGameFiles()
    {
        var config = Load("""{"dataFolder": "/tmp/graft", "keysFolder": "", "baseGame": "", "update": ""}""");

        Assert.Equal("USen", config.Language);
        var error = Assert.Throws<HelperException>(config.RequireGameFiles);
        Assert.Contains("the keys folder, the base game file, the update file", error.Message);
    }

    [Fact]
    public void ReadsEveryField()
    {
        var config = Load("""
            {"dataFolder": "/tmp/graft", "keysFolder": "/keys", "baseGame": "/base.xci", "update": "/update.nsp",
             "language": "EUfr", "titleText": "Mods", "gameName": "Tears of the Kingdom",
             "otherGames": [{"name": "Breath of the Wild", "extensions": [".sbactorpack"], "folders": ["Actor/Pack/"]}],
             "setup": [{"id": "m1", "enabled": false, "options": {"FPS": ["60"], "Extras": []}}]}
            """);

        config.RequireGameFiles();
        Assert.Equal("EUfr", config.Language);
        Assert.Equal("Mods", config.TitleText);
        var other = Assert.Single(config.OtherGames);
        Assert.True(other.Matches("Actor/Pack/Enemy.sbactorpack"));
        var entry = Assert.Single(config.Setup ?? []);
        Assert.Equal("m1", entry.Id);
        Assert.False(entry.Enabled);
        Assert.Equal(["60"], entry.Options?["FPS"]);
        Assert.Empty(entry.Options?["Extras"] ?? ["missing"]);
    }

    [Fact]
    public void MissingDataFolderIsReported()
    {
        Assert.Throws<HelperException>(() => Load("""{"keysFolder": "/keys"}"""));
        Assert.Throws<HelperException>(() => Load("not json"));
    }

    [Fact]
    public void MessagesUseCamelCaseNames()
    {
        var json = JsonSerializer.Serialize(new IgnoredCode("id", "Mod", 1, 2), HelperJson.Default.IgnoredCode);

        Assert.Equal("""{"modId":"id","modName":"Mod","subSdkFiles":1,"patchesForOtherBuilds":2}""", json);
    }
}
