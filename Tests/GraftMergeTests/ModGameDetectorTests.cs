
namespace GraftMerge.Tests;

public class ModGameDetectorTests
{
    private static readonly GameSignatures[] Others = [
        new("Breath of the Wild", [".sbactorpack", ".sbfres", ".srsizetable", ".sbyml"], ["Actor/Pack/", "Map/MainField/"]),
        new("Super Mario Odyssey", [".szs"], ["ObjectData/", "StageData/"]),
    ];

    private static string? Detect(GameSignatures[] others, (string, bool)[] files) => ModGameDetector.OtherGame(files, others);

    private static (string, bool)[] Unknown(params string[] paths) => paths.Select(path => (path, false)).ToArray();

    [Fact]
    public void BreathOfTheWildModsAreRecognized()
    {
        Assert.Equal("Breath of the Wild", Detect(Others, Unknown(
            "Actor/Pack/Weapon_Sword_001.sbactorpack",
            "Model/Weapon_Sword_001.sbfres",
            "System/Resource/ResourceSizeTable.product.srsizetable")));
    }

    [Fact]
    public void OdysseyModsAreRecognized()
    {
        Assert.Equal("Super Mario Odyssey", Detect(Others, Unknown(
            "ObjectData/Mario.szs",
            "StageData/CapWorldHomeStageMap.szs")));
    }

    [Fact]
    public void TearsOfTheKingdomModsPass()
    {
        Assert.Null(Detect(Others, [
            ("Component/ConditionParam/Player.game__component__ConditionParam.bgyml", true),
            ("AI/DriftRestore.module.ainb", false),
        ]));
        Assert.Null(Detect(Others, Unknown("AI/DriftRestore.module.ainb", "Pack/Actor/NewItem.pack")));
    }

    [Fact]
    public void ModsWithoutDataFilesPass()
    {
        Assert.Null(Detect(Others, []));
    }

    [Fact]
    public void OneStrayFileDoesNotRejectAMod()
    {
        Assert.Null(Detect(Others, Unknown("Pack/Actor/A.pack", "Pack/Actor/B.pack", "Pack/Actor/C.pack", "Old/leftover.sbyml")));
    }
}
