#!@bash@/bin/bash
set -eu

FILE="${1:--}" # Fallback to stdin (-)

cat "$FILE" | @yaml2json@/bin/yaml2json | @nixUnstable@/bin/nix-instantiate --eval -E "with builtins; fromJSON (readFile /dev/stdin)" | @nixfmt@/bin/nixfmt
