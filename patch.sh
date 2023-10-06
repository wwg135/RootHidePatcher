#!/usr/bin/bash

export TMPDIR=/var/mobile/RootHidePatcher

LDID="ldid -Hsha256"
ECHO="echo -e"

set -e

if [ $(whoami) != "root" ]; then
    $ECHO "Please run as root user (sudo)."
    exit 1;
fi

if ! type dpkg-deb >/dev/null 2>&1; then
	$ECHO "Please install dpkg-deb."
    exit 1;
fi

if ! type file >/dev/null 2>&1; then
	$ECHO "Please install file."
    exit 1;
fi

if ! type awk >/dev/null 2>&1; then
    $ECHO "Please install awk."
    exit 1;
fi

if ! ldid 2>&1 | grep -q procursus; then
	$ECHO "Please install Procursus ldid."
    exit 1;
fi


if [ -z "$1" ] || ! file "$1" | grep -q "Debian binary package" ; then
    $ECHO "Usage: $0 /path/to/deb [/path/to/output]"
    exit 1;
fi

$ECHO "creating workspace..."
TEMPDIR_OLD="$(mktemp -d)"
TEMPDIR_NEW="$(mktemp -d)"

if [ ! -d "$TEMPDIR_OLD" ] || [ ! -d "$TEMPDIR_NEW" ]; then
	$ECHO "*** Creating temporary directories failed!\n"
    exit 1;
fi

### Real script start

dpkg-deb -R "$1" "$TEMPDIR_OLD"

if [ ! -d "$TEMPDIR_OLD/var/jb" ]; then
    $ECHO "*** Not a rootless package!\n\nskipping and exiting cleanly."
    rm -rf "$TEMPDIR_OLD" "$TEMPDIR_NEW"
    exit 1;
fi

cp -a "$TEMPDIR_OLD"/DEBIAN "$TEMPDIR_NEW"
sed 's|iphoneos-arm64|iphoneos-arm64e|' < "$TEMPDIR_OLD"/DEBIAN/control > "$TEMPDIR_NEW"/DEBIAN/control

mv -f "$TEMPDIR_OLD"/var/jb/.* "$TEMPDIR_NEW"/ >/dev/null 2>&1 || true
mv -f "$TEMPDIR_OLD"/var/jb/* "$TEMPDIR_NEW"/ || true

lsrpath() {
    otool -l "$@" |
    awk '
        /^[^ ]/ {f = 0}
        $2 == "LC_RPATH" && $1 == "cmd" {f = 1}
        f && gsub(/^ *path | \(offset [0-9]+\)$/, "") == 2
    '
}

find "$TEMPDIR_NEW" -type f | while read -r file; do
  fpath=$(realpath --relative-base="$TEMPDIR_NEW" "$file")
  if file -ib "$file" | grep -q "x-mach-binary; charset=binary"; then
    $ECHO "=> $fpath"
    $ECHO -n "patch..."
    if [ ! -z "$(lsrpath $file | grep "/var/jb/usr/lib")" ]; then
        install_name_tool -delete_rpath "/var/jb/usr/lib" "$file"
        install_name_tool -add_rpath "@loader_path/.jbroot/usr/lib" "$file"
    fi
    if [ ! -z "$(lsrpath $file | grep "/var/jb/Library/Frameworks")" ]; then
        install_name_tool -delete_rpath "/var/jb/Library/Frameworks" "$file"
        install_name_tool -add_rpath "@loader_path/.jbroot/Library/Frameworks" "$file"
    fi
    $ECHO -n "resign..."
    $LDID -s "$file"
    $LDID -M -S$(dirname $0)/roothide.entitlements "$file"
    $ECHO "~ok."
    varjbstr=$(strings - "$file" | grep /var/jb || true)
  else
    fname=$(basename "$file")
    if [[ {preinst,prerm,postinst,postrm,extrainst_} =~ "$fname" ]]; then
        sed -i 's|/var/jb/|/|g' "$file"
    fi
    varjbstr=$(strings - "$file" | grep /var/jb || true)
    if [ ! -z "$varjbstr" ]; then
        $ECHO "=> $fpath"
    fi
  fi
  if [ ! -z "$varjbstr" ]; then
    $ECHO "***WARNNING:fixed path(s):***\n$varjbstr\n\n"
  fi
done

DEB_PACKAGE=$(grep Package: "$TEMPDIR_NEW"/DEBIAN/control | cut -f2 -d ' ')
DEB_VERSION=$(grep Version: "$TEMPDIR_NEW"/DEBIAN/control | cut -f2 -d ' ')
DEB_ARCH=$(grep Architecture: "$TEMPDIR_NEW"/DEBIAN/control | cut -f2 -d ' ')

OUTPUT_PATH="/var/mobile/RootHidePatcher/$DEB_PACKAGE"_"$DEB_VERSION"_"$DEB_ARCH".deb

if [ ! -z "$2" ]; then OUTPUT_PATH=$2; fi;

find "$TEMPDIR_NEW" -name ".DS_Store" -delete
dpkg-deb -Zzstd -b "$TEMPDIR_NEW" "$OUTPUT_PATH"
chown mobile:mobile "$OUTPUT_PATH"

### Real script end

$ECHO "\nfinished. cleaning up..."
rm -rf "$TEMPDIR_OLD" "$TEMPDIR_NEW"
rm -f $1
