{ ... }:
{
  boot.tmp.cleanOnBoot = true;

  # Keep the journal from silently filling the disk.
  services.journald.extraConfig = ''
    SystemMaxUse=2G
  '';
}
