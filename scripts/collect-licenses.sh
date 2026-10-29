#!/bin/zsh
set -euo pipefail
setopt extendedglob

deps="$1"
packages="$2"
out="$3"
mkdir -p "$out"
notices="$out/graft-merge-packages.txt"

field() {
  xmllint --xpath "string(//*[local-name()='$2']${3:-})" "$1" 2>/dev/null || true
}

{
  print "Packages included in graft-merge, with their licenses."
  print "Packages under the MIT License show their copyright line; the MIT License text is at the end of this file."
  print "Packages under the AGPL-3.0-or-later are covered by AGPL-3.0.txt in this folder."
  print
} > "$notices"

jq -r '.libraries | to_entries[] | select(.value.type == "package") | .key' "$deps" | while IFS=/ read -r id version; do
  folder="$packages/${id:l}/$version"
  nuspec="$folder/${id:l}.nuspec"
  license="$(field "$nuspec" license)"
  kind="$(field "$nuspec" license /@type)"
  {
    print -r -- "== $id $version"
    print -r -- "License: ${license:-see the package}"
    copyright="$(field "$nuspec" copyright)"
    [[ -n "$copyright" ]] && print -r -- "$copyright"
    project="$(field "$nuspec" projectUrl)"
    [[ -n "$project" ]] && print -r -- "$project"
    local_license=("$folder"/(#i)license(|.txt|.md)(N.))
    if [[ "$kind" == file && -f "$folder/$license" ]]; then
      print
      cat "$folder/$license"
    elif (( ${#local_license} )); then
      print
      cat "$local_license[1]"
    fi
    print
  } >> "$notices"
done

cat >> "$notices" <<'MIT'
== MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
documentation files (the "Software"), to deal in the Software without restriction, including without limitation the
rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit
persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
MIT

runtime="$(jq -r '.libraries | to_entries[] | select(.value.type == "runtimepack") | .key' "$deps")"
runtime_id="${${runtime%%/*}#runtimepack.}"
runtime_folder="$packages/${runtime_id:l}/${runtime#*/}"
install -m 644 "$runtime_folder/LICENSE.TXT" "$out/dotnet-runtime-LICENSE.txt"
install -m 644 "$runtime_folder/THIRD-PARTY-NOTICES.TXT" "$out/dotnet-runtime-THIRD-PARTY-NOTICES.txt"
