{ config, ... }:
{
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
    authKeyFile = config.sops.secrets."tailscale/authkey".path;
  };

  # Trust the tailnet wholesale: any service that isn't explicitly opened to the
  # LAN (openFirewall / allowedTCPPorts) is still reachable over Tailscale.
  # This is what makes the admin UIs (AdGuard :3000, Homepage :8082,
  # Syncthing GUI :8384) Tailscale-only.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
