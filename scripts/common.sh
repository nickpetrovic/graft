export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1

find_dotnet() {
  local candidate
  for candidate in "${DOTNET:-}" "$HOME/.dotnet/dotnet" "$(command -v dotnet 2>/dev/null || true)"; do
    [[ -n "$candidate" && -x "$candidate" ]] || continue
    if "$candidate" --list-sdks 2>/dev/null | grep -q '^10\.'; then
      print -r -- "$candidate"
      return
    fi
  done
  print -u2 "The .NET 10 SDK is missing. Install it with scripts/install-dotnet.sh (no admin rights needed), or set DOTNET to a dotnet program that has it."
  exit 1
}

prepare_sources() {
  local tksharp="$ROOT/vendor/TkSharp"
  local patches=("$ROOT"/vendor/patches/tksharp-*.patch(N))
  if [[ -e "$ROOT/.git" ]]; then
    local submodules=$'\n'"$(git -C "$ROOT" submodule status)"
    if [[ "$submodules" == *$'\n'[-+U]* ]]; then
      [[ -f "$tksharp/TkSharp.sln" ]] && reset_tksharp "$tksharp"
      git -C "$ROOT" submodule update --init --recursive
    fi
  elif [[ ! -f "$tksharp/TkSharp.sln" || ! -f "$ROOT/vendor/capstone/cs.c" ]]; then
    print -u2 "vendor/TkSharp and vendor/capstone are empty. Get Graft with git instead: git clone --recurse-submodules <url>"
    exit 1
  fi

  local marker="$(git -C "$tksharp" rev-parse --absolute-git-dir)/graft-patches"
  local wanted="$({ git -C "$tksharp" rev-parse HEAD; cat /dev/null "${patches[@]}"; } | shasum -a 256)"
  [[ -f "$marker" && "$(<"$marker")" == "$wanted" ]] && return

  reset_tksharp "$tksharp"
  local patch
  for patch in "${patches[@]}"; do
    if ! git -C "$tksharp" apply --check "$patch" 2>/dev/null; then
      print -u2 "vendor/patches/${patch:t} doesn't fit the TkSharp commit in vendor/TkSharp. Update the patch for that commit."
      exit 1
    fi
    git -C "$tksharp" apply "$patch"
  done
  print -r -- "$wanted" > "$marker"
}

reset_tksharp() {
  git -C "$1" reset -q --hard
  git -C "$1" clean -fdq
  rm -f "$(git -C "$1" rev-parse --absolute-git-dir)/graft-patches"
}
