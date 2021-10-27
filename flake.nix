{
  description = "KubeNix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = inputs @ {
    self,
    flake-utils,
    nixpkgs,
    ...
  }:
  let
    flakeLib = import ./lib { inherit lib; };
    lib = with nixpkgs.lib; recursiveUpdate nixpkgs.lib flakeLib;
  in
  {
    lib = flakeLib;
    nixosModules =
      builtins.map
      (x: {config, pkgs, ... }: (x { inherit config lib pkgs; })) # Overwrite the lib that is passed to the module with out own
      (import ./module);
  } // (
    flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = nixpkgs.legacyPackages."${system}";
    in {
      devShell = pkgs.mkShell {
        builtInputs = with pkgs; [
          nixpkgs-fmt
        ];
      };

      apps = {
        helm-update = flake-utils.lib.mkApp {
          name = "helm-update";
          drv = pkgs.substituteAll {
            name = "helm-update";
            src = ./scripts/helm-update.py;
            dir = "bin";
            isExecutable = true;
            inherit (pkgs) python3 nixUnstable;
          };
        };
      };
    })
  );
}
