{ lib, config, ... }:
let
  cfg = config.myServices.jellyfin;
in
{
  options.myServices.jellyfin.enable = lib.mkEnableOption "Jellyfin media server";

  config = lib.mkIf cfg.enable {
    services.jellyfin = {
      enable = true;
      openFirewall = true;
    };

    # render/video give ffmpeg NVENC access; enable it in the Jellyfin dashboard.
    users.users.jellyfin.extraGroups = [
      "render"
      "video"
    ];
  };
}
