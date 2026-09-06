{ config, lib, ... }:
{
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
    authKeyFile = config.sops.secrets."tailscale/authkey".path;

    # Don't let tailscaled own /etc/resolv.conf. With accept-dns on, the ONLY
    # nameserver on this box was 100.100.100.100 and tailscaled forwarded to
    # whatever upstream it had scraped from NetworkManager. On 2026-09-06 the
    # WiFi dropped at 03:00, tailscaled came back with "no upstream resolvers
    # set, returning SERVFAIL", and every DNS lookup on the box failed for 12
    # hours (cloudflared -> capture-graph.org down, syncthing, upgrades...).
    # With this off, resolv.conf is just what DHCP hands NetworkManager and
    # DNS no longer depends on tailscaled's health. Cost: MagicDNS names
    # (host.tail8e3d7f.ts.net) don't resolve from this box; use `tailscale ip`.
    extraSetFlags = [ "--accept-dns=false" ];
  };

  # Trust the tailnet wholesale: any service that isn't explicitly opened to the
  # LAN (openFirewall / allowedTCPPorts) is still reachable over Tailscale.
  # This is what makes the admin UIs (Homepage :8082, Syncthing GUI :8384)
  # Tailscale-only.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # Disable reverse-path filtering. With useRoutingFeatures = "client", tailscale
  # sets up policy routing (fwmark 0x80000 + peer routes in table 52), and the
  # firewall's rpfilter --validmark then drops inbound tailnet packets (their
  # marked route lookup hits the "unreachable" rule instead of table 52),
  # silently blocking SSH and all services over Tailscale. The upstream tailscale
  # module sets this to "loose", but loose still drops here, so mkForce false.
  networking.firewall.checkReversePath = lib.mkForce false;
}
