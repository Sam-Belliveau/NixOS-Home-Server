"""Guide + DPad Up/Down -> DDC monitor brightness +/-10."""
import asyncio, os, shutil, subprocess
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
    print(f"adjust({delta}) bl={bl}", flush=True)
    if not bl:
        return
    try:
        cur = int(open(f"{bl}/brightness").read())
        mx  = int(open(f"{bl}/max_brightness").read())
        nv  = max(0, min(mx, cur + delta))
        print(f"adjust: cur={cur} mx={mx} nv={nv}", flush=True)
        open(f"{bl}/brightness", "w").write(str(nv))
        print("adjust: write ok", flush=True)
    except PermissionError:
        if shutil.which("ddcutil"):
            cur2 = int(open(f"{bl}/brightness").read()) if bl else 50
            subprocess.run(
                ["ddcutil", "setvcp", "0x10", str(max(0, min(100, cur2 + delta)))],
                capture_output=True,
            )
    except Exception as e:
        print(f"adjust: error {e!r}", flush=True)


async def watch(path, active):
    try:
        dev = InputDevice(path)
        if ecodes.BTN_MODE not in dev.capabilities().get(ecodes.EV_KEY, []):
            return
        active.add(path)
        print(f"watching {dev.name} ({path})", flush=True)
        guide = False
        async for ev in dev.async_read_loop():
            if ev.type == ecodes.EV_KEY and ev.code == ecodes.BTN_MODE:
                guide = ev.value == 1
                print(f"BTN_MODE={ev.value} on {dev.name}", flush=True)
            elif ev.type == ecodes.EV_ABS and ev.code == ecodes.ABS_HAT0Y:
                print(f"HAT0Y={ev.value} guide={guide} on {dev.name}", flush=True)
            if guide and ev.type == ecodes.EV_ABS and ev.code == ecodes.ABS_HAT0Y:
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
