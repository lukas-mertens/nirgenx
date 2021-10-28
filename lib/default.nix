{ lib, ... }:
with builtins; with lib; {
  types = with types; {
    strOrPath = coercedTo path (p: "${p}") str;
    helmInstallation =
      let
        moduleConfig = submodule {
          options = {
            chart = {
              repository = mkOption {
                type = str;
                description = "The helm respoitory that contains the chart";
                example = ''
                  "bitnami";
                '';
              };
              name = mkOption {
                type = str;
                description = "The name of the chart that will be installed";
                example = ''
                  "redis";
                '';
              };
              version = mkOption {
                type = nullOr str;
                default = null;
                description = "The version of the chart that will be installed";
                example = ''
                  "15.5.2";
                '';
              };
            };
            name = mkOption {
              type = str;
              description = "Name of the deployment";
              example = ''
                "redis";
              '';
            };
            namespace = mkOption {
              type = str;
              default = "default";
              description = "Namespace that the chart will be installed into. Will be created if it does not already exist";
              example = ''
                "redis";
              '';
            };
            values = mkOption {
              type = oneOf [ strOrPath (attrsOf anything) ];
              description = "Value definitions for the helm chart. This can be either an attrset or a path to a yaml/json that contains the values";
              example = ''
                {
                  global = {
                    storageClass = "local-path";
                    redis.password = "hunter2";
                  };
                  cluster.enable = false;
                }
              '';
            };
          };
        };
      in
      addCheck moduleConfig (mod:
        mod ? chart && mod.chart ? name && mod.chart ? repository && isString mod.chart.name && isString mod.chart.repository
        && mod ? name && isString mod.name
        && mod ? namespace && isString mod.namespace
        && mod ? values && (isAttrs mod.values || isCoercibleToString mod.values)
      );
    kubernetesResource =
      (
        addCheck (attrsOf anything) # These apply to all k8s resources I can think of right not, this may need to be changed
          (val:
            val ? apiVersion && isString val.apiVersion
            && val ? kind && isString val.kind
          )
      ) // {
        description = "kubernetes resource definition";
      };
    kubernetesDeployment = submodule {
      options = {
        enable = mkEnableOption "this deployment";
        steps = mkOption {
          type = listOf (oneOf [ strOrPath kubernetesResource helmInstallation ]);
          description = "A list of deployment steps. These can be either kubernetes resources (as a file or attrset) or helm charts";
        };
      };
    };
  };

  # (head (sort (a: b: ! (lib.versionOlder a.version b.version)) ((fromJSON (readFile ./helm.lock)).bitnami.entries.))).urls
  getHelmChart =
    helmNixPath:
    repo:
    chart:
    version:
    let
      lockfile = fromJSON (readFile "${helmNixPath}/helm.lock");
      helmNix = import "${helmNixPath}/helm.nix";
      repos =
        mapAttrs
          (name: url: { inherit url; inherit (lockfile.${name}) entries; })
          helmNix;
      repoUrl = repos.${repo}.url;
      latestVersion = head (sort (a: b: ! (versionOlder a.version b.version)) repos.${repo}.entries.${chart});
      filteredVersionCandidates = filter (x: x.version == version) repos.${repo}.entries.${chart};
      filteredVersion =
        if length filteredVersionCandidates == 0 then
          abort "Version ${version} not found for chart ${repo}/${chart}"
        else if length filteredVersionCandidates > 1 then
          abort "Multiple candidates for version ${version} found for chart ${repo}/${chart}"
        else
          head filteredVersionCandidates;
      chartDef =
        if isNull version then
          latestVersion
        else
          filteredVersion;
      chartUrl = head chartDef.urls;
      fullUrl = if hasPrefix "https://" chartUrl || hasPrefix "http://" chartUrl then chartUrl else "${repoUrl}/${chartUrl}";
    in
    if length chartDef.urls != 1 then
      abort "Chart has none or more than one URL! This is not supported"
    else (fetchurl { url = fullUrl; sha256 = chartDef.digest; });
}
