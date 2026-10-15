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
    # Misc utilities
    bc
    zip
    unzip
    p7zip
    sqlite
    usbutils
    pciutils
  ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
