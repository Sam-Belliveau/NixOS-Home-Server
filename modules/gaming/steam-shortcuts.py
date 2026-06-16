#!/usr/bin/env python3
"""Generate Steam non-Steam shortcuts (shortcuts.vdf) without Electron/SRM.

Steam ROM Manager is an Electron app and hangs when run headless at boot, so we
can't use it to populate Game Mode. This reproduces the only part we need: read
SRM's declarative parser config (userConfigurations.json) plus its manual app
manifests, glob the ROM folders, and write a binary shortcuts.vdf directly.

It is idempotent: a sidecar file records the appids we created, so re-runs
replace our own entries while leaving any shortcuts the user added by hand
untouched. Artwork (SteamGridDB) is intentionally out of scope here.
"""

import binascii
import glob
import json
import os
import re
import sys

import vdf

HOME = os.environ["HOME"]
SRM_DIR = os.environ.get(
    "SRM_CONFIG_DIR", os.path.join(HOME, ".config", "steam-rom-manager")
)
STEAM_ROOT = os.environ.get(
    "STEAM_ROOT", os.path.join(HOME, ".steam", "steam")
)
SIDECAR = os.path.join(
    HOME, ".local", "share", "nix-steam-shortcuts", "managed-appids.json"
)


def log(*args):
    print("[steam-shortcuts]", *args, flush=True)


def shortcut_appid(quoted_exe, appname):
    """Steam's shortcut appid: crc32(exe+name) with the top bit set."""
    key = (quoted_exe + appname).encode("utf-8")
    return (binascii.crc32(key) & 0xFFFFFFFF) | 0x80000000


def to_signed32(value):
    return value - 0x100000000 if value >= 0x80000000 else value


def norm_appid(value):
    """Compare appids regardless of signed/unsigned storage."""
    return value & 0xFFFFFFFF if value is not None else None


def make_entry(title, exe, launch_options, start_dir, categories):
    quoted_exe = '"' + exe + '"'
    uid = shortcut_appid(quoted_exe, title)
    return {
        "appid": to_signed32(uid),
        "AppName": title,
        "Exe": quoted_exe,
        "StartDir": '"' + start_dir + '"',
        "icon": "",
        "ShortcutPath": "",
        "LaunchOptions": launch_options,
        "IsHidden": 0,
        "AllowDesktopConfig": 1,
        "AllowOverlay": 1,
        "OpenVR": 0,
        "Devkit": 0,
        "DevkitGameID": "",
        "DevkitOverrideAppID": 0,
        "LastPlayTime": 0,
        "FlatpakAppID": "",
        "tags": {str(i): c for i, c in enumerate(categories)},
    }


def parse_srm_glob(pattern):
    """Translate an SRM glob into (title_regex, [concrete_glob, ...]).

    Handles the two shapes used in practice:
      ${title}@(.iso|.chd)            -> *.iso, *.chd ; title = stem
      ${title}/PS3_GAME/USRDIR/EBOOT.BIN -> */PS3_GAME/... ; title = top dir
    """
    regex = ""
    globs = [""]
    i = 0
    while i < len(pattern):
        if pattern.startswith("${title}", i):
            regex += r"(?P<title>.+?)"
            globs = [g + "*" for g in globs]
            i += len("${title}")
        elif pattern[i] == "@" and pattern[i + 1:i + 2] == "(":
            close = pattern.index(")", i)
            alts = pattern[i + 2:close].split("|")
            regex += "(?:" + "|".join(re.escape(a) for a in alts) + ")"
            globs = [g + a for g in globs for a in alts]
            i = close + 1
        else:
            regex += re.escape(pattern[i])
            globs = [g + pattern[i] for g in globs]
            i += 1
    return re.compile("^" + regex + "$"), globs


