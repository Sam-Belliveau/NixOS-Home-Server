# Secrets

Secrets are encrypted with [sops-nix](https://github.com/Mic92/sops-nix) and
committed (encrypted) as `secrets/secrets.yaml`. The decryption key is an age
identity derived from the machine's SSH host key, so only this box can read them.
The raw host key is the single persisted secret: it lives on the install USB's
`SAMOS-SECRETS` partition, never in the repo.

## What is stored

| Key | Used by |
|-----|---------|
| `samb/hashedPassword` | the `samb` login + sudo |
| `cloudflared/credentials` | the Cloudflare tunnel |
| `tailscale/authkey` | unattended Tailscale join |
| `steamgriddb/apikey` | ROM artwork lookups |

## First-time setup

```bash
# 1. Generate the machine's age-capable host key (also copied to the USB).
ssh-keygen -t ed25519 -f ./ssh_host_ed25519_key -N "" -C samb-tower

# 2. Derive its age public key and your own.
nix run nixpkgs#ssh-to-age -- < ./ssh_host_ed25519_key.pub   # -> age1...

# 3. Put both pubkeys in .sops.yaml (the host one as &samb_tower).

# 4. Add the secrets (opens $EDITOR with a decrypted view).
nix run nixpkgs#sops -- secrets/secrets.yaml
```

`secrets.yaml` is keyed by integration, for example:

```yaml
samb:
  hashedPassword: "$y$..."
cloudflared:
  credentials: |
    { "AccountTag": "...", "TunnelID": "...", "TunnelSecret": "..." }
tailscale:
  authkey: "tskey-auth-..."
steamgriddb:
  apikey: "..."
```

## Rotating recipients

After changing `.sops.yaml`, re-encrypt to the new key set:

```bash
nix run nixpkgs#sops -- updatekeys secrets/secrets.yaml
```

## Reinstall

The USB carries `ssh_host_ed25519_key`; `install.sh` drops it into `/etc/ssh/`, so
the rebuilt machine decrypts the same `secrets.yaml` with no manual steps.
