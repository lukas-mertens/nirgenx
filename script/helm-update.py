#!@python3@/bin/python3

import sys
import json
from subprocess import Popen
from pathlib import Path

if not Path("helm.nix").is_file():
  print("No helm.nix found!")

subprocess.Popen(["@nixUnstable@/bin/nix-instantiate", "--eval", "-E", "builtins.toJSON (import ./helm.nix)"])
