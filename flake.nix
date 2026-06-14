{
  description = "samb-tower — couch Steam Game Mode + headless dev/server (NixOS 26.05)";

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
      # ── The machine ──────────────────────────────────────────────────────
      nixosConfigurations.samb-tower = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/samb-tower ];
      };

      # ── Per-project dev shells (the reusable pattern) ────────────────────
      devShells.${system} = import ./devshells.nix { inherit pkgs; };

      templates = {
        python-ml = {
          path = ./templates/python-ml;
          description = "uv venv + nix-ld for binary ML wheels";
        };
        cuda = {
          path = ./templates/cuda;
          description = "pinned cudaPackages + nvcc toolchain";
        };
        gaussian-splat = {
          path = ./templates/gaussian-splat;
          description = "COLMAP (CUDA) + nerfstudio/gsplat via uv";
        };
        rust = {
          path = ./templates/rust;
          description = "rustc/cargo/clippy + rust-analyzer";
        };
        cpp = {
          path = ./templates/cpp;
          description = "clang/gcc + cmake/ninja + lldb";
        };
      };

      # ── Tooling ──────────────────────────────────────────────────────────
      formatter.${system} = pkgs.nixfmt-rfc-style;

      checks.${system}.toplevel =
        self.nixosConfigurations.samb-tower.config.system.build.toplevel;
    };
}
