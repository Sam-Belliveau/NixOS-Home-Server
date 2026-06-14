{ ... }:
{
  # Xbox (incl. wireless), DualShock4, Stadia. Steam Input handles the rest.
  hardware.steam-hardware.enable = true; # udev + uinput
  hardware.xpadneo.enable = true; # Xbox over Bluetooth

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
}
