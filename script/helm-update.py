#!@python3@/bin/python3

import sys
import json
import subprocess
import urllib.request
import yaml
from subprocess import Popen
from pathlib import Path


def reformat(lock):
  result = {}
  for entry in lock["entries"]:
    versions = {}
    for version in lock["entries"][entry]:
      num = version["version"]
      name = version["name"]
      if len(version["urls"]) == 0:
        sys.stderr.write(f"Version {num} of release {name} has no URL!")
        sys.stderr.flush()
        continue
      if len(version["urls"]) > 1:
        sys.stderr.write(f"Version {num} of release {name} has multiple URLs!")
        sys.stderr.flush()
      versions[num] = {
        "digest": version["digest"],
        "url": version["urls"][0],
      }
    result[entry] = versions
  return result


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
  if len(args) == 1 and args[0] == "--migrate":
    toUpdate = []
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
      if "entries" in oldlock[key]:
        lockfile[key] = reformat(oldlock[key])
      else:
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
    lockfile[repo] = reformat(yaml.load(response.read(), Loader=yaml.CLoader))

with open(lockname, "w") as f:
  f.write(json.dumps(lockfile, indent = 2))
  f.flush()


