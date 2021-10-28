#!@python3@/bin/python3

import sys
import json
import subprocess
import urllib.request
import yaml
from subprocess import Popen
from pathlib import Path

lockname = "helm.lock"
args = sys.argv[1:]

if not Path("helm.nix").is_file():
  print("No helm.nix found!")

result = Popen(["@nixUnstable@/bin/nix-instantiate", "--eval", "-E", "builtins.toJSON (import ./helm.nix)"], stdout=subprocess.PIPE)
result.wait()

if not result.returncode == 0:
  print("An error occured while parsing helm.nix")
  exit(1)

decoded = result.stdout.read().decode("unicode_escape").strip()[1:-1]
config = json.loads(decoded)

toUpdate = config.keys()
if len(args) > 0:
  toUpdate = args
  missing = []
  for repo in toUpdate:
    if not repo in config:
      missing += [ repo ]
  if len(missing) > 0:
    print(f"Unknown repositories {missing}!")
    exit(1)

lockfile = {}
if Path(lockname).is_file():
  oldlock = {}
  with open(lockname, "r") as f:
    oldlock = json.loads(f.read())
  for key in config.keys():
    if key in oldlock:
      lockfile[key] = oldlock[key]

for repo in toUpdate:
  print(f"Updating {repo}...")
  request = urllib.request.Request(
    f"{config[repo]}/index.yaml",
    data=None,
    headers = {
      "User-Agent": "Helm/3.5.4" # Some chart repos don't want to talk to python
    }
  )
  with urllib.request.urlopen(request) as response:
    lockfile[repo] = yaml.load(response.read(), Loader=yaml.CLoader)

with open(lockname, "w") as f:
  f.write(json.dumps(lockfile, indent = 2))
  f.flush()


