{
  description = "samb-tower - couch Steam Game Mode + headless dev/server (NixOS unstable, for Jovian)";

  inputs = {
    # nixos-unstable: required by Jovian-NixOS (it only supports unstable; its
    # gamescope overlay is applied to *this* nixpkgs). flake.lock pins the exact
    # rev, so "rolling" only moves when you `nix flake update`.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # claude-code only (overlaid in modules/system/nix-settings.nix). It ships
    # new releases — and with them new models — far faster than the main
    # nixpkgs pin moves, and bumping that pin drags gamescope/NVIDIA along with
    # it. master gets claude-code updates first. Bump on its own with
    # `nix flake update nixpkgs-claude`.
    nixpkgs-claude.url = "github:NixOS/nixpkgs/master";

    home-manager = {
      # master tracks nixpkgs unstable (release-* tracks stable).
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # SteamOS-style Game Mode on generic hardware: proper gamescope session +
    # a working steamos-session-select (reliable Game Mode <-> Desktop switch).
    # Wired into the host via modules/gaming/game-mode.nix.
    jovian = {
      url = "github:Jovian-Experiments/Jovian-NixOS";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      nixosConfigurations.samb-tower = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/samb-tower ];
      };

      devShells.${system} = import ./devshells.nix { inherit pkgs; };

      formatter.${system} = pkgs.nixfmt;

      checks.${system}.toplevel = self.nixosConfigurations.samb-tower.config.system.build.toplevel;
    };
}
