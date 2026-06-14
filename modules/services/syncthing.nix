{ lib, config, ... }:
let
  cfg = config.myServices.syncthing;
in
{
  options.myServices.syncthing.enable = lib.mkEnableOption "Syncthing";

  config = lib.mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      user = "samb";
      group = "users";
      dataDir = "/srv/syncthing";
      configDir = "/srv/syncthing/.config";
      openDefaultPorts = true;
    };
  };
}
