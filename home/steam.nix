{ ... }:
{
  home.stateVersion = "26.05";

  # ROM->Steam parser definitions. Verify emulator binary names and globs in the
  # Steam ROM Manager GUI, then commit changes here. See README.
  home.file.".config/steam-rom-manager/userData/userConfigurations.json".source =
    ./steam/srm/userConfigurations.json;

  # Desktop apps (Vesktop, Chrome) surfaced in Steam Game Mode via the Manual parser.
  home.file.".config/steam-rom-manager/manifests/apps.json".source = ./steam/srm/manifests/apps.json;
}
