{ ... }:
{
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;

    # Assertive Bluetooth audio. This box shares headsets/speakers with phones
    # and laptops. A multipoint headset plays to whichever source is *actively*
    # streaming; by default PipeWire suspends a Bluetooth sink the moment
    # nothing is playing, so the host goes quiet and the headset sticks with the
    # phone - which is why audio "won't play until you disconnect it elsewhere".
    # These rules make the host grab the link and hold it open instead.
    wireplumber.extraConfig."51-assertive-bluetooth" = {
      "monitor.bluez.properties" = {
        # Prefer high-quality A2DP, enable the better codecs, and auto-(re)bind
        # the media role on connect.
        "bluez5.enable-sbc-xq" = true;
        "bluez5.enable-msbc" = true;
        "bluez5.enable-hw-volume" = true;
        "bluez5.roles" = [
          "a2dp_sink"
          "a2dp_source"
          "bap_sink"
          "bap_source"
          "hfp_hf"
          "hfp_ag"
        ];
        "bluez5.auto-connect" = [
          "a2dp_sink"
          "a2dp_source"
        ];
      };

      "wireplumber.settings" = {
        # Stay on high-quality A2DP for playback instead of dropping to the
        # tinny HSP/HFP headset profile.
        "bluetooth.autoswitch-to-headset-profile" = false;
        # When a headset (re)appears and becomes the default, pull the running
        # streams over to it so audio actually follows the headphones.
        "linking.follow-default-target" = true;
        "linking.allow-moving-streams" = true;
      };

      "monitor.bluez.rules" = [
        {
          matches = [ { "device.name" = "~bluez_card.*"; } ];
          # Land on the A2DP sink profile as soon as the card shows up.
          actions.update-props."device.profile" = "a2dp-sink";
        }
        {
          matches = [ { "node.name" = "~bluez_output.*"; } ];
          actions.update-props = {
            # Never let the Bluetooth sink idle: holding the A2DP transport
            # open keeps THIS host the "active" source, which is what makes a
            # multipoint headset play here without unpairing it from the phone.
            "session.suspend-timeout-seconds" = 0;
            # Outrank the onboard/HDMI sinks for default-sink selection so a
            # connected headset becomes the default output automatically. (Only
            # priority.session; leave priority.driver alone so a high-latency BT
            # link never becomes the graph clock driver.)
            "priority.session" = 2000;
          };
        }
      ];
    };
  };
}
