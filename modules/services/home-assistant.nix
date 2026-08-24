{ lib, config, pkgs, ... }:
let
  cfg = config.myServices.homeAssistant;
in
{
  options.myServices.homeAssistant.enable = lib.mkEnableOption "Home Assistant";

  config = lib.mkIf cfg.enable {
    services.matter-server = {
      enable = true;
      package = pkgs.python-matter-server.overridePythonAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./matter-server-skip-bad-paa-cert.patch ];
      });
    };

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
        "matter"
        "apple_tv"
        "thread"
        "homekit_controller"
        "google_translate"
        "roku"
        "upnp"
      ];
      config =
        let
          ceiling = map (n: "light.living_room_living_room_ceiling_light_${toString n}") [ 1 2 3 4 5 ];
          walls = map (n: "light.living_room_living_room_wall_light_${toString n}") [ 1 2 ];
          stairs = map (n: "light.living_room_stair_light_${toString n}") [ 1 2 ];
          bedroom = map (n: "light.bedroom_bedroom_light_${toString n}") [ 1 2 ];
          # scene helper: same settings across a list of lights
          lit = entities: attrs: lib.genAttrs entities (_: { state = "on"; } // attrs);
          off = entities: lib.genAttrs entities (_: { state = "off"; });
        in
        {
          default_config = { };
          homeassistant = {
            name = "samb-tower";
            unit_system = "us_customary";
            time_zone = "America/New_York";
          };

          light = [
            { platform = "group"; unique_id = "living_room_ceiling"; name = "Living Room Ceiling"; entities = ceiling; }
            { platform = "group"; unique_id = "living_room_walls"; name = "Living Room Walls"; entities = walls; }
            { platform = "group"; unique_id = "stairway_lights"; name = "Stairway Lights"; entities = stairs; }
            { platform = "group"; unique_id = "bedroom_lights"; name = "Bedroom Lights"; entities = bedroom; }
            { platform = "group"; unique_id = "all_lights"; name = "All Lights"; entities = ceiling ++ walls ++ stairs ++ bedroom; }
          ];

          "scene manual" = [
            {
              id = "movie_night";
              name = "Movie Night";
              icon = "mdi:movie-open";
              entities =
                lit ceiling { brightness = 20; color_temp_kelvin = 2500; }
                // lit stairs { brightness = 31; color_temp_kelvin = 2500; }
                // off walls // off bedroom;
            }
            {
              id = "cozy";
              name = "Cozy";
              icon = "mdi:fireplace";
              entities =
                lit ceiling { brightness = 115; color_temp_kelvin = 2700; }
                // lit walls { brightness = 153; color_temp_kelvin = 2700; }
                // lit stairs { brightness = 77; color_temp_kelvin = 2700; };
            }
            {
              id = "focus";
              name = "Focus";
              icon = "mdi:head-lightbulb";
              entities =
                lit ceiling { brightness = 255; color_temp_kelvin = 5000; }
                // lit walls { brightness = 255; color_temp_kelvin = 4600; };
            }
            {
              id = "party";
              name = "Party";
              icon = "mdi:party-popper";
              entities =
                lit [ (builtins.elemAt ceiling 0) (builtins.elemAt ceiling 2) (builtins.elemAt ceiling 4) ]
                  { brightness = 200; rgb_color = [ 170 0 255 ]; }
                // lit [ (builtins.elemAt ceiling 1) (builtins.elemAt ceiling 3) ]
                  { brightness = 200; rgb_color = [ 0 120 255 ]; }
                // lit walls { brightness = 220; rgb_color = [ 255 0 120 ]; }
                // lit stairs { brightness = 180; rgb_color = [ 0 255 170 ]; };
            }
            {
              id = "night";
              name = "Night";
              icon = "mdi:weather-night";
              entities =
                lit stairs { brightness = 20; rgb_color = [ 255 70 0 ]; }
                // off ceiling // off walls // off bedroom;
            }
          ];
          "scene ui" = "!include scenes.yaml";

          script = {
            goodnight = {
              alias = "Goodnight";
              icon = "mdi:sleep";
              sequence = [
                { action = "media_player.media_pause"; target.entity_id = "media_player.dormpod_dormpod"; }
                { action = "scene.turn_on"; target.entity_id = "scene.night"; data.transition = 3; }
              ];
            };
            announce = {
              alias = "Announce on DormPod";
              icon = "mdi:bullhorn";
              fields.message = {
                description = "What the HomePod should say";
                example = "Dinner is ready";
              };
              sequence = [
                {
                  action = "tts.speak";
                  target.entity_id = "tts.google_translate_en_com";
                  data = {
                    media_player_entity_id = "media_player.dormpod_dormpod";
                    message = "{{ message }}";
                  };
                }
              ];
            };
          };

          "automation ui" = "!include automations.yaml";
        };
    };
  };
}
