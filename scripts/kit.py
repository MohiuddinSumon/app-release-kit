#!/usr/bin/env python3
"""app-release-kit: turn an Android project into a Play-Store-ready release with one config file.

    python scripts/kit.py init <app_repo>                 # render website, release script, listing, checklists
    python scripts/kit.py listing <app_repo>              # (re)write the store listing files from release-kit.toml
    python scripts/kit.py check <app_repo>                # lint everything Play review usually trips over
    python scripts/kit.py rename-package <app_repo> <new.package> [--namespace] [--dry-run]
    python scripts/kit.py notes <app_repo> [--write]      # draft English release notes from recent commits
    python scripts/kit.py graphics <app_repo>             # feature graphic + framed screenshots (needs Node + Playwright)

Standard library only (Python 3.11+).
"""
from __future__ import annotations

import argparse
import datetime
import json
import re
import shutil
import struct
import subprocess
import sys
import tomllib
from pathlib import Path

KIT = Path(__file__).resolve().parent.parent
TEMPLATES = KIT / "templates"
OK, WARN, FAIL = "PASS", "WARN", "FAIL"


# ----------------------------------------------------------------------------- config
def load_config(app_repo: Path) -> dict:
    dev = tomllib.loads((KIT / "config" / "developer.toml").read_text(encoding="utf-8"))["developer"]
    cfg_path = app_repo / "release-kit.toml"
    if not cfg_path.exists():
        sys.exit(f"{cfg_path} not found. Run `kit.py init {app_repo}` first, then fill it in.")
    raw = tomllib.loads(cfg_path.read_text(encoding="utf-8"))
    app, privacy = raw.get("app", {}), raw.get("privacy", {})

    name = app.get("name", "").strip()
    subtitle = app.get("subtitle", "").strip()
    slug = app.get("slug", "").strip()
    domain = app.get("domain", "").strip() or f"{slug.replace('-', '')}.{dev['base_domain']}"
    ctx = {
        "name": name,
        "subtitle": subtitle,
        "title": f"{name}: {subtitle}" if subtitle else name,
        "slug": slug,
        "package": app.get("package", ""),
        "domain": domain,
        "tagline": app.get("tagline", ""),
        "category": app.get("category", ""),
        "languages": app.get("languages", dev.get("default_languages", ["en-US"])),
        "developer_name": dev["name"],
        "developer_url": dev["play_developer_url"],
        "products_url": dev["products_url"],
        "contact_text": dev["contact_text"],
        "base_domain": dev["base_domain"],
        "privacy_url": f"https://{domain}/privacy",
        "year": str(datetime.date.today().year),
        "date": datetime.date.today().strftime("%d %B %Y"),
        "features": raw.get("features", []),
        "listing": raw.get("listing", {}),
        "graphics": raw.get("graphics", {}),
        "screenshots": raw.get("screenshots", []),
    }
    # [[screens]] drive both the phone-capture script and the framed graphics
    screens = []
    for i, sc in enumerate(raw.get("screens", []), 1):
        name = re.sub(r"[^a-z0-9]+", "-", sc.get("name", f"screen{i}").lower()).strip("-") or f"screen{i}"
        hint = sc.get("hint", sc.get("name", f"Screen {i}"))
        screens.append({
            "file": f"{i:02d}_{name}.png",
            "hint_ps": hint.replace("'", "''"),
            "caption": sc.get("caption", ""),
        })
    ctx["screens"] = screens
    if not ctx["screenshots"]:
        ctx["screenshots"] = [{"file": f"store_assets/raw_screenshots/{sc['file']}", "caption": sc["caption"]} for sc in screens]
    ctx["release_notes_template"] = "".join(
        f"<{lang}>\nWhat's new:\n- \n</{lang}>\n" for lang in ctx["languages"]
    )
    for key, value in privacy.items():
        ctx[key] = value
    return ctx


# ----------------------------------------------------------------------------- template engine
def _truthy(v) -> bool:
    return bool(v) and v not in ("false", "False", "0")


