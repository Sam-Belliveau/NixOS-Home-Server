{ config, pkgs, ... }:
let
  pythonEnv = pkgs.python3.withPackages (ps: [ ps.evdev ]);

  brightnessDaemon = pkgs.writeText "ddc-brightness-daemon.py" ''
    """Guide + DPad Up/Down -> DDC monitor brightness +/-10."""
    import asyncio, os
    from evdev import InputDevice, ecodes, list_devices

    STEP = 10
    BL_ROOT = "/sys/class/backlight"

    def find_backlight():
        try:
            devs = sorted(d for d in os.listdir(BL_ROOT) if d.startswith("ddcci"))
            return f"{BL_ROOT}/{devs[0]}" if devs else None
        except Exception:
            return None

    def adjust(delta):
        bl = find_backlight()
        if not bl:
            return
        try:
            cur = int(open(f"{bl}/brightness").read())
            mx  = int(open(f"{bl}/max_brightness").read())
            nv  = max(0, min(mx, cur + delta))
            open(f"{bl}/brightness", "w").write(str(nv))
        except PermissionError:
            import subprocess, shutil
            if shutil.which("ddcutil"):
                cur2 = int(open(f"{bl}/brightness").read()) if bl else 50
                subprocess.run(["ddcutil", "setvcp", "0x10", str(max(0, min(100, cur2 + delta)))],
                               capture_output=True)
        except Exception:
            pass

    async def watch(path, active):
        try:
            dev = InputDevice(path)
            if ecodes.BTN_MODE not in dev.capabilities().get(ecodes.EV_KEY, []):
                return
            active.add(path)
            guide = False
            async for ev in dev.async_read_loop():
                if ev.type == ecodes.EV_KEY and ev.code == ecodes.BTN_MODE:
                    guide = ev.value == 1
                elif guide and ev.type == ecodes.EV_ABS and ev.code == ecodes.ABS_HAT0Y:
                    if ev.value == -1:
                        adjust(STEP)
                    elif ev.value == 1:
                        adjust(-STEP)
        except OSError:
            pass
        finally:
            active.discard(path)

    async def main():
        active, tasks = set(), {}
        while True:
            for path in list_devices():
                if path not in active:
                    tasks[path] = asyncio.create_task(watch(path, active))
            tasks = {p: t for p, t in tasks.items() if not t.done()}
            await asyncio.sleep(5)

    asyncio.run(main())
  '';
in
{
  hardware.i2c.enable = true;

  boot.extraModprobeConfig = ''
    options nvidia NVreg_RegistryDwords=RMUseSwI2c=0x01;RMI2cSpeed=100
  '';

  boot.extraModulePackages = [ config.boot.kernelPackages.ddcci-driver ];
  boot.kernelModules = [ "ddcci_backlight" ];

  services.udev.extraRules = ''
    # NVIDIA i2c adapters can be unready when ddcci probes at module load;
    # defer binding until udev fires for each adapter.
    ACTION=="add", SUBSYSTEM=="i2c", IMPORT{parent}="DRIVER"
    ACTION=="add", SUBSYSTEM=="i2c", ENV{DRIVER}=="nvidia", ATTR{new_device}="ddcci 0x37"
    # Make the brightness node writable so the daemon can write without root.
    SUBSYSTEM=="backlight", KERNEL=="ddcci*", RUN+="${pkgs.coreutils}/bin/chmod a+w /sys/class/backlight/%k/brightness"
  '';

  environment.systemPackages = [ pkgs.ddcutil ];

  # Watches all gamepads for Guide + DPad Up/Down and adjusts DDC brightness.
  systemd.services.ddc-brightness = {
    description = "DDC brightness control via gamepad Guide+DPad";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udevd.service" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pythonEnv}/bin/python3 ${brightnessDaemon}";
      User = "samb";
      Restart = "always";
      RestartSec = "3s";
    };
  };
}
