# Building and contributing

## Prerequisites

1. A Mac with Apple silicon and macOS 26 or later.
2. The Command Line Tools for Xcode 26 or later, which include Swift 6.2 and the macOS 26 SDK: `xcode-select --install`. They include git, Swift, GNU Make and the signing tools the build uses. Full Xcode works too.
3. The .NET 10 SDK. The scripts use the first of `$DOTNET`, `~/.dotnet/dotnet` and `dotnet` on your `PATH` that has a 10.0 SDK, so an older .NET elsewhere doesn't get in the way. Run `make dotnet` to install it in `~/.dotnet` without admin rights. `Sources/GraftMerge/global.json` asks for SDK 10.0.100 or a later 10.0 release.
4. An internet connection for the first build, which fetches the `vendor/` submodules and the helper's NuGet packages.

## Make targets

The Makefile is the entry point. Each target runs one of the scripts in `scripts/`, which hold the actual steps.

| Target | What it does |
| :-- | :-- |
| `make` or `make build` | Runs `scripts/build.sh`: publishes the C# merge helper, builds the app in release mode, assembles `.build/app/Graft.app` and signs it ad hoc |
| `make test` | Runs `scripts/test.sh`: the C# tests, then the Swift tests. `make test FILTER=PatchAnalyzerTests` runs only the Swift tests whose names match |
| `make run` | Builds, then opens the app |
| `make install` | Builds, copies `Graft.app` to `APPDIR` (default `/Applications`) and links `graft` into `BINDIR` (default `~/.local/bin`), for example `make install APPDIR=~/Applications BINDIR=/usr/local/bin`. It stops if that copy of Graft is running |
| `make uninstall` | Removes the installed app and the `graft` link. Your games, mods and settings in `~/Library/Application Support/Graft` stay |
| `make clean` | Deletes the build output: `.build` and the C# `bin` and `obj` folders |
| `make dotnet` | Runs `scripts/install-dotnet.sh`, which installs the .NET 10 SDK in `~/.dotnet` with Microsoft's install script |
| `make icon` | Runs `scripts/make-icon.sh`, which draws the app icon with `scripts/draw-icon.swift` and writes `Resources/AppIcon.icns`; run it after changing the drawing |
| `make help` | Lists the targets and the install folders |

The Makefile works with the GNU Make 3.81 that comes with the Command Line Tools. The scripts also run on their own, and `scripts/test.sh` passes any arguments to `swift test`. `scripts/collect-licenses.sh` writes the license notices of the helper's packages and the .NET runtime into the app; `build.sh` runs it.

Both `build.sh` and `test.sh` first fetch the submodules if they are missing and apply Graft's TkSharp changes (`scripts/common.sh`). Run `make test` before you send a change; `make build` doesn't run the tests.

Two kinds of warnings are expected:

- A full build of TkSharp prints warning CS8785 from a code generator inside TkSharp. It comes from TkSharp itself and doesn't affect Graft.
- With the Command Line Tools, `swift build` and `swift test` print `ld: warning: search path '/Library/Developer/CommandLineTools/...' not found`. These come from SwiftPM and the Command Line Tools, not from Graft.

The Command Line Tools ship without SwiftUI's macro plugin, so the app spells `@State` as `@ViewState`, a type alias for the same property wrapper. The test script passes the Testing macro plugin's path when it exists.

## Updating

After `git pull`, run `make build` or `make test` as usual. If the pull moved a submodule to a new commit or changed a file in `vendor/patches/`, the scripts reset `vendor/TkSharp`, check out the right commit and apply the patches again. The scripts own `vendor/TkSharp`: edits made there by hand are discarded at that point.

## Opening the code in an IDE

Open the package folder in Xcode, or another editor with Swift support, for the app and ModKit. Open `Sources/GraftMerge/GraftMerge.slnx` for the C# helper and its tests. Run `make test` once first, because the helper builds only against the patched TkSharp.

## Running from source

After `make build` has built the merge helper once, you can run the app and the command-line tool straight from the package:

```sh
swift run Graft
swift run graft-cli list
```

The command-line tool's package product is named `graft-cli`, because `graft` and `Graft` would be the same file name on the Mac's case-insensitive disk. The build script names it `graft` inside the app.

Debug builds find the game templates in `Resources/Templates` and the merge helper in `.build/app/helper`. Release builds look only inside the app bundle.

Debug builds can also draw their windows to an image, which works without screen-recording permission:

