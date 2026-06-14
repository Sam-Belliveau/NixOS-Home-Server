{ ... }:
{
  imports = [
    ./samb/zsh.nix
    ./samb/starship.nix
    ./samb/git.nix
    ./samb/vscode.nix
    ./samb/browser.nix
  ];

  home.stateVersion = "26.05";
}
