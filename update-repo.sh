#!/usr/bin/env bash
# Пересобирает индексы APT-репозитория из всех .deb в debs/
# Нужны: ar, tar, gzip, bzip2, xz, coreutils
#
# Использование:  ./update-repo.sh
# Добавить пакет: cp foo_1.0_iphoneos-arm64.deb debs/ && ./update-repo.sh
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

echo "Готово: $(grep -c '^Package:' Packages) пакет(ов) в индексе"
paste -d' ' <(sed -n 's/^Package: //p' Packages) <(sed -n 's/^Architecture: //p' Packages) <(sed -n 's/^Version: //p' Packages | sed 's/^/v/')
