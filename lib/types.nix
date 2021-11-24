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
        } // { description = "Helm chart installation"; };
      in
      addCheck moduleConfig (mod:
        mod ? chart && mod.chart ? name && mod.chart ? repository && isString mod.chart.name && isString mod.chart.repository
        && mod ? name && isString mod.name
        && mod ? namespace && isString mod.namespace
        && mod ? values && (isAttrs mod.values || isPath mod.values || isString mod.values)
      );

    kubernetesResource =
      (
        addCheck (attrsOf anything) # These apply to all k8s resources I can think of right now, this may need to be changed
          (val:
            val ? apiVersion && isString val.apiVersion
            && val ? kind && isString val.kind
          )
      ) // {
        description = "kubernetes resource definition";
      };

    scriptExecution =
      let
        moduleConfig = # submodule {
        #   options = {
        #     script = mkOption {
        #       type = lines;
        #       description = "A shell script snippet that will be executed";
        #     };
        #     scriptFile = mkOption {
        #       type = strOrPath;
        #       description = "Link to a script that will be executed";
        #     };
        #   };
        # }
        attrsOf anything // { description = "script execution"; };
      in
      addCheck moduleConfig (mod:
        if (mod ? script && isString mod.script) || (mod ? scriptFile && (isPath mod.scriptFile || isString mod.scriptFile))
        then
        let
          attrs = traceValSeq (attrNames (traceValSeq mod));
        in
        (
          if !(mod ? script && isString mod.script && mod ? scriptFile && (isPath mod.scriptFile || isString mod.scriptFile))
          then true
          else abort "Can not have both a scriptFile and script attribute!"
        )
        else false
      );

    kubernetesDeployment = submodule {
      options = {
        enable = mkEnableOption "this deployment";
        dependencies = mkOption {
          type = listOf str;
          default = [ ];
          description = "Names of other deployments that must be run before this one";
        };
        steps = mkOption {
          type = listOf (oneOf [ strOrPath kubernetesResource helmInstallation scriptExecution ]);
          description = "A list of deployment steps. These can be either kubernetes resources (as a file or attrset), helm charts or script executions";
        };
      };
    };

  };
}
