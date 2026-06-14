{ pkgs, ... }:
{
  # Interpreter + project tooling only; never pip-install into this Python.
  environment.systemPackages = with pkgs; [
    python3
    uv
    pipx
    micromamba
  ];
}
