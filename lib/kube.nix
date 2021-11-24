{ lib, ... }:
with builtins; with lib; {
  kube = {

    createNamespace =
    name:
      {
        apiVersion = "v1";
        kind = "Namespace";
        metadata.name = name;
      };

    installHelmChart =
    repository: name: values:
    {
      chart = {
        inherit repository;
        inherit name;
      };
      inherit name;
      namespace = name;
      inherit values;
    };

  };
}
