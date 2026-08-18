#!/usr/bin/env bash
# Verify-and-bump helper for app-misc/claude-desktop-bin.
#
# All the expensive work lives here rather than in the model's context: fetching
# the apt index, downloading ~170 MB .debs, unpacking and profiling them, and
# running the install phase. The only thing that reaches Claude is the compact
# report below, ending in a single VERDICT line:
#
#   UP-TO-DATE  local overlay already has the newest upstream release
#   SMOOTH      new ebuild is a straight copy and everything it relies on is
#               unchanged -> safe to commit and push without asking
#   REVIEW      something the ebuild depends on moved -> explain it, then ask
#   FAIL        the bump does not work as-is -> do not commit
#
# The checks are derived from the ebuild itself (fperms/domenu/dodoc targets)
# rather than a hardcoded list, so they keep testing the right things if the
# ebuild's install phase is later reworked.

set -uo pipefail

PN=claude-desktop-bin
MY_PN=claude-desktop
BASE_URI=https://downloads.claude.ai/claude-desktop/apt/stable
POOL=$BASE_URI/pool/main/c/$MY_PN
ARCHES="amd64 arm64"
DEEP_ARCH=amd64          # arch whose .deb we unpack and inspect byte-level

CHECK_ONLY=0
KEEP_BUILD=0
TARGET=

usage() {
	cat <<EOF
usage: bump.sh [--check-only] [--version VER] [--keep-build]

  --check-only   report local vs upstream version only; no downloads, no writes
  --version VER  bump to VER instead of the newest upstream release
  --keep-build   leave /var/tmp/portage build tree in place for inspection
EOF
}

while (($#)); do
	case $1 in
		--check-only) CHECK_ONLY=1 ;;
		--version) TARGET=${2:?--version needs an argument}; shift ;;
		--keep-build) KEEP_BUILD=1 ;;
		-h|--help) usage; exit 0 ;;
		*) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
	esac
	shift
done

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)
[[ -n $REPO ]] || { echo "bump.sh must live inside the overlay git checkout" >&2; exit 2; }
PKGDIR=$REPO/app-misc/$PN
[[ -d $PKGDIR ]] || { echo "no such package dir: $PKGDIR" >&2; exit 2; }

WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

DISTDIR=$(portageq distdir 2>/dev/null) || DISTDIR=/var/cache/distfiles

REVIEW=()
FAILS=()
NOTES=()
DETAIL=""
review() { REVIEW+=("$1"); }
hard()   { FAILS+=("$1"); }
note()   { NOTES+=("$1"); }
row()    { printf '%-22s %s\n' "$1" "$2"; }
hdr()    { printf '\n%s\n' "$1"; }
detail() { DETAIL+=$'\n'"--- $1 ---"$'\n'"$2"$'\n'; }

