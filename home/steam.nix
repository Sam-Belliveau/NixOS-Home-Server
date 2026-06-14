{ ... }:
{
  home.stateVersion = "26.05";

  # ROM->Steam parser definitions. Verify emulator binary names and globs in the
  # Steam ROM Manager GUI, then commit changes here. See README.
  home.file.".config/steam-rom-manager/userData/userConfigurations.json".source =
    ./steam/srm/userConfigurations.json;
}
