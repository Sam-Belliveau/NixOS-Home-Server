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

  # Disable reverse-path filtering. With useRoutingFeatures = "client", tailscale
  # sets up policy routing (fwmark 0x80000 + peer routes in table 52), and the
  # firewall's rpfilter --validmark then drops inbound tailnet packets (their
  # marked route lookup hits the "unreachable" rule instead of table 52). That
  # silently blocks SSH and all services over Tailscale. Safe on a NAT'd box.
  networking.firewall.checkReversePath = false;
}
