#!/usr/bin/env python3
"""Generate Steam non-Steam shortcuts (shortcuts.vdf) without Electron/SRM.

Steam ROM Manager is an Electron app and hangs when run headless at boot, so we
can't use it to populate Game Mode. This reproduces the only part we need: read
SRM's declarative parser config (userConfigurations.json) plus its manual app
manifests, glob the ROM folders, and write a binary shortcuts.vdf directly.

It is idempotent: a sidecar file records the appids we created, so re-runs
replace our own entries while leaving any shortcuts the user added by hand
untouched.

Run with `--artwork` to instead download SteamGridDB art (portrait, grid, hero,
logo) for every shortcut into Steam's grid/ folder. This needs a key in
$STEAMGRIDDB_KEY_FILE (or $STEAMGRIDDB_KEY) and network access, so it runs as a
separate, non-boot-blocking pass; the default mode never touches the network.
"""

import binascii
import glob
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

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
# When set, every shortcut launches through this wrapper, which scrubs the
# steam-runtime LD_LIBRARY_PATH that otherwise kills Nix-built binaries.
LAUNCH_WRAPPER = os.environ.get("LAUNCH_WRAPPER", "")

# SteamGridDB sits behind Cloudflare, which 403s the default "Python-urllib/x.y"
# User-Agent. A browser-like UA gets through; without this every art lookup
# fails with HTTP 403 and no shortcut ever gets a banner.
USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) nix-steam-shortcuts/1.0"


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
    real = '"' + exe + '"'
    if LAUNCH_WRAPPER:
        # Exe -> wrapper; the real command (+ its args) moves into LaunchOptions
        # so Steam runs: <wrapper> <real-exe> <args>.
        exe_field = '"' + LAUNCH_WRAPPER + '"'
        launch = real + ((" " + launch_options) if launch_options else "")
    else:
        exe_field = real
        launch = launch_options
    uid = shortcut_appid(exe_field, title)
    return {
        "appid": to_signed32(uid),
        "AppName": title,
        "Exe": exe_field,
        "StartDir": '"' + start_dir + '"',
        "icon": "",
        "ShortcutPath": "",
        "LaunchOptions": launch,
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


# SteamGridDB indexes some apps under a different name than our shortcut title
# (Vesktop is a Discord client, etc.). Map title -> the term we should search.
QUERY_OVERRIDES = {
    "Vesktop": "Discord",
}


def clean_query(title):
    """Strip region/language tags so a ROM title matches on SteamGridDB.

    Filenames like "Skate 3 (USA, Asia) (En,Fr,Es)" never autocomplete-match;
    SRM handles this with fuzzyMatch.removeBrackets, which our generator mirrors
    here. Drops any (...)/[...]/{...} groups and collapses the leftover spaces.
    """
    stripped = re.sub(r"[\(\[\{][^\(\)\[\]\{\}]*[\)\]\}]", " ", title)
    return re.sub(r"\s+", " ", stripped).strip() or title


def entries_from_glob_parser(parser):
    """Return [(vdf_entry, art_query), ...] for a glob (ROM) parser."""
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
            title = match.group("title")
            launch = args.replace("${filePath}", path)
            entry = make_entry(title, exe, launch,
                               os.path.dirname(exe), categories)
            query = QUERY_OVERRIDES.get(title) or clean_query(title)
            entries.append((entry, query))
    log(parser.get("configTitle"), "->", len(entries), "roms")
    return entries


def entries_from_manual_parser(parser):
    """Return [(vdf_entry, art_query), ...] for a manual (apps) parser."""
    manifest_dir = parser["parserInputs"]["manualManifests"]
    categories = parser.get("steamCategories", [])
    entries = []
    for manifest in sorted(glob.glob(os.path.join(manifest_dir, "*.json"))):
        with open(manifest) as handle:
            apps = json.load(handle)
        for app in apps:
            exe = app["target"]
            start = app.get("startIn") or os.path.dirname(exe)
            title = app["title"]
            entry = make_entry(title, exe,
                               app.get("launchOptions", ""), start, categories)
            query = app.get("imageQuery") or QUERY_OVERRIDES.get(title, title)
            entries.append((entry, query))
    log(parser.get("configTitle"), "->", len(entries), "apps")
    return entries


def build_entries():
    """Return (entries, queries): the vdf entries and {appid: art_query}."""
    config = os.path.join(SRM_DIR, "userData", "userConfigurations.json")
    with open(config) as handle:
        parsers = json.load(handle)
    pairs = []
    for parser in parsers:
        kind = parser.get("parserType")
        try:
            if kind == "Glob":
                pairs += entries_from_glob_parser(parser)
            elif kind == "Manual":
                pairs += entries_from_manual_parser(parser)
            else:
                log("skip unknown parser type", kind)
        except Exception as err:  # one bad parser shouldn't sink the rest
            log("parser error", parser.get("configTitle"), repr(err))
    entries = [entry for entry, _ in pairs]
    queries = {norm_appid(entry["appid"]): query for entry, query in pairs}
    return entries, queries


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


SGDB_API = "https://www.steamgriddb.com/api/v2"


def sgdb_key():
    path = os.environ.get("STEAMGRIDDB_KEY_FILE")
    if path and os.path.exists(path):
        with open(path) as handle:
            return handle.read().strip()
    return os.environ.get("STEAMGRIDDB_KEY", "").strip()


def sgdb_get(key, path, params=None):
    url = SGDB_API + path
    if params:
        url += "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={
        "Authorization": "Bearer " + key,
        "User-Agent": USER_AGENT,
    })
    with urllib.request.urlopen(req, timeout=20) as resp:
        return json.load(resp)


