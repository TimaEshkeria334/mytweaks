#!/usr/bin/env bash
# Пересобирает индексы APT-репозитория из всех .deb в debs/
# и страницу скачивания .ipa из ipa/
# Нужны: ar, tar, gzip, bzip2, xz, coreutils (python3 — опционально, для метаданных IPA)
#
# Использование:  ./update-repo.sh
# Добавить твик:  cp foo_1.0_iphoneos-arm64.deb debs/ && ./update-repo.sh
# Добавить IPA:   cp Foo.ipa ipa/ && ./update-repo.sh
set -euo pipefail
cd "$(dirname "$0")"

ORIGIN="timagray"
LABEL="timagray"
SUITE="stable"
CODENAME="ios"
REPO_DESC="my tweaks for ios 12.5.8(5s)"
REPO_URL="https://timaeshkeria334.github.io/mytweaks"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

: > Packages

shopt -s nullglob
for deb in debs/*.deb; do
	deb_abs=$(realpath "$deb")
	name=$(basename "$deb")
	work="$tmp/$name"
	mkdir -p "$work/ctl"

	# control.tar.* лежит внутри ar-архива
	ctl_member=$(ar t "$deb_abs" | grep '^control\.tar' || true)
	( cd "$work" && ar x "$deb_abs" debian-binary "$ctl_member" )
	ctl_file=$(ls "$work"/control.tar.*)

	case "$ctl_file" in
		*.gz)   tar xzf "$ctl_file" -C "$work/ctl" ;;
		*.xz)   tar xJf "$ctl_file" -C "$work/ctl" ;;
		*.lzma) tar --lzma -xf "$ctl_file" -C "$work/ctl" ;;
		*.bz2)  tar xjf "$ctl_file" -C "$work/ctl" ;;
		*)      tar xf "$ctl_file" -C "$work/ctl" ;;
	esac

	# Обязательные поля — иначе пакет не увидит ни один менеджер
	for f in Package Version Architecture; do
		grep -qi "^$f:" "$work/ctl/control" || {
			echo "ОШИБКА: в $name нет поля $f" >&2
			exit 1
		}
	done
	grep -qi '^Section:'  "$work/ctl/control" || echo "Section: Tweaks" >> "$work/ctl/control"
	grep -qi '^Priority:' "$work/ctl/control" || echo "Priority: optional" >> "$work/ctl/control"

	# Если есть страница описания в depictions/<package>/ — подставляем свой Depiction
	pkg=$(sed -n 's/^Package: *//p' "$work/ctl/control" | head -1 | tr -d '\r')
	if [ -f "depictions/$pkg/info.xml" ]; then
		sed -i '/^[Dd]epiction:/d' "$work/ctl/control"
		echo "Depiction: $REPO_URL/depictions/?p=$pkg" >> "$work/ctl/control"
	fi

	cat "$work/ctl/control" >> Packages
	{
		echo "Filename: $deb"
		echo "Size: $(stat -c%s "$deb_abs")"
		echo "MD5sum: $(md5sum "$deb_abs" | cut -d' ' -f1)"
		echo "SHA1: $(sha1sum "$deb_abs" | cut -d' ' -f1)"
		echo "SHA256: $(sha256sum "$deb_abs" | cut -d' ' -f1)"
		echo "SHA512: $(sha512sum "$deb_abs" | cut -d' ' -f1)"
		echo
	} >> Packages
done

gzip -9 -k -f Packages
bzip2 -9 -k -f Packages
xz -9 -k -f Packages

{
	echo "Origin: $ORIGIN"
	echo "Label: $LABEL"
	echo "Suite: $SUITE"
	echo "Version: 1.0"
	echo "Codename: $CODENAME"
	echo "Architectures: iphoneos-arm iphoneos-arm64"
	echo "Components: main"
	echo "Description: $REPO_DESC"
	echo "Date: $(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S UTC')"
	echo "MD5Sum:"
	for f in Packages Packages.gz Packages.bz2 Packages.xz; do
		printf " %s %16d %s\n" "$(md5sum "$f" | cut -d' ' -f1)" "$(stat -c%s "$f")" "$f"
	done
	echo "SHA256:"
	for f in Packages Packages.gz Packages.bz2 Packages.xz; do
		printf " %s %16d %s\n" "$(sha256sum "$f" | cut -d' ' -f1)" "$(stat -c%s "$f")" "$f"
	done
} > Release

