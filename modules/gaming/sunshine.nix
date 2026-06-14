{ pkgs, ... }:
{
  # Stream this box to Moonlight clients (NVENC).
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };

  environment.systemPackages = [ pkgs.moonlight-qt ];
}
