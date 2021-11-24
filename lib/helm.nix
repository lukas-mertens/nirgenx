{ lib, ... }:
with builtins; with lib; {
  helm = rec {

    getRepos =
      helmNixPath:
      let
        lockfile = fromJSON (readFile "${helmNixPath}/helm.lock");
        helmNix = import "${helmNixPath}/helm.nix";
        repos =
          mapAttrs
            (name: url: { inherit url; entries = (lockfile."${name}"); })
            helmNix;
      in
      repos;

    getChart =
      helmNixPath:
      repo:
      chart:
      version:
      let
        repos = helm.getRepos helmNixPath;
        repoUrl = repos."${repo}".url;
        latestVersion = head (sort (a: b: ! (versionOlder a.version b.version)) (mapAttrsToList (n: v: v // { version = n; }) repos."${repo}".entries."${chart}"));
        selectedVersion = repos."${repo}".entries."${chart}"."${version}";
      in
      if isNull version then
        latestVersion
      else
        selectedVersion;

    getLatest =
      helmNixPath:
      repo:
      chart:
      getChart helmNixPath repo chart null;

    getLatestVersion =
      helmNixPath:
      repo:
      chart:
      (getChart helmNixPath repo chart null).version;

    getTar =
      helmNixPath:
      repo:
      chart:
      version:
      let
        repos = getRepos helmNixPath;
        repoUrl = repos."${repo}".url;
        entry = getChart helmNixPath repo chart version;
        fullUrl = if hasPrefix "https://" entry.url || hasPrefix "http://" entry.url then entry.url else "${repoUrl}/${entry.url}";
      in
      fetchurl { url = fullUrl; sha256 = entry.digest; };

  };
}
