{ ... }:
{
  users.users.steam = {
    isNormalUser = true;
    description = "Steam Game Mode";
    extraGroups = [
      "gamelib"
      "video"
      "render"
      "input"
    ];
  };
}
