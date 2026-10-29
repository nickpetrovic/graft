// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Graft",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "Graft", targets: ["GraftApp"]),
        .executable(name: "graft-cli", targets: ["GraftCLI"]),
    ],
    targets: [
        .target(
            name: "CCapstone",
            path: "vendor/capstone",
            sources: [
                "cs.c",
                "Mapping.c",
                "MCInst.c",
                "MCInstrDesc.c",
                "MCRegisterInfo.c",
                "SStream.c",
                "utils.c",
                "arch/AArch64/AArch64BaseInfo.c",
                "arch/AArch64/AArch64Disassembler.c",
                "arch/AArch64/AArch64InstPrinter.c",
                "arch/AArch64/AArch64Mapping.c",
                "arch/AArch64/AArch64Module.c",
            ],
            publicHeadersPath: "include/capstone",
            cSettings: [
                .define("CAPSTONE_HAS_ARM64"),
                .define("CAPSTONE_USE_SYS_DYN_MEM"),
                .headerSearchPath("include"),
                .headerSearchPath("."),
                .unsafeFlags(["-w"]),
            ]
        ),
        .target(
            name: "ModKit",
            dependencies: ["CCapstone"]
        ),
        .executableTarget(
            name: "GraftApp",
            dependencies: ["ModKit"]
        ),
        .executableTarget(
            name: "GraftCLI",
            dependencies: ["ModKit"]
        ),
        .testTarget(
            name: "ModKitTests",
            dependencies: ["ModKit"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "GraftAppTests",
            dependencies: ["GraftApp"]
        ),
    ]
)
