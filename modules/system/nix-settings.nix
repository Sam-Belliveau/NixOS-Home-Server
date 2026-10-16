{ pkgs, inputs, ... }:
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

  # claude-code comes from its own nixpkgs input (see flake.nix) so it can be
  # bumped without moving the rest of the system. Overlaid so every user of
  # pkgs.claude-code (incl. the Remote Control units) gets the same build.
  nixpkgs.overlays = [
    (final: prev: {
      claude-code =
        (import inputs.nixpkgs-claude {
          system = prev.stdenv.hostPlatform.system;
          config.allowUnfree = true;
        }).claude-code;
    })
  ];

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
