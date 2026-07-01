{ pkgs, ... }:
{
  # Standalone emulators, launched per-ROM by the Steam import pipeline.
  environment.systemPackages =
    (with pkgs; [
      dolphin-emu
      pcsx2
      ares
      melonds
      mgba
      ppsspp
      cemu
      azahar
      xemu
    ])
    ++ [
      # rpcs3's nixpkgs package is broken: it vendors wolfSSL/Fusion as shared
      # libs but installs none of them, so the binary can't load (and it's
      # marked unfree, so it's never a cached/tested build). Run the upstream
      # AppImage in an FHS sandbox instead - see ./rpcs3.nix.
      (import ./rpcs3.nix { inherit pkgs; })
    ];
}
