{ ... }:
{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    # Mirrors the local macOS "sira" theme verbatim. Kept as a sibling TOML so
    # it stays the single source of truth and can be re-synced from the Mac with:
    #   cp ~/.config/starship.toml home/samb/starship.toml
    settings = builtins.fromTOML (builtins.readFile ./starship.toml);
  };
}