# --- страница скачивания .ipa ------------------------------------------------
ipas=(ipa/*.ipa)
if [ ${#ipas[@]} -gt 0 ]; then
	if command -v python3 >/dev/null 2>&1; then
		python3 - "$REPO_URL" "$REPO_DESC" <<'PY'
import hashlib, html, os, plistlib, sys, zipfile

repo_url, repo_desc = sys.argv[1], sys.argv[2]
icon_dir = "icons"
os.makedirs(os.path.join("ipa", icon_dir), exist_ok=True)


def human(n):
    n = float(n)
    for unit in ("Б", "КБ", "МБ", "ГБ"):
        if n < 1024:
            return f"{n:.0f} {unit}" if unit == "Б" else f"{n:.1f} {unit}"
        n /= 1024
    return f"{n:.1f} ТБ"


def meta(path):
    d = {"bundle": "", "name": "", "version": "", "minios": "", "icon": ""}
    try:
        with zipfile.ZipFile(path) as z:
            plists = [
                n for n in z.namelist()
                if n.startswith("Payload/") and n.count("/") == 2 and n.endswith(".app/Info.plist")
            ]
            if not plists:
                return d
            appdir = os.path.dirname(plists[0])
            p = plistlib.loads(z.read(plists[0]))
            d["bundle"] = str(p.get("CFBundleIdentifier") or "")
            d["name"] = str(p.get("CFBundleDisplayName") or p.get("CFBundleName") or "")
            d["version"] = str(p.get("CFBundleShortVersionString") or p.get("CFBundleVersion") or "")
            d["minios"] = str(p.get("MinimumOSVersion") or "")

            # иконка: самый крупный Icon*.png / AppIcon*.png в корне .app
            best = None
            for n in z.namelist():
                if not n.startswith(appdir + "/"):
                    continue
                rest = n[len(appdir) + 1:]
                low = rest.lower()
                if "/" in rest or not low.endswith(".png"):
                    continue
                if not low.startswith(("icon", "appicon")):
                    continue
                size = z.getinfo(n).file_size
                if best is None or size > best[1]:
                    best = (n, size)
            if best:
                out = os.path.join("ipa", icon_dir, os.path.basename(path)[:-4] + ".png")
                with open(out, "wb") as f:
                    f.write(z.read(best[0]))
                d["icon"] = icon_dir + "/" + os.path.basename(out)
    except Exception as e:
        print(f"предупреждение: не удалось прочитать {path}: {e}", file=sys.stderr)
    return d


cards = []
for path in sorted(p for p in os.listdir("ipa") if p.lower().endswith(".ipa")):
    full = os.path.join("ipa", path)
    d = meta(full)
    size = os.path.getsize(full)
    with open(full, "rb") as f:
        sha = hashlib.sha256(f.read()).hexdigest()

    title = html.escape(d["name"] or os.path.basename(path)[:-4])
    parts = []
    if d["bundle"]:
        parts.append(f"<code>{html.escape(d['bundle'])}</code>")
    if d["minios"]:
        parts.append(f"iOS {html.escape(d['minios'])}+")
    parts.append(human(size))

    icon = ""
    if d["icon"]:
        icon = f'<img class="app-icon mr-3" src="{html.escape(d["icon"])}" alt="" loading="lazy">'

    version = f' <small class="text-muted">v{html.escape(d["version"])}</small>' if d["version"] else ""
    cards.append(f"""	<div class="card">
		<div class="card-body d-flex">
			{icon}
			<div class="flex-grow-1">
				<h5 class="card-title mb-1">{title}{version}</h5>
				<p class="card-text mb-2"><small class="text-muted">{' · '.join(parts)}</small></p>
				<a class="btn btn-sm btn-primary" href="{html.escape(path)}" download>Скачать .ipa</a>
				<p class="card-text mt-2 mb-0"><small class="text-muted text-break">SHA256: <code>{sha}</code></small></p>
			</div>
		</div>
	</div>""")

page = f"""<!DOCTYPE html>
<html lang="ru">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>timagray — приложения (.ipa)</title>
  <link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.5.0/css/bootstrap.min.css">
  <style>
    body {{ margin: 1em; }}
    .card {{ margin-bottom: 1em; }}
    .app-icon {{ width: 57px; height: 57px; border-radius: 12px; }}
  </style>
</head>
<body>

<div class="container">
	<h1><img src="../CydiaIcon.png" width="48" height="48" alt=""> timagray</h1>
	<p><a href="../">&larr; На главную</a></p>
	<div class="card">
		<div class="card-body">
			<p class="mb-1">{html.escape(repo_desc)}</p>
			<p class="mb-0"><small class="text-muted">Приложения (.ipa) — {len(cards)} шт. Ставить через
			<a href="https://timaeshkeria334.github.io/mytweaks/">AppSync Unified</a>:
			скачать .ipa, открыть в Filza и нажать «Install», либо установить через <code>ipainstaller</code> /
			<code>AppSync</code>.</small></p>
		</div>
	</div>
</div>

<div class="container">
	<h3 class="page-header">Приложения</h3>
</div>

<div class="container">
{chr(10).join(cards)}
</div>

<div class="container">
	<p><small class="text-muted">Источник: <a href="{html.escape(repo_url)}/">{html.escape(repo_url)}</a></small></p>
</div>

</body>
</html>
"""

with open(os.path.join("ipa", "index.html"), "w", encoding="utf-8") as f:
    f.write(page)

print(f"ipa/index.html: {len(cards)} приложени(й)")
PY
	else
		echo "предупреждение: python3 не найден — ipa/index.html не обновлён" >&2
	fi
fi

echo "Готово: $(grep -c '^Package:' Packages) пакет(ов) в индексе"
paste -d' ' <(sed -n 's/^Package: //p' Packages) <(sed -n 's/^Architecture: //p' Packages) <(sed -n 's/^Version: //p' Packages | sed 's/^/v/')