def entries_from_glob_parser(parser):
    rom_dir = parser["romDirectory"]
    if not os.path.isdir(rom_dir):
        log("skip", parser.get("configTitle"), "- no dir", rom_dir)
        return []
    exe = parser["executable"]["path"]
    args = parser.get("executableArgs", "")
    categories = parser.get("steamCategories", [])
    title_re, globs = parse_srm_glob(parser["parserInputs"]["glob"])
    entries, seen = [], set()
    for pattern in globs:
        for path in glob.glob(os.path.join(rom_dir, pattern)):
            if path in seen:
                continue
            match = title_re.match(os.path.relpath(path, rom_dir))
            if not match:
                continue
            seen.add(path)
            launch = args.replace("${filePath}", path)
            entries.append(
                make_entry(match.group("title"), exe, launch,
                           os.path.dirname(exe), categories)
            )
    log(parser.get("configTitle"), "->", len(entries), "roms")
    return entries


def entries_from_manual_parser(parser):
    manifest_dir = parser["parserInputs"]["manualManifests"]
    categories = parser.get("steamCategories", [])
    entries = []
    for manifest in sorted(glob.glob(os.path.join(manifest_dir, "*.json"))):
        with open(manifest) as handle:
            apps = json.load(handle)
        for app in apps:
            exe = app["target"]
            start = app.get("startIn") or os.path.dirname(exe)
            entries.append(
                make_entry(app["title"], exe,
                           app.get("launchOptions", ""), start, categories)
            )
    log(parser.get("configTitle"), "->", len(entries), "apps")
    return entries


def build_entries():
    config = os.path.join(SRM_DIR, "userData", "userConfigurations.json")
    with open(config) as handle:
        parsers = json.load(handle)
    entries = []
    for parser in parsers:
        kind = parser.get("parserType")
        try:
            if kind == "Glob":
                entries += entries_from_glob_parser(parser)
            elif kind == "Manual":
                entries += entries_from_manual_parser(parser)
            else:
                log("skip unknown parser type", kind)
        except Exception as err:  # one bad parser shouldn't sink the rest
            log("parser error", parser.get("configTitle"), repr(err))
    return entries


def write_shortcuts(entries):
    accounts = glob.glob(os.path.join(STEAM_ROOT, "userdata", "*", "config"))
    if not accounts:
        log("no userdata/*/config dirs - Steam not signed in?")
        return 1

    prev = set()
    if os.path.exists(SIDECAR):
        try:
            prev = {norm_appid(a) for a in json.load(open(SIDECAR))}
        except Exception:
            prev = set()
    ours = {norm_appid(e["appid"]) for e in entries}

    for config_dir in accounts:
        path = os.path.join(config_dir, "shortcuts.vdf")
        existing = {"shortcuts": {}}
        if os.path.exists(path):
            try:
                with open(path, "rb") as handle:
                    existing = vdf.binary_load(handle)
            except Exception as err:
                log("unreadable, recreating", path, repr(err))
        # Keep shortcuts the user made by hand; drop any we created last run
        # or that would collide with an appid we're about to write.
        preserved = [
            v for v in existing.get("shortcuts", {}).values()
            if norm_appid(v.get("appid")) not in prev
            and norm_appid(v.get("appid")) not in ours
        ]
        combined = preserved + entries
        new_map = {str(i): v for i, v in enumerate(combined)}
        os.makedirs(config_dir, exist_ok=True)
        with open(path, "wb") as handle:
            vdf.binary_dump({"shortcuts": new_map}, handle)
        log("wrote", len(entries), "managed +",
            len(preserved), "preserved ->", path)

    os.makedirs(os.path.dirname(SIDECAR), exist_ok=True)
    with open(SIDECAR, "w") as handle:
        json.dump(sorted(ours), handle)
    return 0


def main():
    entries = build_entries()
    log("total", len(entries), "shortcuts")
    if not entries:
        log("nothing to write; leaving shortcuts.vdf untouched")
        return 0
    return write_shortcuts(entries)


if __name__ == "__main__":
    sys.exit(main())
