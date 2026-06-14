{ ... }:
{
  programs.git = {
    enable = true;
    userName = "Sam Belliveau";
    userEmail = "sam.belliveau@gmail.com";
    lfs.enable = true;
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
  };

  programs.gh = {
    enable = true;
    settings.aliases.co = "pr checkout";
  };
}
