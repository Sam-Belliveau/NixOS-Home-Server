{ ... }:
{
  # Always on: the only recovery path on a single-GPU box.
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PermitRootLogin = "no";
      # Password login allowed (LAN brute-force surface; acceptable for a home box).
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = false;
    };
  };
}