def sgdb_game_id(key, term):
    data = sgdb_get(key, "/search/autocomplete/" + urllib.parse.quote(term))
    items = data.get("data") or []
    if not items:
        return None
    # Autocomplete orders by popularity, which can rank a spin-off ahead of the
    # entry that actually has art (e.g. "YouTube VR" before "YouTube (Website)").
    # Prefer a candidate whose name equals the query once a trailing
    # "(Website)"/"(Program)" qualifier and case are ignored; fall back to first.
    want = term.casefold()
    for item in items:
        name = re.sub(r"\s*\((?:website|program)\)\s*$", "",
                      item.get("name", ""), flags=re.I)
        if name.casefold() == want:
            return item["id"]
    return items[0]["id"]


def sgdb_first_url(key, kind, game_id, params=None):
    try:
        data = sgdb_get(key, "/%s/game/%d" % (kind, game_id), params)
    except urllib.error.HTTPError as err:
        log("sgdb", kind, "http", err.code, "for", game_id)
        return None
    items = data.get("data") or []
    return items[0]["url"] if items else None


def fetch(url, dest):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = resp.read()
    tmp = dest + ".tmp"
    with open(tmp, "wb") as handle:
        handle.write(data)
    os.replace(tmp, dest)


def download_all_art(queries):
    """Download SteamGridDB art for each appid into every account's grid/ dir."""
    key = sgdb_key()
    if not key:
        log("no SteamGridDB key; skipping artwork")
        return 0
    grids = [
        os.path.join(c, "grid")
        for c in glob.glob(os.path.join(STEAM_ROOT, "userdata", "*", "config"))
    ]
    if not grids:
        log("no userdata/*/config dirs - Steam not signed in?")
        return 0
    for grid in grids:
        os.makedirs(grid, exist_ok=True)

    # filename suffix -> (SteamGridDB asset kind, request params)
    art = [
        ("p.png", "grids", {"dimensions": "600x900"}),     # library portrait
        (".png", "grids", {"dimensions": "460x215,920x430"}),  # wide capsule
        ("_hero.png", "heroes", None),
        ("_logo.png", "logos", None),
    ]
    for uid, term in queries.items():
        # The portrait is the sentinel: if it exists everywhere, this app is
        # already done, so we don't re-hit the API on every boot.
        if all(os.path.exists(os.path.join(g, "%dp.png" % uid)) for g in grids):
            continue
        try:
            game_id = sgdb_game_id(key, term)
        except Exception as err:
            log("sgdb search failed", term, repr(err))
            continue
        if not game_id:
            log("no sgdb match for", term)
            continue
        for suffix, kind, params in art:
            url = sgdb_first_url(key, kind, game_id, params)
            if not url:
                continue
            for grid in grids:
                dest = os.path.join(grid, "%d%s" % (uid, suffix))
                if os.path.exists(dest):
                    continue
                try:
                    fetch(url, dest)
                except Exception as err:
                    log("download failed", dest, repr(err))
        log("art for", term, "->", game_id)
    return 0


def main():
    artwork = "--artwork" in sys.argv
    entries, queries = build_entries()
    log("total", len(entries), "shortcuts")
    if artwork:
        return download_all_art(queries)
    if not entries:
        log("nothing to write; leaving shortcuts.vdf untouched")
        return 0
    return write_shortcuts(entries)


if __name__ == "__main__":
    sys.exit(main())