verdict() {
	local v=$1
	if [[ -n $DETAIL ]]; then
		hdr "what changed"
		printf '%s' "$DETAIL"
	fi
	if ((${#NOTES[@]})); then
		hdr "notes"
		printf '  - %s\n' "${NOTES[@]}"
	fi
	if ((${#FAILS[@]})); then
		hdr "blocking"
		printf '  - %s\n' "${FAILS[@]}"
	fi
	if ((${#REVIEW[@]})); then
		hdr "needs your judgement"
		printf '  - %s\n' "${REVIEW[@]}"
	fi
	printf '\nVERDICT: %s\n' "$v"
	[[ $v == FAIL ]] && exit 1
	exit 0
}

get() { # url outfile
	curl -fsSL --retry 3 "$1" -o "$2"
}

# ---------------------------------------------------------------- versions ---

local_versions() {
	local f v
	for f in "$PKGDIR"/$PN-*.ebuild; do
		[[ -e $f ]] || continue
		v=${f##*/$PN-}
		printf '%s\n' "${v%.ebuild}"
	done | sort -V
}

# highest local version strictly below $1, else highest local version != $1
prev_of() {
	local t=$1 v best=
	while read -r v; do
		[[ $v == "$t" ]] && continue
		[[ $(printf '%s\n%s\n' "$v" "$t" | sort -V | head -1) == "$v" ]] && best=$v
	done < <(local_versions)
	[[ -n $best ]] || best=$(local_versions | grep -vxF "$t" | tail -1)
	printf '%s\n' "$best"
}

index_versions() { grep '^Version: ' "$WORK/Packages.$1" | awk '{print $2}' | sort -u; }

has_version() { grep -qxF "Version: $2" "$WORK/Packages.$1"; }

index_field() { # arch version field
	awk -v RS='' -v FS='\n' -v want="Version: $2" -v key="$3: " '
		{ hit = 0
		  for (i = 1; i <= NF; i++) if ($i == want) hit = 1
		  if (hit) for (i = 1; i <= NF; i++)
			if (index($i, key) == 1) { print substr($i, length(key) + 1); exit } }
	' "$WORK/Packages.$1"
}

# newest version published for every arch in SRC_URI
newest_common() {
	local a first=1
	for a in $ARCHES; do
		index_versions "$a" > "$WORK/v.$a"
		if ((first)); then cp "$WORK/v.$a" "$WORK/common"; first=0
		else comm -12 "$WORK/common" "$WORK/v.$a" > "$WORK/common.new" && mv "$WORK/common.new" "$WORK/common"
		fi
	done
	sort -V "$WORK/common" | tail -1
}

echo "=== app-misc/$PN bump check ==="
LOCAL=$(local_versions | tail -1)
[[ -n $LOCAL ]] || { echo "no ebuilds found in $PKGDIR" >&2; exit 2; }

for a in $ARCHES; do
	get "$BASE_URI/dists/stable/main/binary-$a/Packages" "$WORK/Packages.$a" \
		|| { echo "cannot fetch upstream $a index" >&2; exit 2; }
done

UPSTREAM=$(newest_common)
row "local latest" "$LOCAL"
row "upstream latest" "$UPSTREAM"

# A release published for only some arches cannot satisfy SRC_URI as written.
for a in $ARCHES; do
	newest_a=$(sort -V "$WORK/v.$a" | tail -1)
	[[ $newest_a == "$UPSTREAM" ]] || note "$a has a newer standalone release ($newest_a) not yet published for all arches"
done

if [[ -z $TARGET ]]; then
	TARGET=$UPSTREAM
	if [[ $LOCAL == "$TARGET" ]]; then
		row "target" "none"
		verdict UP-TO-DATE
	fi
fi
row "target" "$TARGET"

for a in $ARCHES; do
	has_version "$a" "$TARGET" || { hard "$TARGET is not published for $a"; verdict FAIL; }
done

PREV=$(prev_of "$TARGET")
row "compare against" "$PREV"

((CHECK_ONLY)) && verdict REVIEW

# ------------------------------------------------------- ebuild + manifest ---

NEW_EBUILD=$PKGDIR/$PN-$TARGET.ebuild
if [[ -e $NEW_EBUILD ]]; then
	row "new ebuild" "already present (left as-is)"
	if ! diff -q "$PKGDIR/$PN-$PREV.ebuild" "$NEW_EBUILD" >/dev/null; then
		review "$PN-$TARGET.ebuild already exists and differs from $PREV's"
		detail "ebuild diff vs $PREV" "$(diff -u "$PKGDIR/$PN-$PREV.ebuild" "$NEW_EBUILD" | tail -n +3)"
	fi
else
	cp "$PKGDIR/$PN-$PREV.ebuild" "$NEW_EBUILD" || { hard "could not create $NEW_EBUILD"; verdict FAIL; }
	row "new ebuild" "created as a copy of $PREV"
fi

# ebuild(1) is run in the working directory on purpose: this checkout is itself
# a valid overlay, so no root and no /var/db/repos writes are needed.
if ! ( cd "$PKGDIR" && ebuild "$PN-$TARGET.ebuild" manifest ) >"$WORK/manifest.log" 2>&1; then
	hard "ebuild manifest failed"
	detail "manifest log (tail)" "$(tail -15 "$WORK/manifest.log")"
	verdict FAIL
fi
missing_dist=0
for a in $ARCHES; do
	grep -q "^DIST ${MY_PN}_${TARGET}_${a}.deb " "$PKGDIR/Manifest" || missing_dist=1
done
if ((missing_dist)); then
	hard "Manifest is missing a DIST line for $TARGET"
	verdict FAIL
fi
row "manifest" "ok (DIST entries for $ARCHES)"

# ------------------------------------------------------------- deb probing ---

deb_for() { # version arch -> path on stdout, fetching only if not cached
	local v=$1 a=$2 f
	f="${MY_PN}_${v}_${a}.deb"
	if   [[ -r $DISTDIR/$f ]]; then printf '%s\n' "$DISTDIR/$f"
	elif [[ -r $WORK/$f    ]]; then printf '%s\n' "$WORK/$f"
	elif get "$POOL/$f" "$WORK/$f";  then printf '%s\n' "$WORK/$f"
	else return 1
	fi
}

deb_member() { ar t "$1" | grep -m1 "^$2\.tar"; }

# tar here reads from a pipe, where this tar will not sniff the compression
# itself, so the filter is picked from the member name upstream chose.
tar_flag() {
	case $1 in
		*.xz)  echo -J ;;
		*.gz)  echo -z ;;
		*.zst) echo --zstd ;;
		*.bz2) echo -j ;;
		*)     echo ;;
	esac
}

control_field() { # deb field
	local m tf
	m=$(deb_member "$1" control) || return 1
	tf=$(tar_flag "$m")
	ar p "$1" "$m" | tar $tf -xOf - ./control 2>/dev/null |
		awk -v k="$2: " 'index($0, k) == 1 { print substr($0, length(k) + 1) }'
}

# Turn a .deb into a directory of small text files describing everything the
# ebuild cares about, so the comparisons below are plain diffs.
profile() { # deb outdir
	local deb=$1 out=$2 dm tf
	mkdir -p "$out/x"
	dm=$(deb_member "$deb" data) || return 1
	tf=$(tar_flag "$dm")
	ar p "$deb" "$dm" | tar $tf -tvf - > "$out/tv.txt" 2>/dev/null || return 1
	awk '{ name = $6; for (i = 7; i <= NF; i++) name = name " " $i
	       sub(/ -> .*$/, "", name); sub(/^\.\//, "", name)
	       print $1 "\t" name }' "$out/tv.txt" > "$out/pn.txt"
	awk -F'\t' '$1 !~ /^d/ { print $2 }'                "$out/pn.txt" | sort > "$out/files.txt"
	awk -F'\t' '$1 ~ /^-/ && $1 ~ /x/ { print $2 }'     "$out/pn.txt" | sort > "$out/exe.txt"
	grep -oE "usr/share/icons/hicolor/[0-9]+x[0-9]+/apps/.*" "$out/files.txt" | sort > "$out/icons.txt"
	# entries the ebuild walks directly: the app dir and its resources dir
	grep -E "^usr/lib/$MY_PN/[^/]+$|^usr/lib/$MY_PN/resources/[^/]+$" "$out/files.txt" \
		| sort > "$out/tree.txt"
	ar p "$deb" "$dm" | tar $tf -xf - -C "$out/x" --wildcards \
		"./usr/lib/$MY_PN/version" "./usr/lib/$MY_PN/$MY_PN" './usr/share/applications/*' \
		2>/dev/null
	if [[ -f $out/x/usr/lib/$MY_PN/$MY_PN ]]; then
		objdump -p "$out/x/usr/lib/$MY_PN/$MY_PN" 2>/dev/null |
			awk '$1 == "NEEDED" { print $2 }' | sort -u > "$out/needed.txt"
		rm -f "$out/x/usr/lib/$MY_PN/$MY_PN"   # ~200 MB, not needed past this point
	else
		: > "$out/needed.txt"
	fi
	cat "$out/x/usr/lib/$MY_PN/version" 2>/dev/null > "$out/electron" || : > "$out/electron"
	cat "$out"/x/usr/share/applications/*.desktop 2>/dev/null > "$out/desktop" || : > "$out/desktop"
	stat -c %s "$deb" > "$out/size"
}

OLD_DEB=$(deb_for "$PREV" "$DEEP_ARCH")   || { hard "cannot obtain $PREV $DEEP_ARCH .deb for comparison"; verdict FAIL; }
NEW_DEB=$(deb_for "$TARGET" "$DEEP_ARCH") || { hard "cannot obtain $TARGET $DEEP_ARCH .deb"; verdict FAIL; }
profile "$OLD_DEB" "$WORK/old" || { hard "cannot unpack $PREV .deb";   verdict FAIL; }
profile "$NEW_DEB" "$WORK/new" || { hard "cannot unpack $TARGET .deb"; verdict FAIL; }

hdr "$PREV -> $TARGET ($DEEP_ARCH unpacked, deps checked on all arches)"

cmp_txt() { # label oldstring newstring
	if [[ $2 == "$3" ]]; then row "$1" "unchanged"; return; fi
	row "$1" "CHANGED"
	review "$1 changed"
	detail "$1" "- $2"$'\n'"+ $3"
}

cmp_file() { # label oldfile newfile
	local n; n=$(wc -l < "$3")
	if diff -q "$2" "$3" >/dev/null 2>&1; then row "$1" "unchanged ($n entries)"; return 0; fi
	row "$1" "CHANGED"
	detail "$1" "$(diff -u "$2" "$3" | tail -n +3 | grep -E '^[+-]' | head -40)"
	return 1
}

# Upstream's own dependency declarations: the source RDEPEND was derived from.
for a in $ARCHES; do
	for k in Depends Recommends; do
		if [[ $a == "$DEEP_ARCH" ]]; then
			o=$(control_field "$OLD_DEB" "$k"); n=$(control_field "$NEW_DEB" "$k")
		elif has_version "$a" "$PREV"; then
			o=$(index_field "$a" "$PREV" "$k"); n=$(index_field "$a" "$TARGET" "$k")
		else
			row "deb $k ($a)" "n/a ($PREV pruned upstream)"
			continue
		fi
		cmp_txt "deb $k ($a)" "$o" "$n"
	done
done

# Shared libraries the bundled Electron binary links: what RDEPEND must cover.
cmp_file "NEEDED sonames" "$WORK/old/needed.txt" "$WORK/new/needed.txt" \
	|| review "the bundled binary links a different set of shared libraries - RDEPEND may need updating"

# Every executable needs fperms/pax-mark treatment in src_install.
cmp_file "executable set" "$WORK/old/exe.txt" "$WORK/new/exe.txt" \
	|| review "the set of executables changed - check whether src_install needs new fperms/pax-mark lines"

cmp_file "icon set" "$WORK/old/icons.txt" "$WORK/new/icons.txt" \
	|| review "installed icons changed - check the doicon loop"

cmp_file ".desktop entry" "$WORK/old/desktop" "$WORK/new/desktop" \
	|| review ".desktop entry changed - check Exec/WM_CLASS against the dosym and domenu"

# New payload under resources/ is normal and harmless; disappearing entries are
# what would break an ebuild that reaches for a specific file.
if ! cmp_file "app tree" "$WORK/old/tree.txt" "$WORK/new/tree.txt"; then
	removed=$(comm -23 "$WORK/old/tree.txt" "$WORK/new/tree.txt")
	added=$(comm -13   "$WORK/old/tree.txt" "$WORK/new/tree.txt")
	[[ -n $removed ]] && review "entries removed from the app tree: $(echo $removed)"
	[[ -n $added   ]] && note   "new payload in the app tree: $(echo $added)"
fi

# The RDEPEND comment names an Electron major; a major bump warrants a look.
eo=$(cat "$WORK/old/electron"); en=$(cat "$WORK/new/electron")
if [[ ${eo%%.*} == "${en%%.*}" ]]; then
	row "electron" "$eo -> $en (same major)"
else
	row "electron" "$eo -> $en (MAJOR BUMP)"
	review "bundled Electron went from major ${eo%%.*} to ${en%%.*} - re-check RDEPEND and the comment naming it"
fi

row "deb size" "$(cat "$WORK/old/size") -> $(cat "$WORK/new/size")"
row "file count" "$(wc -l < "$WORK/old/files.txt") -> $(wc -l < "$WORK/new/files.txt")"

# Paths src_install actually reaches for, read out of the ebuild so this stays
# honest if the install phase is ever reworked.
expected_paths() {
	sed -e "s/\${MY_PN}/$MY_PN/g" -e "s/\${PN}/$PN/g" "$1" | awk -v p="$MY_PN" '
		$1 == "fperms" { t = $NF; sub("^/opt/" p "/", "usr/lib/" p "/", t); print t }
		$1 == "domenu" || $1 == "dodoc" { for (i = 2; i <= NF; i++) if ($i ~ /^usr\//) print $i }
	' | grep -v '[$*]' | sort -u
}
missing=()
while read -r p; do
	[[ -n $p ]] || continue
	grep -qxF "$p" "$WORK/new/files.txt" || missing+=("$p")
done < <(expected_paths "$NEW_EBUILD")
if ((${#missing[@]})); then
	row "src_install paths" "MISSING ${#missing[@]}"
	hard "paths src_install requires are absent from the .deb: ${missing[*]}"
else
	row "src_install paths" "all present"
fi

# ------------------------------------------------------------------- build ---

if ! ( cd "$PKGDIR" && ebuild "$PN-$TARGET.ebuild" clean install ) >"$WORK/build.log" 2>&1; then
	hard "ebuild install phase failed"
	detail "build log (tail)" "$(tail -25 "$WORK/build.log")"
	verdict FAIL
fi

IMAGE=$(sed -n 's,.*Install .* into \(/.*\)$,\1,p' "$WORK/build.log" | tail -1)
if [[ -d $IMAGE ]]; then
	img_missing=()
	[[ -x $IMAGE/opt/$MY_PN/$MY_PN ]]                            || img_missing+=("opt/$MY_PN/$MY_PN")
	[[ -L $IMAGE/usr/bin/$MY_PN ]]                               || img_missing+=("usr/bin/$MY_PN symlink")
	compgen -G "$IMAGE/usr/share/applications/*.desktop" >/dev/null || img_missing+=(".desktop entry")
	compgen -G "$IMAGE/usr/share/icons/hicolor/*/apps/*"  >/dev/null || img_missing+=("icons")
	if ((${#img_missing[@]})); then
		hard "installed image is missing: ${img_missing[*]}"
	else
		row "installed image" "ok (binary, symlink, menu entry, icons)"
	fi
fi

qa=$(grep -cE 'QA Notice' "$WORK/build.log")
if ((qa)); then
	row "build" "ok but $qa QA notice(s)"
	review "the install phase emitted QA notices"
	detail "QA notices" "$(grep -A2 'QA Notice' "$WORK/build.log" | head -20)"
else
	row "build" "ok, no QA notices"
fi

((KEEP_BUILD)) || ( cd "$PKGDIR" && ebuild "$PN-$TARGET.ebuild" clean ) >/dev/null 2>&1

hdr "changed files"
git -C "$REPO" status --short -- "app-misc/$PN" | sed 's/^/  /'

if   ((${#FAILS[@]}));  then verdict FAIL
elif ((${#REVIEW[@]})); then verdict REVIEW
else                         verdict SMOOTH
fi
