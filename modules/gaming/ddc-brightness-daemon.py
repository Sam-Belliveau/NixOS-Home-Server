"""Guide + DPad Up/Down -> DDC monitor brightness with quadratic acceleration."""

import asyncio
import os
import time
from evdev import InputDevice, ecodes, list_devices

BL_ROOT = "/sys/class/backlight"


def find_backlight():
    try:
        devs = sorted(d for d in os.listdir(BL_ROOT) if d.startswith("ddcci"))
        return f"{BL_ROOT}/{devs[0]}" if devs else None
    except Exception:
        return None


async def hat_accelerate(direction):
    """Adjust brightness repeatedly while DPad is held, ramping quadratically
    from the starting value to the full range over ~1s."""
    start = time.monotonic()
    bl = find_backlight()
    if not bl:
        return
    mx = int(open(f"{bl}/max_brightness").read())
    cur = int(open(f"{bl}/brightness").read())
    while True:
        elapsed = time.monotonic() - start
        delta = int(max(10, mx * (elapsed / 1) ** 2))
        nv = max(0, min(mx, cur + direction * delta))
        print(f"adjust: cur={cur} mx={mx} nv={nv}", flush=True)
        open(f"{bl}/brightness", "w").write(str(nv))
        await asyncio.sleep(0.005)


async def watch(path, active):
    hat_task = None
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
                if not guide and hat_task:
                    hat_task.cancel()
                    hat_task = None
            elif ev.type == ecodes.EV_ABS and ev.code == ecodes.ABS_HAT0Y:
                print(f"HAT0Y={ev.value} guide={guide} on {dev.name}", flush=True)
                if hat_task:
                    hat_task.cancel()
                    hat_task = None
                if guide and ev.value != 0:
                    # HAT0Y=-1 is DPad Up (brighter); +1 is DPad Down (dimmer)
                    direction = 1 if ev.value == -1 else -1
                    hat_task = asyncio.create_task(hat_accelerate(direction))
    except OSError:
        pass
    finally:
        active.discard(path)
        if hat_task:
            hat_task.cancel()


async def main():
    active, tasks = set(), {}
    while True:
        for path in list_devices():
            if path not in active:
                tasks[path] = asyncio.create_task(watch(path, active))
        tasks = {p: t for p, t in tasks.items() if not t.done()}
        await asyncio.sleep(5)


asyncio.run(main())
