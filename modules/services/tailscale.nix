{ config, lib, ... }:
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
  # marked route lookup hits the "unreachable" rule instead of table 52),
  # silently blocking SSH and all services over Tailscale. The upstream tailscale
  # module sets this to "loose", but loose still drops here, so mkForce false.
  networking.firewall.checkReversePath = lib.mkForce false;
}
