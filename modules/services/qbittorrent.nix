{ lib, config, ... }:
let
  cfg = config.myServices.qbittorrent;
  torrentPort = 50413;
  mediaRoot = "/srv/media";
  profileDir = config.services.qbittorrent.profileDir;
in
{
  options.myServices.qbittorrent.enable = lib.mkEnableOption "qBittorrent download portal";

  config = lib.mkIf cfg.enable {
    services.qbittorrent = {
      enable = true;
      webuiPort = 8080;
      torrentingPort = torrentPort;
      # openFirewall would also expose the WebUI to the LAN; keep that
      # Tailscale-only (trustedInterfaces) and open just the peer port below.
      openFirewall = false;

      # NOTE: this file is regenerated from serverConfig on every service start,
      # so settings changed in the WebUI do not survive a restart - change them
      # here instead. Categories (see preStart below) DO persist.
      serverConfig = {
        LegalNotice.Accepted = true;
        BitTorrent.Session = {
          DefaultSavePath = "${mediaRoot}/downloads";
          TempPath = "${mediaRoot}/downloads/incomplete";
          TempPathEnabled = true;
          # Auto Torrent Management on by default: picking the "movies" / "tv"
          # category routes the finished download to the matching library dir.
          DisableAutoTMMByDefault = false;
        };
        Preferences.WebUI = {
          Username = "samb";
          # PBKDF2-HMAC-SHA512. Regenerate (and update this) with:
          #   python3 -c 'import hashlib,os,base64,getpass; s=os.urandom(16); p=getpass.getpass().encode(); print("@ByteArray("+base64.b64encode(s).decode()+":"+base64.b64encode(hashlib.pbkdf2_hmac("sha512",p,s,100000,64)).decode()+")")'
          Password_PBKDF2 = ''"@ByteArray(j4b10Vrr1lHd21YT3K/ZjA==:1c9CyIByPBFbOkgd2evzV1zfqdk34E5YoqYHATJ2veN5P4ZgEYsnQu4CiwKGjBXRifkTCo8rWhI0NhYQjOFMMQ==)"'';
          LocalHostAuth = false;
        };
      };
    };

    # Peer connectivity only (TCP + uTP/DHT over UDP); WebUI stays closed.
    networking.firewall.allowedTCPPorts = [ torrentPort ];
    networking.firewall.allowedUDPPorts = [ torrentPort ];

    # Media tree shared with Jellyfin: qbittorrent owns and writes, jellyfin
    # reads (media group + world-read). Setgid keeps new dirs group "media".
    systemd.tmpfiles.rules = [
      "d ${mediaRoot} 2775 root media -"
      "d ${mediaRoot}/movies 2775 qbittorrent media -"
      "d ${mediaRoot}/tv 2775 qbittorrent media -"
      "d ${mediaRoot}/downloads 2775 qbittorrent media -"
      "d ${mediaRoot}/downloads/incomplete 2775 qbittorrent media -"
    ];

    users.groups.media = { };
    users.users.qbittorrent.extraGroups = [ "media" ];

    systemd.services.qbittorrent = {
      # Group-writable downloads so jellyfin (media group) can read everything.
      serviceConfig.UMask = "0002";
      # Seed the movies/tv categories once; qBittorrent manages the file after.
      preStart = ''
        categories="${profileDir}/qBittorrent/config/categories.json"
        if [ ! -f "$categories" ]; then
          printf '%s\n' '{"movies": {"save_path": "${mediaRoot}/movies"}, "tv": {"save_path": "${mediaRoot}/tv"}}' > "$categories"
        fi
      '';
    };
  };
}
