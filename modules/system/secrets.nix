{ ... }:
{
  # Age identity is the box's SSH host key (persisted on the install USB).
  # See SECRETS.md.
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age = {
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };

    secrets = {
      "samb/hashedPassword".neededForUsers = true;
      "cloudflared/token" = { };
      "tailscale/authkey" = { };
      "steamgriddb/apikey".owner = "steam";
    };
  };
}
