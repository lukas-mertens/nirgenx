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

  outputs =
    inputs @ { self
    , flake-utils
    , nixpkgs
    , ...
    }:
    let
      flakeLib = import ./lib { inherit lib; };
      lib = with nixpkgs.lib; recursiveUpdate nixpkgs.lib flakeLib;
    in
    {
      lib = flakeLib;
      nixosModules =
        builtins.map
          (x: { config, pkgs, ... }: (x { inherit config lib pkgs; })) # Overwrite the lib that is passed to the module with our own
          (import ./module);
    } // (
      flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages."${system}";
      in
      {
        devShell = pkgs.mkShell {
          builtInputs = with pkgs; [
            nixpkgs-fmt
          ];
        };

        packages = {
          helm-update = pkgs.substituteAll {
            name = "helm-update";
            src = ./script/helm-update.py;
            dir = "bin";
            isExecutable = true;
            inherit (pkgs) nixUnstable;
            python3 = pkgs.python3.withPackages (p: [ p.pyyaml ]);
          };
          yaml2nix = pkgs.substituteAll {
            name = "yaml2nix";
            src = ./script/yaml2nix.sh;
            dir = "bin";
            isExecutable = true;
            inherit (pkgs) bash nixUnstable nixfmt remarshal;
          };
        };

        apps = {
          helm-update = flake-utils.lib.mkApp {
            name = "helm-update";
            drv = self.packages.${system}.helm-update;
          };
          yaml2nix = flake-utils.lib.mkApp {
            name = "yaml2nix";
            drv = self.packages.${system}.yaml2nix;
          };
        };
      })
    );
}
