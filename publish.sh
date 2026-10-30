#!/usr/bin/env bash
#
# publish.sh — автоопределение твиков, сборка, публикация в репозиторий
# и создание GitHub Release.
#
#   ./publish.sh                 # всё: сборка + индексы + LAN + git push + releases
#   BUILD=0 ./publish.sh         # не собирать, взять готовые .deb
#   PUSH=0 RELEASES=0 ./publish.sh
#   RELEASE_ALL=1 ./publish.sh   # релизить все секции, а не только Tweaks
#
# Переменные: TWEAKS, REPO, LAN, BUILD, PUSH, RELEASES, RELEASE_ALL, GH_REPO
#
set -euo pipefail

TWEAKS="${TWEAKS:-$HOME/tweaks}"
REPO="${REPO:-$HOME/myrepo}"
LAN="${LAN:-$HOME/lanrepo}"
BUILD="${BUILD:-1}"
PUSH="${PUSH:-1}"
RELEASES="${RELEASES:-1}"
RELEASE_ALL="${RELEASE_ALL:-0}"

log() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[33m!!  %s\033[0m\n' "$*" >&2; }

# ---------------------------------------------------------------- утилиты

# deb_field <deb> <Field> — вытащить поле из control внутри .deb
deb_field() {
	local deb=$1 field=$2 abs tmp member
	abs=$(realpath "$deb")
	tmp=$(mktemp -d)
	member=$(ar t "$abs" | grep '^control\.tar' | head -1)
	[ -n "$member" ] || { rm -rf "$tmp"; return 1; }
	( cd "$tmp" && ar x "$abs" "$member" >/dev/null 2>&1 )
	case "$member" in
		*.gz)   tar xzf "$tmp/$member" -C "$tmp" ;;
		*.xz)   tar xJf "$tmp/$member" -C "$tmp" ;;
		*.lzma) tar --lzma -xf "$tmp/$member" -C "$tmp" ;;
		*.bz2)  tar xjf "$tmp/$member" -C "$tmp" ;;
		*)      tar xf "$tmp/$member" -C "$tmp" ;;
	esac
	sed -n "s/^$field:[[:space:]]*//p" "$tmp/control" | head -1
	rm -rf "$tmp"
}

# ---------------------------------------------------------------- 1. твики

log "Поиск твиков в $TWEAKS"
found=()
for dir in "$TWEAKS"/*/; do
	[ -f "$dir/control" ] || continue
	found+=("$dir")
done

if [ "${#found[@]}" -eq 0 ]; then
	warn "твиков не найдено"
else
	names=()
	for dir in "${found[@]}"; do names+=("$(basename "$dir")"); done
	printf '  найдено: %s\n' "${names[*]}"
fi

built=()
for dir in "${found[@]}"; do
	name=$(basename "$dir")
	log "Твик: $name"

	if [ "$BUILD" = "1" ]; then
		if [ -x "$dir/build.sh" ]; then
			( cd "$dir" && ./build.sh ) && echo "  собрано через build.sh"
		elif [ -f "$dir/Makefile" ] && [ -n "${THEOS:-}" ]; then
			( cd "$dir" && make package ) && echo "  собрано через Theos"
		else
			warn "$name: нечем собирать (нет build.sh и THEOS), беру готовые .deb"
		fi
	fi

	shopt -s nullglob
	for deb in "$dir"/packages/*.deb "$dir"/debs/*.deb "$dir"/*.deb; do
		built+=("$deb")
	done
	shopt -u nullglob
done

if [ "${#built[@]}" -eq 0 ]; then
	warn "готовых .deb не найдено — публикую то, что уже лежит в $REPO/debs"
fi

# ---------------------------------------------------------------- 2. репо

log "Синхронизация с $REPO/debs"
mkdir -p "$REPO/debs"
for deb in "${built[@]}"; do
	cp -f "$deb" "$REPO/debs/"
	echo "  + $(basename "$deb")"
done

changed=$(git -C "$REPO" status --porcelain -- debs 2>/dev/null |
	sed 's/^...//' | sed 's/^"\(.*\)"$/\1/' | sort -u)

log "Пересборка индексов ($REPO)"
( cd "$REPO" && ./update-repo.sh )

# ---------------------------------------------------------------- 3. LAN

if [ -d "$LAN" ]; then
	log "Синхронизация LAN-репозитория ($LAN)"
	mkdir -p "$LAN/debs"
	rm -f "$LAN"/debs/*.deb
	cp -f "$REPO"/debs/*.deb "$LAN/debs/"
	( cd "$LAN" && ./update-repo.sh )
else
	warn "LAN-репозиторий $LAN не найден — пропускаю"
fi

# ---------------------------------------------------------------- 4. git

if [ "$PUSH" = "1" ] && [ -d "$REPO/.git" ]; then
	log "Коммит и push"
	( cd "$REPO" && git add debs Packages Packages.gz Packages.bz2 Packages.xz Release publish.sh 2>/dev/null || true )
	if ( cd "$REPO" && ! git diff --cached --quiet ); then
		( cd "$REPO" && git commit -m "Publish: $(date -u '+%Y-%m-%d %H:%M')" )
		( cd "$REPO" && git push origin "$(git branch --show-current)" )
	else
		echo "  изменений нет"
	fi
else
	warn "git push отключён (PUSH=$PUSH)"
fi

# ---------------------------------------------------------------- 5. releases

if [ "$RELEASES" != "1" ]; then
	warn "releases отключены (RELEASES=$RELEASES)"
	exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
	warn "gh не найден — releases пропущены"
	exit 0
fi

GH_REPO="${GH_REPO:-$(git -C "$REPO" remote get-url origin 2>/dev/null |
	sed -E 's#\.git$##; s#.*github\.com[:/]##')}"
[ -n "$GH_REPO" ] || { warn "не удалось определить GitHub-репозиторий"; exit 0; }

if [ -z "$changed" ]; then
	log "Новых/изменённых .deb нет"
fi

log "GitHub Releases ($GH_REPO)"
if [ "${#built[@]}" -eq 0 ]; then
	warn "нет собранных твиков — releases пропущены"
	exit 0
fi

shopt -s nullglob
for src in "${built[@]}"; do
	deb="$REPO/debs/$(basename "$src")"
	[ -f "$deb" ] || continue

	pkg=$(deb_field "$deb" Package)
	ver=$(deb_field "$deb" Version)
	name=$(deb_field "$deb" Name)
	section=$(deb_field "$deb" Section)
	desc=$(deb_field "$deb" Description)

	[ -n "$pkg" ] || { warn "$(basename "$deb"): не смог прочитать Package"; continue; }

	if [ "$RELEASE_ALL" != "1" ]; then
		case "$section" in
			Tweaks|Tweak) ;;
			*) continue ;;
		esac
	fi

	tag="${pkg}-v${ver}"
	title="${name:-$pkg} ${ver}"

	if gh release view "$tag" -R "$GH_REPO" >/dev/null 2>&1; then
		if printf '%s\n' "$changed" | grep -qx "debs/$(basename "$deb")"; then
			echo "  ~ $tag: обновляю ассет"
			gh release upload "$tag" "$deb" -R "$GH_REPO" --clobber
		else
			echo "  = $tag уже есть"
		fi
	else
		echo "  + $tag"
		gh release create "$tag" "$deb" -R "$GH_REPO" \
			--title "$title" \
			--notes "${desc:-Автоматический релиз $pkg $ver}"
	fi
done

log "Готово"
