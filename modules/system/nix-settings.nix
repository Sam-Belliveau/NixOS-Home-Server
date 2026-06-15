{ pkgs, ... }:
{
  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    trusted-users = [
      "root"
      "samb"
    ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  environment.systemPackages = [ pkgs.claude-code ];

  # Ship terminfo for many terminal emulators (incl. ghostty's xterm-ghostty)
  # so TERM is recognized over SSH instead of breaking colors/clear/keys.
  environment.enableAllTerminfo = true;

  # Locale / time / console
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  networking.networkmanager.enable = true;
}