def render(text: str, ctx: dict, escape: bool = False) -> str:
    """{{var}}, {{#if x}}..{{/if}}, {{#unless x}}..{{/unless}}, {{#each list}}..{{/each}} (items' keys are in scope)."""
    esc = (lambda s: str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")) if escape else str

    each = re.compile(r"\{\{#each (\w+)\}\}(.*?)\{\{/each\}\}", re.S)
    while True:
        m = each.search(text)
        if not m:
            break
        body = "".join(render(m.group(2), {**ctx, **item}, escape) for item in ctx.get(m.group(1), []))
        text = text[: m.start()] + body + text[m.end():]

    cond = re.compile(r"\{\{#(if|unless) (\w+)\}\}((?:(?!\{\{#(?:if|unless) ).)*?)\{\{/\1\}\}", re.S)
    while True:
        m = cond.search(text)
        if not m:
            break
        keep = _truthy(ctx.get(m.group(2))) == (m.group(1) == "if")
        text = text[: m.start()] + (m.group(3) if keep else "") + text[m.end():]

    def sub(m):
        key = m.group(1)
        if key not in ctx:
            return m.group(0)
        v = ctx[key]
        return esc(", ".join(v) if isinstance(v, list) else v)

    return re.sub(r"\{\{(\w+)\}\}", sub, text)


def write_rendered(src: Path, dst: Path, ctx: dict, force: bool, report: list):
    if dst.exists() and not force:
        report.append(("skip", dst))
        return
    dst.parent.mkdir(parents=True, exist_ok=True)
    if src.suffix == ".tpl":
        text = render(src.read_text(encoding="utf-8"), ctx, escape=dst.suffix == ".html")
        newline = "\r\n" if dst.suffix in (".bat", ".ps1") else "\n"
        with open(dst, "w", encoding="utf-8", newline="") as f:
            f.write(text.replace("\r\n", "\n").replace("\n", newline))
    else:
        shutil.copy2(src, dst)
    report.append(("write", dst))


# ----------------------------------------------------------------------------- init
def cmd_init(a):
    app = Path(a.app_repo).resolve()
    if not (app / "release-kit.toml").exists():
        shutil.copy2(TEMPLATES / "release-kit.toml", app / "release-kit.toml")
        print(f"Created {app/'release-kit.toml'}. Fill it in (name, package, features, listing), then run init again.")
        return
    ctx = load_config(app)
    report: list = []
    plan = {
        "android/release.ps1.tpl": "release.ps1",
        "android/release.bat.tpl": "release.bat",
        "android/release.sh": "release.sh",
        "android/release-notes.txt.tpl": "release-notes.txt",
        "android/draft-release-notes.ps1.tpl": "draft-release-notes.ps1",
        "android/capture-screenshots.ps1.tpl": "capture-screenshots.ps1",
        "android/capture-screenshots.bat.tpl": "capture-screenshots.bat",
        "android/gitattributes": ".gitattributes",
        "store/PLAY_CONSOLE_CHECKLIST.md.tpl": "docs/PLAY_CONSOLE_CHECKLIST.md",
        "store/PLAY_STORE_PERMISSIONS.md.tpl": "docs/PLAY_STORE_PERMISSIONS.md",
        "website/index.html.tpl": "website/index.html",
        "website/privacy.html.tpl": "website/privacy.html",
        "website/terms.html.tpl": "website/terms.html",
        "website/site.css": "website/site.css",
        "website/vercel.json": "website/vercel.json",
        "website/robots.txt.tpl": "website/robots.txt",
        "website/sitemap.xml.tpl": "website/sitemap.xml",
        "website/README.md.tpl": "website/README.md",
        "ci/release.yml.tpl": ".github/workflows/release.yml.disabled",
    }
    for src, dst in plan.items():
        write_rendered(TEMPLATES / src, app / dst, ctx, a.force, report)

    # website icon comes from the store icon
    icon = next((p for p in [app / "store_assets/icon_512x512.png", app / "store_assets/icon.png"] if p.exists()), None)
    if icon:
        shutil.copy2(icon, app / "website/icon.png")

    # .gitignore: secrets and build output
    gi = app / ".gitignore"
    existing = gi.read_text(encoding="utf-8") if gi.exists() else ""
    needed = ["*.jks", "*.keystore", "keystore.properties", "/release"]
    add = [line for line in needed if line not in existing.splitlines()]
    if add:
        gi.write_text(existing.rstrip("\n") + "\n\n# Release signing / build output (app-release-kit)\n" + "\n".join(add) + "\n", encoding="utf-8")
        report.append(("write", gi))

    if (app / "release.sh").exists():
        (app / "release.sh").chmod(0o755)

    # gradle wrapper: no more "open Android Studio once to generate it"
    if not (app / "gradlew").exists():
        gradle = shutil.which("gradle")
        if gradle and ((app / "settings.gradle.kts").exists() or (app / "settings.gradle").exists()):
            ver = _wrapper_version(app)
            r = subprocess.run([gradle, "wrapper", "--gradle-version", ver, "--no-daemon", "-q"], cwd=app, capture_output=True, text=True)
            report.append(("write" if r.returncode == 0 else "FAILED", app / "gradlew"))
        else:
            report.append(("TODO", app / "gradlew (install Gradle or run `gradle wrapper` once)"))

    cmd_listing(argparse.Namespace(app_repo=str(app)), quiet=True)
    for kind, path in report:
        print(f"  {kind:6} {path.relative_to(app) if isinstance(path, Path) and app in path.parents else path}")
    print("\nNext: python scripts/kit.py check", app)


def _wrapper_version(app: Path) -> str:
    props = app / "gradle/wrapper/gradle-wrapper.properties"
    if props.exists():
        m = re.search(r"gradle-([\d.]+)-", props.read_text(encoding="utf-8"))
        if m:
            return m.group(1)
    return "8.14.3"


# ----------------------------------------------------------------------------- listing
def cmd_listing(a, quiet=False):
    app = Path(a.app_repo).resolve()
    ctx = load_config(app)
    out = app / "store_assets"
    combined = []
    for lang in ctx["languages"]:
        entry = ctx["listing"].get(lang)
        if not entry:
            continue
        d = out / "metadata" / "android" / lang
        d.mkdir(parents=True, exist_ok=True)
        title = entry.get("title", ctx["title"])
        short, full = entry.get("short", "").strip(), entry.get("full", "").strip()
        (d / "title.txt").write_text(title + "\n", encoding="utf-8")
        (d / "short_description.txt").write_text(short + "\n", encoding="utf-8")
        (d / "full_description.txt").write_text(full + "\n", encoding="utf-8")
        combined.append(f"<{lang}>\nTITLE ({len(title)}/30):\n{title}\n\nSHORT DESCRIPTION ({len(short)}/80):\n{short}\n\nFULL DESCRIPTION ({len(full)}/4000):\n{full}\n</{lang}>\n")
    (out / "LISTING.txt").write_text("\n".join(combined), encoding="utf-8")
    if not quiet:
        print(f"Wrote store_assets/LISTING.txt and store_assets/metadata/android/<lang>/ for {', '.join(ctx['languages'])}")


# ----------------------------------------------------------------------------- check
def png_size(path: Path):
    with open(path, "rb") as f:
        head = f.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return struct.unpack(">II", head[16:24])


def cmd_check(a):
    app = Path(a.app_repo).resolve()
    ctx = load_config(app)
    rows: list[tuple[str, str]] = []

    def add(level, msg):
        rows.append((level, msg))

    # listing
    for lang in ctx["languages"]:
        e = ctx["listing"].get(lang)
        if not e:
            add(FAIL, f"listing.{lang} is missing in release-kit.toml")
            continue
        title = e.get("title", ctx["title"])
        short, full = e.get("short", "").strip(), e.get("full", "").strip()
        add(OK if 0 < len(title) <= 30 else FAIL, f"[{lang}] title {len(title)}/30")
        add(OK if 0 < len(short) <= 80 else FAIL, f"[{lang}] short description {len(short)}/80")
        add(OK if 0 < len(full) <= 4000 else FAIL, f"[{lang}] full description {len(full)}/4000")

    # release notes
    notes = app / "release-notes.txt"
    if notes.exists():
        found = dict(re.findall(r"(?s)<([A-Za-z]{2,3}(?:-[A-Za-z0-9]+)?)>\s*(.*?)\s*</\1>", notes.read_text(encoding="utf-8")))
        for lang in ctx["languages"]:
            n = len(found.get(lang, "").strip())
            add(OK if 0 < n <= 500 else FAIL, f"[{lang}] release notes {n}/500")
    else:
        add(FAIL, "release-notes.txt missing")

    # identity
    gradle = next((p for p in [app / "app/build.gradle.kts", app / "app/build.gradle"] if p.exists()), None)
    if gradle:
        g = gradle.read_text(encoding="utf-8")
        m = re.search(r'applicationId\s*=?\s*"([^"]+)"', g)
        add(OK if m and m.group(1) == ctx["package"] else FAIL, f"applicationId {m.group(1) if m else '?'} vs release-kit.toml {ctx['package']}")
        ns = re.search(r'namespace\s*=?\s*"([^"]+)"', g)
        if ns and ns.group(1).startswith("com.example"):
            add(WARN, f"namespace is still {ns.group(1)} (works, but `rename-package --namespace` tidies it)")
        add(OK if re.search(r"versionCode\s*=?\s*\d+", g) else FAIL, "versionCode present")
    else:
        add(FAIL, "app/build.gradle(.kts) not found")

    # manifest lint
    mf = app / "app/src/main/AndroidManifest.xml"
    if mf.exists():
        x = mf.read_text(encoding="utf-8")
        perms = set(re.findall(r'<uses-permission[^>]*android:name="([^"]+)"', x))
        if "com.google.android.gms.permission.AD_ID" in perms and 'tools:node="remove"' not in x:
            add(FAIL if not ctx.get("has_ads") else WARN, "AD_ID permission present but the app declares no ads")
        elif not ctx.get("has_ads"):
            stripped = 'permission.AD_ID" tools:node="remove"' in x
            add(OK if stripped else WARN, "AD_ID permission stripped in the manifest" if stripped else
                'AD_ID is not stripped: add <uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:node="remove" /> to the manifest')
        if "android.permission.USE_EXACT_ALARM" in perms:
            add(WARN, "USE_EXACT_ALARM is restricted to alarm-clock/calendar apps; prefer SCHEDULE_EXACT_ALARM")
        if "android.permission.USE_FULL_SCREEN_INTENT" in perms and not ctx.get("uses_full_screen_alert"):
            add(WARN, "USE_FULL_SCREEN_INTENT declared but uses_full_screen_alert=false in release-kit.toml")
        if "android.permission.INTERNET" in perms and not ctx.get("uses_internet"):
            add(WARN, "INTERNET permission present but uses_internet=false (privacy policy would be wrong)")
        if ({"android.permission.ACCESS_FINE_LOCATION", "android.permission.ACCESS_COARSE_LOCATION"} & perms) and not ctx.get("uses_location"):
            add(WARN, "location permission present but uses_location=false (privacy policy would be wrong)")
    else:
        add(FAIL, "AndroidManifest.xml not found")

    # privacy kit limits
    for flag in ("has_ads", "has_accounts", "collects_personal_data"):
        if ctx.get(flag):
            add(FAIL, f"{flag}=true: the generated privacy policy does not cover this; write it by hand (see PLAYBOOK.md)")
    if not any(r[0] == FAIL and "privacy" in r[1] for r in rows):
        add(OK, "privacy facts are within what the generated policy covers")

    # assets
    store = app / "store_assets"
    icon = next((p for p in [store / "icon_512x512.png", store / "icon.png"] if p.exists()), None)
    if icon:
        add(OK if png_size(icon) == (512, 512) and icon.stat().st_size <= 1_048_576 else FAIL, f"icon 512x512 PNG <= 1 MB ({png_size(icon)})")
    else:
        add(FAIL, "store_assets/icon_512x512.png missing")
    fg = store / "feature_graphic_1024x500.png"
    add(OK if fg.exists() and png_size(fg) == (1024, 500) else FAIL, "feature graphic 1024x500 (store_assets/feature_graphic_1024x500.png)")
    shots = sorted((store / "screenshots").glob("phone*.png")) if (store / "screenshots").exists() else []
    good = [s for s in shots if (sz := png_size(s)) and 320 <= min(sz) and max(sz) <= 3840 and max(sz) <= 2 * min(sz)]
    add(OK if len(good) >= 2 else FAIL, f"{len(good)} valid phone screenshots in store_assets/screenshots (need 2-8)")

    # website, signing, wrapper
    for f in ("index.html", "privacy.html", "terms.html"):
        add(OK if (app / "website" / f).exists() else FAIL, f"website/{f}")
    gi = (app / ".gitignore").read_text(encoding="utf-8") if (app / ".gitignore").exists() else ""
    add(OK if "*.jks" in gi and "keystore.properties" in gi else FAIL, ".gitignore protects the keystore")
    add(OK if (app / "gradlew").exists() else WARN, "gradle wrapper present (gradlew)")
    add(OK if (app / "release.ps1").exists() else FAIL, "release.ps1 present")
    add(OK if (app / "docs/PLAY_CONSOLE_CHECKLIST.md").exists() else WARN, "docs/PLAY_CONSOLE_CHECKLIST.md present")

    for level, msg in rows:
        print(f"[{level}] {msg}")
    fails = sum(1 for l, _ in rows if l == FAIL)
    warns = sum(1 for l, _ in rows if l == WARN)
    print(f"\n{len(rows)} checks: {fails} failed, {warns} warnings")
    sys.exit(1 if fails else 0)


# ----------------------------------------------------------------------------- rename-package
TEXT_SUFFIXES = {".kt", ".java", ".xml", ".kts", ".gradle", ".pro", ".txt", ".md", ".toml", ".properties"}


def cmd_rename(a):
    app = Path(a.app_repo).resolve()
    new = a.new_package
    if not re.fullmatch(r"[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+", new):
        sys.exit("Package must look like com.company.app (lowercase letters, digits, underscores).")
    gradle = next((p for p in [app / "app/build.gradle.kts", app / "app/build.gradle"] if p.exists()), None)
    if not gradle:
        sys.exit("app/build.gradle(.kts) not found")
    g = gradle.read_text(encoding="utf-8")
    old_id = re.search(r'applicationId\s*=?\s*"([^"]+)"', g)
    old_ns = re.search(r'namespace\s*=?\s*"([^"]+)"', g)
    changes = []

    if old_id and old_id.group(1) != new:
        g = g.replace(old_id.group(0), old_id.group(0).replace(old_id.group(1), new))
        changes.append(f"applicationId {old_id.group(1)} -> {new}")

    if a.namespace and old_ns and old_ns.group(1) != new:
        old = old_ns.group(1)
        g = g.replace(old_ns.group(0), old_ns.group(0).replace(old, new))
        pat = re.compile(r"(?<![\w.])" + re.escape(old) + r"(?![\w])")
        touched = 0
        for f in list((app / "app").rglob("*")):
            if f.is_file() and f.suffix in TEXT_SUFFIXES and "build" not in f.relative_to(app).parts[:2]:
                text = f.read_text(encoding="utf-8", errors="ignore")
                if pat.search(text) and f != gradle:
                    touched += 1
                    if not a.dry_run:
                        f.write_text(pat.sub(new, text), encoding="utf-8")
        # move source directories
        old_path, new_path = Path(*old.split(".")), Path(*new.split("."))
        moved = 0
        for kind in ("main", "test", "androidTest"):
            for lang in ("java", "kotlin"):
                base = app / "app/src" / kind / lang
                if (base / old_path).exists():
                    moved += 1
                    if not a.dry_run:
                        (base / new_path).parent.mkdir(parents=True, exist_ok=True)
                        shutil.move(str(base / old_path), str(base / new_path))
                        for parent in list((base / old_path).parents)[:2]:
                            if parent.exists() and parent != base and not any(parent.iterdir()):
                                parent.rmdir()
        changes.append(f"namespace {old} -> {new}: rewrote {touched} files, moved {moved} source folder(s)")

    if not a.dry_run:
        gradle.write_text(g, encoding="utf-8")
        cfg = app / "release-kit.toml"
        if cfg.exists():
            t = cfg.read_text(encoding="utf-8")
            cfg.write_text(re.sub(r'(?m)^(package\s*=\s*)"[^"]*"', rf'\1"{new}"', t), encoding="utf-8")
    for c in changes or ["nothing to change"]:
        print(("[dry-run] " if a.dry_run else "") + c)
    print("Remember: the application ID is permanent after the first Play upload.")


# ----------------------------------------------------------------------------- graphics
def cmd_graphics(a):
    app = Path(a.app_repo).resolve()
    ctx = load_config(app)
    icon = next((p for p in [app / "store_assets/icon_512x512.png", app / "store_assets/icon.png"] if p.exists()), None)
    if not icon:
        sys.exit("store_assets/icon_512x512.png is required")
    job = {
        "icon": str(icon),
        "name": ctx["name"],
        "tagline": ctx["tagline"],
        "colors": {"bg1": "#09130E", "bg2": "#183327", "accent": "#10B981", "text": "#FFFFFF", **ctx["graphics"].get("colors", {})},
        "out": str(app / "store_assets"),
        "screenshots": [
            {"file": str((app / s["file"]).resolve()), "caption": s.get("caption", "")} for s in ctx["screenshots"]
        ],
        "tablet": bool(ctx["graphics"].get("tablet", False)),
    }
    cfg = app / "store_assets" / ".graphics-job.json"
    cfg.parent.mkdir(parents=True, exist_ok=True)
    cfg.write_text(json.dumps(job, indent=2), encoding="utf-8")
    r = subprocess.run(["node", str(KIT / "scripts/graphics/render.js"), str(cfg)])
    cfg.unlink(missing_ok=True)
    sys.exit(r.returncode)



# ----------------------------------------------------------------------------- notes (draft release notes from git)
SKIP = re.compile(r"^(merge|chore|refactor|docs?|ci|test|build|bump|release|wip)\b|release\.ps1|readme|gradle wrapper|keystore|\.gitignore|typo|temporary|park |website|privacy policy|terms", re.I)


def draft_notes(app: Path, since: str | None = None, limit: int = 450) -> list[str]:
    def git(*args):
        r = subprocess.run(["git", *args], cwd=app, capture_output=True, text=True)
        return r.stdout.strip() if r.returncode == 0 else ""
    if not since:
        since = git("describe", "--tags", "--abbrev=0") or git("log", "-1", "--format=%H", "-G", "versionCode", "--", "app/build.gradle.kts")
    log = git("log", f"{since}..HEAD", "--no-merges", "--pretty=%s") if since else git("log", "-n", "30", "--no-merges", "--pretty=%s")
    out, used, seen = [], len("What's new:\n"), set()
    for subject in log.splitlines():
        subject = subject.strip().rstrip(".")
        if not subject or SKIP.search(subject) or subject.lower() in seen:
            continue
        seen.add(subject.lower())
        line = "- " + subject[0].upper() + subject[1:]
        if used + len(line) + 1 > limit:
            break
        out.append(line)
        used += len(line) + 1
    return out


def cmd_notes(a):
    app = Path(a.app_repo).resolve()
    lines = draft_notes(app, a.since)
    if not lines:
        sys.exit("No user-facing commits found since the last release. Write the notes by hand.")
    body = "What's new:\n" + "\n".join(lines)
    if a.write:
        path = app / "release-notes.txt"
        raw = path.read_text(encoding="utf-8") if path.exists() else ""
        if re.search(r"(?s)<en-US>.*?</en-US>", raw):
            raw = re.sub(r"(?s)<en-US>.*?</en-US>", lambda m: f"<en-US>\n{body}\n</en-US>", raw, count=1)
        else:
            raw = f"<en-US>\n{body}\n</en-US>\n" + raw
        path.write_text(raw, encoding="utf-8")
        print(f"Updated the <en-US> block in {path.name}. Translate or rewrite the other languages, then review.")
    print(body)


# ----------------------------------------------------------------------------- main
def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("init"); s.add_argument("app_repo"); s.add_argument("--force", action="store_true"); s.set_defaults(fn=cmd_init)
    s = sub.add_parser("listing"); s.add_argument("app_repo"); s.set_defaults(fn=cmd_listing)
    s = sub.add_parser("check"); s.add_argument("app_repo"); s.set_defaults(fn=cmd_check)
    s = sub.add_parser("rename-package"); s.add_argument("app_repo"); s.add_argument("new_package")
    s.add_argument("--namespace", action="store_true"); s.add_argument("--dry-run", action="store_true"); s.set_defaults(fn=cmd_rename)
    s = sub.add_parser("notes"); s.add_argument("app_repo"); s.add_argument("--since"); s.add_argument("--write", action="store_true"); s.set_defaults(fn=cmd_notes)
    s = sub.add_parser("graphics"); s.add_argument("app_repo"); s.set_defaults(fn=cmd_graphics)
    a = p.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
