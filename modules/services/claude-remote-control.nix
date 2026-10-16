{ lib, pkgs, config, ... }:
let
  cfg = config.myServices.claudeRemoteControl;

  # `claude remote-control` (aka `claude rc`) keeps a persistent server on the
  # box that claude.ai/code and the Claude mobile app can spawn sessions on, so
  # sessions live here instead of on the laptop.
  #
  # One server serves one directory, and spawned sessions start there — so a
  # repo's CLAUDE.md, project memory and settings only load if the server runs
  # in that repo. Hence one unit per folder; each shows up in claude.ai/code as
  # its own environment, named below.
  #
  # Auth: there is no separate token. The units run as samb with HOME set, so
  # they reuse samb's normal claude.ai login in ~/.claude/.credentials.json
  # (full-scope OAuth with a refresh token; Claude Code refreshes it in place).
  # `claude setup-token` tokens are inference-only and can't drive Remote
  # Control. If the login ever dies, run `claude` → /login as samb once; the
  # units keep retrying and pick it up.
  #
  # One-time manual prerequisites (state lives in ~/.claude.json, not nix):
  #   * Remote Control consent ("Enable Remote Control? (y/n)") — accepted.
  #   * Workspace trust for each folder: run `claude` there once and accept
  #     (trust is inherited by subfolders). $HOME itself can never be trusted.
  home = "/home/samb";
  folders = {
    programming = "${home}/Programming";
    capturegraph = "${home}/Programming/Research/capturegraph";
    nixos = "${home}/Programming/misc/NixOS-Home-Server";
  };

  mkUnit = name: dir: lib.nameValuePair "claude-rc-${name}" {
    description = "Claude Code Remote Control (claude rc) in ${dir}";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    # Keep retrying forever: a missing trust/login makes rc exit 1, and it
    # should come up on its own once that's fixed, without a manual restart.
    unitConfig.StartLimitIntervalSec = 0;
    # A reprovisioned box without the checkout restored: skip, don't loop.
    unitConfig.ConditionPathIsDirectory = dir;

    environment = {
      HOME = home;
      USER = "samb";
      # rc prefixes auto-generated session names with this.
      CLAUDE_REMOTE_CONTROL_SESSION_NAME_PREFIX = "samb-tower";
    };
    # Spawned sessions run tools (git, nix, nrs, sudo, …) with this PATH, so
    # give them the same view samb gets in a login shell.
    path = [
      "/run/wrappers"
      "/etc/profiles/per-user/samb"
      "/run/current-system/sw"
    ];

    serviceConfig = {
      User = "samb";
      Group = "users";
      WorkingDirectory = dir;
      # No pre-created session: otherwise every boot leaves an empty one in
      # the claude.ai session list. Spawn on demand instead.
      ExecStart = "${pkgs.claude-code}/bin/claude remote-control --name samb-tower/${name} --no-create-session-in-dir";
      Restart = "always";
      RestartSec = 30;
      # Match the fast-shutdown budget used elsewhere; live sessions die with
      # the unit either way.
      TimeoutStopSec = 15;
      # Deliberately no NoNewPrivileges: sessions should be able to sudo
      # (nixos-rebuild) just like an interactive Claude Code session here.
    };
  };
in
{
  options.myServices.claudeRemoteControl.enable =
    lib.mkEnableOption "Claude Code Remote Control servers (spawn sessions from claude.ai/code)";

  config = lib.mkIf cfg.enable {
    systemd.services = lib.mapAttrs' mkUnit folders;
  };
}
