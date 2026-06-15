{ pkgs, ... }:
let
  # `bt-pair` — interactive helper to pair + trust + auto-reconnect a controller.
  # Run over SSH or from a TTY. With no arg it scans and lists controllers;
  # pass a MAC to pair a known one directly (e.g. `bt-pair AC:FD:93:09:79:9A`).
  bt-pair = pkgs.writeShellApplication {
    name = "bt-pair";
    runtimeInputs = [ pkgs.bluez pkgs.gnugrep ];
    text = ''
      bluetoothctl power on        >/dev/null
      bluetoothctl agent on        >/dev/null
      bluetoothctl default-agent   >/dev/null

      if [ "$#" -ge 1 ]; then
        mac="$1"
      else
        echo "Put the controller in pairing mode now:"
        echo "  • DualShock 4: hold Share + PS until the lightbar double-flashes"
        echo "  • Stadia:      hold Y + Stadia until the light pulses orange"
        echo
        echo "Scanning for 15s..."
        bluetoothctl --timeout 15 scan on >/dev/null 2>&1 || true
        echo
        echo "Discovered controllers:"
        bluetoothctl devices \
          | grep -iE 'wireless controller|dualshock|dualsense|stadia|xbox|8bitdo|controller' \
          || { echo "  (none matched - showing all:)"; bluetoothctl devices; }
        echo
        read -rp "Enter the MAC to pair: " mac
      fi

      echo "Pairing $mac ..."
      bluetoothctl pair    "$mac" || true
      bluetoothctl trust   "$mac" || true
      bluetoothctl connect "$mac"
      echo "Done - '$mac' is trusted and will auto-reconnect on power-on."
    '';
  };
in
{
  # Xbox (incl. wireless), DualShock4, Stadia. Steam Input handles the rest.
  hardware.steam-hardware.enable = true; # udev + uinput
  hardware.xpadneo.enable = true; # Xbox over Bluetooth

  environment.systemPackages = [ bt-pair ];

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General = {
      Experimental = true;
      FastConnectable = true;
      MultiProfile = "multiple";
    };
  };

  # Let a controller wake the box; keep servers up (no auto-suspend).
  # BIOS F15a: enable ErP / Wake-on-USB for the wakeup rule to fire.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", DRIVER=="usb", ATTR{power/wakeup}="enabled"
    KERNEL=="hidraw*", ATTRS{idVendor}=="054c", MODE="0660", TAG+="uaccess"
    KERNEL=="hidraw*", ATTRS{idVendor}=="18d1", MODE="0660", TAG+="uaccess"
  '';

  services.logind.settings.Login.IdleAction = "ignore";

  # Active reconnect poller for trusted controllers.
  #
  # The Stadia pad speaks Bluetooth LE (HOGP), not classic BR/EDR. A DS4/Xbox
  # pad *pages the host* itself on power-on, so bluez reconnects it reliably; a
  # Stadia only briefly *advertises*, and bluez's passive background scan
  # intermittently misses that window. When it misses, the LE link may come up
  # but the HID profile never binds, so the pad looks dead and you end up doing
  # the forget-and-re-add dance. Having the host actively initiate the
  # connection closes that race. (Confirmed on this box: the kernel `stadia`
  # driver rebinds on some reconnects but not others — see `journalctl -k`.)
  #
  # Generic over any trusted input-gaming device; a connected pad is skipped so
  # this never interferes with an in-progress session.
  systemd.services.controller-reconnect = {
    description = "Reconnect trusted Bluetooth game controllers";
    after = [ "bluetooth.target" ];
    serviceConfig.Type = "oneshot";
    path = [ pkgs.bluez pkgs.gnugrep pkgs.gawk pkgs.coreutils ];
    script = ''
      bluetoothctl devices Trusted | awk '{print $2}' | while read -r mac; do
        info=$(bluetoothctl info "$mac" 2>/dev/null) || continue
        grep -q "Icon: input-gaming" <<<"$info" || continue   # controllers only
        grep -q "Connected: yes"     <<<"$info" && continue   # already up, leave it
        timeout 8 bluetoothctl connect "$mac" >/dev/null 2>&1 || true
      done
    '';
  };

  systemd.timers.controller-reconnect = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "20s";
      OnUnitInactiveSec = "20s"; # 20s after each run finishes (no overlap)
      AccuracySec = "2s";
    };
  };
}
