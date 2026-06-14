{
  description = "samb-tower - couch Steam Game Mode + headless dev/server (NixOS 26.05)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
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