```sh
swift run Graft --snapshot /tmp/main.png
swift run Graft --snapshot /tmp/options.png --snapshot-options "Hyrule Rebeautified"
swift run Graft --snapshot /tmp/large.png --snapshot-size 860x860 --snapshot-light
swift run Graft --snapshot /tmp/settings.png --snapshot-settings
swift run Graft --snapshot /tmp/inspector.png --snapshot-inspector
swift run Graft --snapshot /tmp/add.png --snapshot-add "/Applications/Some Port.app"
```

## Signing

Graft is signed ad hoc, without an Apple developer certificate, like the game apps MacNativeGames builds. A copy built on the Mac it runs on opens normally. A copy downloaded from the internet is blocked the first time; open System Settings ▸ Privacy & Security and click **Open Anyway**. macOS remembers permissions per signature, and an ad-hoc signature changes with every build.

## Changes to TkSharp

`vendor/patches/` holds two changes to the TkSharp submodule, applied by the scripts:

- `tksharp-patch-files.patch` replaces TkSharp's readers for `.pchtxt` and `.ips` code-patch files.
  - The original `.pchtxt` reader applies lines in `@disabled` sections, ignores values longer than 4 bytes, pads shorter values with zeros, and ignores `@flag offset_shift`.
  - The original `.ips` reader loses its place after any record that isn't 4 bytes long, and reads only the IPS32 format.
  - The new readers handle these cases, and also read classic IPS files and run-length records.
  - TkSharp stores code patches as 4-byte values, so a value whose length isn't a multiple of 4 can't be stored. Graft leaves those bytes out and says so when the mod is added.
  - `graft check-code` reads `.pchtxt` files through the helper (`graft-merge read-patch`), so it follows the same rules as merging.
- `tksharp-skip-system-files.patch` skips macOS and Windows system files inside mods: `._*`, `.DS_Store`, `__MACOSX`, `Thumbs.db` and `desktop.ini`. Mods copied from a non-Mac drive contain `._` files, which TkSharp otherwise fails on.

`.gitmodules` tells git to ignore these local changes in `vendor/TkSharp`. If a patch doesn't apply to the TkSharp commit in `vendor/TkSharp`, the scripts stop and name the patch; the patch then has to be updated for that commit.

## Tests

`make test` runs two test suites.

### Swift tests

The Swift tests are in `Tests/ModKitTests` and `Tests/GraftAppTests`.

The ModKit tests sit in folders that match `Sources/ModKit` (`Apply`, `Code`, `Engines`, `Game`, `Library`, `Support`), with one file for each type they test. They cover:

- code relocation and checks;
- applying mods with fake engines and build steps;
- both engines, with a stand-in helper script for the TkSharp engine;
- load orders for each version;
- game definitions, mod support settings, the game store, templates, suggestions and the game editor's checks;
- finding files, settings, setup checks, crash reports and the mod folder;
- the cache that reads definitions and templates again only when their files change.

The app tests cover window sizes, card dragging, the height of a mod's title line and the status text in Game Info.

The Swift tests read code patches as JSON (`Tests/ModKitTests/Fixtures/*.json`). Each file is the output of `graft-merge read-patch` for the `.pchtxt` file with the same name in the helper's fixtures.

### C# tests

The C# tests are in `Tests/GraftMergeTests`. They cover Graft's TkSharp changes, the helper's configuration and message format, its commands' error handling, option handling, reordering and mod recognition.

They also read the code-patch files in `Tests/GraftMergeTests/Fixtures`, which were written for these tests:

- a mod that keeps values in its own code;
- the same mod fixed by hand;
- a mod that only replaces instructions.

The C# tests run one at a time. Every TkSharp mod manager saves itself when a static TkSharp event fires, so two tests running together would write into each other's temporary folders.

They use xunit v3 on Microsoft.Testing.Platform, which `Sources/GraftMerge/global.json` selects for `dotnet test`. To run them alone, run this from the `Sources/GraftMerge` folder, because `dotnet` reads `global.json` from the folder it runs in and the folders above it:

```sh
dotnet test --project ../../Tests/GraftMergeTests/GraftMergeTests.csproj
```

### What the tests touch

The tests write only to temporary folders and don't search your home folder. Two tests compare Graft with a MacNativeGames checkout and run only when `GRAFT_MACNATIVEGAMES` is set (see [Games](games.md#testing-against-macnativegames)).
