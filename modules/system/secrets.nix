{ ... }:
{
  # Age identity is the box's SSH host key (persisted on the install USB).
  # See SECRETS.md.
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age = {
      # The SSH host key *is* the age identity. No separately generated key:
      # nothing is encrypted to one and it isn't a recipient in .sops.yaml.
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    };

    secrets = {
      "samb/hashedPassword".neededForUsers = true;
      "cloudflared/token" = { };
      "tailscale/authkey" = { };
      "steamgriddb/apikey".owner = "samb";
    };
  };
}
