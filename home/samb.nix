{ ... }:
{
  imports = [
    ./samb/zsh.nix
    ./samb/starship.nix
    ./samb/git.nix
    ./samb/vscode.nix
  ];

  home.stateVersion = "26.05";

  # ROM->Steam parser definitions (Steam ROM Manager). Verify emulator binary
  # names/globs in the SRM GUI, then commit changes here. See README.
  home.file.".config/steam-rom-manager/userData/userConfigurations.json".source =
    ./samb/srm/userConfigurations.json;

  # Desktop apps (Vesktop, Chrome) surfaced in Game Mode via the Manual parser.
  home.file.".config/steam-rom-manager/manifests/apps.json".source =
    ./samb/srm/manifests/apps.json;
}
