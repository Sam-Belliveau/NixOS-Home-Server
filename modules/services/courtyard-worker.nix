{ lib, pkgs, config, ... }:
let
  cfg = config.myServices.courtyardWorker;

  # Mirrors devshells.nix#gaussian-splat so the worker runs "inside that env".
  # All of this is lazy: with the unit disabled (the default) none of it — not
  # even cudaPackages_12_6 — is evaluated, so it can never affect a rebuild.
  cuda = pkgs.cudaPackages_12_6;
  ldPath = lib.makeLibraryPath (
    (with cuda; [
      cuda_cudart
      libcublas
      cudnn
      cuda_nvrtc
    ])
    ++ (with pkgs; [
      stdenv.cc.cc.lib
      zlib
      zstd
      glib
      libGL
      glibc
      xorg.libX11
      libxcrypt-legacy
    ])
  );

  # Same checkout as the capture server. The worker's exact launch (which venv,
  # `python -m courtyard_worker --interval 900`, …) lives in a gitignored launch
  # script inside it — same pattern as capturegraph's autorun.sh — so tweaking
  # how it starts never needs a nixos-rebuild. Create courtyard.sh and flip
  # `myServices.courtyardWorker.enable = true` to turn this on.
  home = "/home/samb";
  repo = "${home}/Programming/Research/capturegraph";
  launch = "${repo}/courtyard.sh";
in
{
  options.myServices.courtyardWorker.enable =
    lib.mkEnableOption "courtyard splatfacto-w worker (folds new sunny sessions into published splats)";

  config = lib.mkIf cfg.enable {
    systemd.services.courtyard-worker = {
      description = "Courtyard reconstruction worker (nerfstudio/gsplat, GPU)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      # Gitignored launch script: if it isn't present (fresh checkout, or the
      # venv isn't built yet), skip the unit cleanly instead of crash-looping.
      unitConfig.ConditionPathExists = launch;

      environment = {
        HOME = home;
        CUDA_HOME = "${cuda.cuda_nvcc}";
        CUDAHOSTCXX = "${pkgs.gcc12}/bin/g++";
        # Driver libcuda.so (/run/opengl-driver/lib) + cuda libs + wheel libs,
        # covering both nix-ld foreign wheels (uv standalone Python) and a
        # nixpkgs-Python venv.
        LD_LIBRARY_PATH = "${ldPath}:/run/opengl-driver/lib";
        NIX_LD_LIBRARY_PATH = "${ldPath}:/run/opengl-driver/lib";
      };

      # colmap for the registration step; coreutils for the launch script.
      path = [
        pkgs.colmap
        pkgs.coreutils
      ];

      serviceConfig = {
        User = "samb";
        Group = "users";
        WorkingDirectory = repo;
        ExecStart = "${pkgs.bash}/bin/bash ${launch}";
        Restart = "on-failure";
        RestartSec = 30;
        # samb has passwordless sudo and this is a long-running network-adjacent
        # job: block privilege escalation for it and anything it spawns.
        NoNewPrivileges = true;
      };
    };
  };
}
