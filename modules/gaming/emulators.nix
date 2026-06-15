{ pkgs, inputs, ... }:
let
  # Stable nixpkgs, used only for leaf packages that are broken on unstable.
  pkgsStable = import inputs.nixpkgs-stable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
in
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
      # rpcs3 fails to compile on the current nixos-unstable snapshot
      # (2026-06); pull the cached stable build instead. Revert to pkgs.rpcs3
      # once unstable builds again.
      pkgsStable.rpcs3
    ];
}
