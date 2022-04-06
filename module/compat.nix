{ config, pkgs, lib, ... }:
with builtins; with lib; {

  imports = [
    (mkRenamedOptionModule [ "kubenix" ] [ "nirgenx" ])
  ];

}
