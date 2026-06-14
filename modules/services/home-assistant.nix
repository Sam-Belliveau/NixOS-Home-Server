{ lib, config, ... }:
let
  cfg = config.myServices.homeAssistant;
in
{
  options.myServices.homeAssistant.enable = lib.mkEnableOption "Home Assistant";

  config = lib.mkIf cfg.enable {
    services.home-assistant = {
      enable = true;
      configDir = "/srv/home-assistant";
      openFirewall = true;
      extraComponents = [
        "default_config"
        "met"
        "esphome"
        "mobile_app"
        "radio_browser"
        "mqtt"
        "zha"
        "cast"
        "wled"
      ];
      config = {
        default_config = { };
        homeassistant = {
          name = "samb-tower";
          unit_system = "us_customary";
          time_zone = "America/New_York";
        };
      };
    };
  };
}
