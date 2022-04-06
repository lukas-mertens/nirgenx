{ config, lib, pkgs, ... }:
with builtins; with lib; {

  config =
  let
    cfg = config.nirgenx;

    serviceName = deployment: "nirgenx-deployment-${deployment}";

    deploymentConfigs = mapAttrsToList
    (n: deployment: rec {

      name = strings.sanitizeDerivationName n;

      scriptDependencies =
        filter
          (x: x != "" && (! hasPrefix "http" x))
          (map
            (step:
              if lib.types.helmInstallation.check step
              then (if isString step.values then step.values else "")
              else if lib.types.scriptExecution.check step
              then (if step ? scriptFile then step.scriptFile else "")
              else (if isString step then step else "")
            )
            deployment.steps
          );

      allScriptDependencies = concatStringsSep " " (map (f: "\"${f}\"") scriptDependencies);

      deployScript = pkgs.writeShellScriptBin "nirgenx-deploy-${name}" (
        concatStringsSep "\n" ( flatten (
          [ "set -eux" ]
          ++
          (
            map
            (step:
              if lib.types.helmInstallation.check step
              then
                (
                  let
                    fileName = strings.sanitizeDerivationName "helm-chart-${step.chart.repository}/${step.chart.name}${if isNull step.chart.version then "" else "@${step.chart.version}"}-${step.namespace}-${step.name}.json";
                    values = if isString step.values then step.values else pkgs.writeText fileName (toJSON step.values);
                  in
                  ["${cfg.helmPackage}/bin/helm upgrade -i -n '${step.namespace}' --create-namespace -f '${values}' '${step.name}' '${helm.getTar config.nirgenx.helmNixPath step.chart.repository step.chart.name step.chart.version}'"]
                )
              else if lib.types.scriptExecution.check step
              then
                (
                  if step ? scriptFile
                  then [step.scriptFile]
                  else splitString "\n" step.script
                )
              else
                (
                  let
                    fileName = strings.sanitizeDerivationName "k8s${if step ? kind then "-${step.kind}" else ""}${if (step ? metadata) then "${if step.metadata ? name then "-${step.metadata.name}" else ""}${if step.metadata ? namespace then "-${step.metadata.namespace}" else ""}" else ""}.json";
                    resource = if isString step then step else pkgs.writeText fileName (toJSON step);
                  in
                  ["${cfg.kubectlPackage}/bin/kubectl apply -f '${resource}'"]
                )
            )
            deployment.steps
          ) ++ [
            "mkdir -p /var/lib/nirgenx"
            "cat $0 ${allScriptDependencies} | sha256sum | awk '{print $1;}' > /var/lib/nirgenx/${name}"
          ]
        ))
      );

      service = rec {
        requires = cfg.waitForUnits ++ (map (dep: "${serviceName dep}.service") deployment.dependencies);
        after = requires;
        wantedBy = [ "multi-user.target" ];
        environment = {
          HOME = config.users.users.root.home;
          KUBECONFIG = cfg.kubeconfigPath;
        };
        serviceConfig = {
          Type = "oneshot";
        };
        path = [
          cfg.helmPackage
          cfg.kubectlPackage

          pkgs.gawk
        ];
        script =
        let
          ds = "${deployScript}/bin/nirgenx-deploy-${name}";
        in
        ''
          set -e
          if [[ -f /var/lib/nirgenx/${name} ]] && [[ "$(cat /var/lib/nirgenx/${name})" == "$(cat ${ds} ${allScriptDependencies} | sha256sum | awk '{print $1;}')" ]]; then
            echo "Deployment script has not changed since the last run - skipping"
            exit 0
          else
            ${ds}
          fi
        '';
      };
    })
    (
      filterAttrs
      (name: deployment: deployment.enable)
      cfg.deployment
    );
  in
  {
    systemd.services = listToAttrs (map (d: nameValuePair (serviceName d.name) d.service) deploymentConfigs);

    environment.systemPackages = (map (d: d.deployScript) deploymentConfigs);
  };

}
