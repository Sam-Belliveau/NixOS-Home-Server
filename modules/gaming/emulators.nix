{ pkgs, ... }:
{
  # Standalone emulators, launched per-ROM by the Steam import pipeline.
  environment.systemPackages = with pkgs; [
    dolphin-emu
    pcsx2
    ares
    melonds
    mgba
    ppsspp
    rpcs3
    cemu
    azahar
    xemu
  ];
}
