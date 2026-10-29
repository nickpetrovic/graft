# Contributing

Thank you for helping with Graft.

- [Building and contributing](building.md) explains how to build Graft, run the tests and open the code in an IDE.
- [How Graft works](architecture.md) describes the project layout and what happens when you press Play.
- [Games](games.md) explains adding a game, game definitions and templates, and how to add mod support for a new kind of port.

## Before you send a change

- Run `make test` and make sure both test suites pass.
- If your change touches how Graft calls MacNativeGames, also run the tests against a current MacNativeGames checkout: `GRAFT_MACNATIVEGAMES=<path> make test`.
- Update the docs in the same change when a command, setting, label or behavior they describe changes.

## Conventions

- The code has no comments. Names and small functions carry the meaning, and the docs explain the design.
- Logic that doesn't need SwiftUI goes in ModKit, where it can be tested. Tests for a ModKit file go in the matching folder of `Tests/ModKitTests`, and test names describe the behavior they check.
- The app writes `@ViewState` instead of `@State`. It is the same property wrapper under another name: the macOS SDK also declares `@State` as a SwiftUI macro, and the Command Line Tools don't include the plugin that expands it.
- The helper's build treats unused `using` directives as warnings (IDE0005). Remove them before you send a change.
- Swift follows Swift 6 strict concurrency, and C# uses the .NET 10 SDK with nullable reference types on.
- Test fixtures are written for the tests. Don't add files from other people's mods.

## Reporting a problem

Include:

- what you did and what you expected;
- the output of `graft settings`, with your home folder path removed if you like;
- for a crash or a stop, the game's log from `~/Library/Logs/MacNativeGames` (the app's **Show Log** button opens it);
- your macOS version, your Mac, and the game version shown on the Version button above the mod list.
