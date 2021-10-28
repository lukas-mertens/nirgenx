#!@bash@/bin/bash
set -eu

if [ "$1" == "-" ]; then
  FILE="/dev/stdin"
else
  FILE="$1"
fi

cat $FILE | @yaml2json@/bin/yaml2json | @nixUnstable@/bin/nix-instantiate --eval -E "with builtins; fromJSON (readFile /dev/stdin)" | @nixfmt@/bin/nixfmt
