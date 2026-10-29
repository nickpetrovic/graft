#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
cd "$ROOT"
source "$ROOT/scripts/common.sh"
prepare_sources
DOTNET="$(find_dotnet)"

(cd "$ROOT/Sources/GraftMerge" && "$DOTNET" test --project ../../Tests/GraftMergeTests/GraftMergeTests.csproj --results-directory "$ROOT/.build/test-results")

PLUGINS="$(xcode-select -p)/usr/lib/swift/host/plugins/testing"
plugin_flags=()
[[ -d "$PLUGINS" ]] && plugin_flags=(-Xswiftc -plugin-path -Xswiftc "$PLUGINS")
swift test --package-path "$ROOT" "${plugin_flags[@]}" "$@"
