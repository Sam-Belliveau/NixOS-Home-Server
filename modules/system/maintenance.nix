{ ... }:
{
  boot.tmp.cleanOnBoot = true;

  # Fast, bounded shutdowns. systemd's default gives every unit 90s to react
  # to SIGTERM and then ANOTHER 90s after SIGKILL before giving up; on
  # 2026-09-06 a reboot spent 3 minutes in exactly that (see controllers.nix
  # for the root cause). Nothing on this box needs more than a few seconds to
  # stop, so cap it: a wedged service costs 15s, not 3 minutes.
  systemd.settings.Manager.DefaultTimeoutStopSec = "15s";
  systemd.user.settings.Manager.DefaultTimeoutStopSec = "15s";

  # Jovian's steam-launcher ships its own TimeoutStopSec=60 and Steam
  # regularly ignores SIGTERM at shutdown, so that unit alone ate a full
  # minute. It gets SIGKILLed either way; do it after 15s.
  systemd.user.services.steam-launcher = {
    overrideStrategy = "asDropin";
    serviceConfig.TimeoutStopSec = "15s";
  };

  # NetworkManager only logged warnings, which made the 2026-09-06 WiFi/DNS
  # outage impossible to reconstruct (no activation/state-change lines). INFO
  # is the upstream default and cheap.
  networking.networkmanager.logLevel = "INFO";

  # Keep the journal from silently filling the disk.
  services.journald.extraConfig = ''
    SystemMaxUse=2G
  '';
}
