{ pkgs, ... }:
{
  # Stream this box to Moonlight clients (NVENC).
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;

    # The default nixpkgs sunshine is built WITHOUT CUDA, so it has no NVENC
    # encoder and falls back to software x264 (H.264 only) -- NVIDIA VAAPI is
    # decode-only, so there is no other HW path. Rebuild with CUDA to get the
    # NVENC encoder, which enables HEVC (and AV1 on Ada/RTX 40+).
    package = pkgs.sunshine.override {
      cudaSupport = true;
      cudaPackages = pkgs.cudaPackages;
    };
  };

  environment.systemPackages = [ pkgs.moonlight-qt ];
}
