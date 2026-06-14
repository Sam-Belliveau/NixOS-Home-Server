{ ... }:
{
  users.groups.gamelib = { };

  # setgid so files dropped under /games inherit the shared group.
  systemd.tmpfiles.rules = [
    "d /games 2775 root gamelib - -"
    "d /games/roms 2775 root gamelib - -"
  ];
}
