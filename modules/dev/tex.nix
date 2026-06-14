{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.texliveFull ];
}
