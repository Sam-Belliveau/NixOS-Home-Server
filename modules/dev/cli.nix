{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # Version control
    git
    git-lfs
    gh
    lazygit
    # Search / navigation
    ripgrep
    fd
    fzf
    zoxide
    eza
    bat
    # Inspection
    jq
    yq-go
    tree
    file
    # Monitoring
    htop
    btop
    nvtopPackages.nvidia
    # Shell
    tmux
    curl
    wget
    rsync
  ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
