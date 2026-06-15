{
  description = "samb-tower - couch Steam Game Mode + headless dev/server (NixOS unstable, for Jovian)";

  inputs = {
    # nixos-unstable: required by Jovian-NixOS (it only supports unstable; its
    # gamescope overlay is applied to *this* nixpkgs). flake.lock pins the exact
    # rev, so "rolling" only moves when you `nix flake update`.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Stable, only to cherry-pick leaf packages that are temporarily broken on
    # unstable (currently rpcs3 - see modules/gaming/emulators.nix). Not a
    # second system channel; just a source for individual cached binaries.
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";

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
