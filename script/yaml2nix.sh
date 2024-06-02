#!@bash@/bin/bash
set -eu

FILE="${1:--}" # Fallback to stdin (-)

cat "$FILE" | @remarshal@/bin/yaml2json | @nix@/bin/nix-instantiate --eval -E "with builtins; fromJSON (readFile /dev/stdin)" | @nixfmt@/bin/nixfmt
