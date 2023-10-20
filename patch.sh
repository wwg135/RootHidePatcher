#!/bin/bash

set -e
shopt -s dotglob

LDID="ldid -Hsha256"
ECHO="echo -e"
SED="sed"

if [ "$(sw_vers -productName)" == "macOS" ]; then
export TMPDIR=$(dirname "$1")
LOG() { $ECHO "$@\n"; }
SED="gsed"
else
LOG() { return; }
#LOG() { $ECHO "$@\n"; }
export TMPDIR=/var/mobile/RootHidePatcher
fi

LOG "TMPDIR=$TMPDIR"

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
    $ECHO "Usage: $0 /path/to/deb [/path/to/output] [DynamicPatches|AutoPatches]"
    exit 1;
fi

$ECHO "creating workspace..."
debfname=$(basename "$1")
TEMPDIR_OLD=$(mktemp -d "$TMPDIR/$debfname.old.XXXXXX")
TEMPDIR_NEW=$(mktemp -d "$TMPDIR/$debfname.new.XXXXXX")
chmod 0755 "$TEMPDIR_OLD" "$TEMPDIR_NEW"

if [ ! -d "$TEMPDIR_OLD" ] || [ ! -d "$TEMPDIR_NEW" ]; then
	$ECHO "*** Creating temporary directories failed!\n"
    exit 1;
fi

### Real script start

dpkg-deb -R "$1" "$TEMPDIR_OLD"

chmod -R 755 "$TEMPDIR_OLD"/DEBIAN
chmod 644 "$TEMPDIR_OLD"/DEBIAN/control

DEB_PACKAGE=$(grep '^Package:' "$TEMPDIR_OLD"/DEBIAN/control | cut -f2 -d ' ')
DEB_VERSION=$(grep '^Version:' "$TEMPDIR_OLD"/DEBIAN/control | cut -f2 -d ' ')
DEB_ARCH=$(grep '^Architecture:' "$TEMPDIR_OLD"/DEBIAN/control | cut -f2 -d ' ')

if [ ! -d "$TEMPDIR_OLD/var/jb" ] || [ $DEB_ARCH != "iphoneos-arm64" ]; then
    $ECHO "*** Not a rootless package!\n\nskipping and exiting cleanly."
    rm -rf "$TEMPDIR_OLD" "$TEMPDIR_NEW"
    exit 1;
fi

cp -a "$TEMPDIR_OLD"/var/jb/* "$TEMPDIR_NEW"/
cp -a "$TEMPDIR_OLD"/* "$TEMPDIR_NEW"/
rm -rf "$TEMPDIR_NEW"/var/jb
rmdir "$TEMPDIR_NEW"/var >/dev/null 2>&1 || true

lsrpath() {
    otool -l "$@" |
    awk '
        /^[^ ]/ {f = 0}
        $2 == "LC_RPATH" && $1 == "cmd" {f = 1}
        f && gsub(/^ *path | \(offset [0-9]+\)$/, "") == 2
    ' | sort | uniq
}

find "$TEMPDIR_NEW" -type f | while read -r file; do
  fixedpaths=""
  fname=$(basename "$file")
  fpath=/$(realpath --relative-base="$TEMPDIR_NEW" "$file")
  if file -ib "$file" | grep -q "x-mach-binary; charset=binary"; then
    $ECHO "=> $fpath"
    $ECHO -n "patch..."
    lsrpath "$file" | while read line; do
        if [[ $line == /var/jb/* ]]; then
            newpath=${line/\/var\/jb\//@loader_path\/.jbroot\/}
            LOG "change rpath" "$line" "$newpath"
            install_name_tool -rpath "$line" "$newpath" "$file"
        fi
    done
    otool -L "$file" | tail -n +2 | cut -d' ' -f1 | tr -d "[:blank:]" | while read line; do
        if [[ $line == /var/jb/* ]]; then
            newlib=${line/\/var\/jb\//@loader_path\/.jbroot\/}
            LOG "change library" "$line" "$newlib"
            install_name_tool -change "$line" "$newlib" "$file"
        fi
    done
    $ECHO -n "resign..."
    $LDID -M "-S$(dirname $(realpath $0))/roothide.entitlements" "$file"
    $ECHO "~ok."
    fixedpaths=$(strings - "$file" | grep /var/jb || true)
    if [ "$3" == "AutoPatches" ]; then
        ln -s /usr/lib/DynamicPatches/AutoPatches.dylib "$file".roothidepatch
    fi
  elif ! [[ {png,strings} =~ "${fname##*.}" ]]; then
    if [[ {preinst,prerm,postinst,postrm,extrainst_} =~ "$fname" ]]; then
        $SED -i 's|iphoneos-arm64|iphoneos-arm64e|g' "$file"
                        
        $SED -i 's|/var/jb/|/-var/jb/-|g' "$file"
        $SED -i 's|/var/jb|/-var/jb-|g' "$file"
        
        $SED -i 's| /Applications/| /rootfs/Applications/|g' "$file"
        $SED -i 's| /Library/| /rootfs/Library/|g' "$file"
        $SED -i 's| /private/| /rootfs/private/|g' "$file"
        $SED -i 's| /System/| /rootfs/System/|g' "$file"
        $SED -i 's| /sbin/| /rootfs/sbin/|g' "$file"
        $SED -i 's| /bin/| /rootfs/bin/|g' "$file"
        $SED -i 's| /etc/| /rootfs/etc/|g' "$file"
        $SED -i 's| /lib/| /rootfs/lib/|g' "$file"
        $SED -i 's| /usr/| /rootfs/usr/|g' "$file"
        $SED -i 's| /var/| /rootfs/var/|g' "$file"
                                                
        $SED -i 's|/-var/jb/-|/|g' "$file"
        $SED -i 's|/-var/jb-|/var/jb|g' "$file"
    fi
    if [ "${fname##*.}" == "plist" ]; then
        plutil -convert xml1 "$file" >/dev/null
        if [[ {/Library/libSandy,/Library/LaunchDaemons} =~ $(dirname "$fpath") ]]; then
            $SED -i 's|/var/jb/|/-var/jb/-|g' "$file"
            $SED -i 's|/var/jb|/-var/jb-|g' "$file"
                    
            $SED -i 's|>/<|>/rootfs/<|g' "$file"
            $SED -i 's|>/Applications/|>/rootfs/Applications/|g' "$file"
            $SED -i 's|>/Library/|>/rootfs/Library/|g' "$file"
            $SED -i 's|>/private/|>/rootfs/private/|g' "$file"
            $SED -i 's|>/System/|>/rootfs/System/|g' "$file"
            $SED -i 's|>/sbin/|>/rootfs/sbin/|g' "$file"
            $SED -i 's|>/bin/|>/rootfs/bin/|g' "$file"
            $SED -i 's|>/etc/|>/rootfs/etc/|g' "$file"
            $SED -i 's|>/lib/|>/rootfs/lib/|g' "$file"
            $SED -i 's|>/usr/|>/rootfs/usr/|g' "$file"
            $SED -i 's|>/var/|>/rootfs/var/|g' "$file"
            
            $SED -i 's|/-var/jb/-|/|g' "$file"
            $SED -i 's|/-var/jb-|/var/jb|g' "$file"
        fi
    fi
    fixedpaths=$(strings - "$file" | grep /var/jb || true)
    if [ ! -z "$fixedpaths" ]; then
        $ECHO "=> $fpath"
    fi
  fi
  if [ ! -z "$fixedpaths" ]; then
    $ECHO "*****fixed-paths-warnning*****\n$fixedpaths\n*******************************\n"
  fi
done

    
if [ ! -z "$3" ]; then
    mkdir -p "$TEMPDIR_NEW"/var/mobile/Library/pkgmirror
    cp -a "$TEMPDIR_OLD"/* "$TEMPDIR_NEW"/var/mobile/Library/pkgmirror/
    mv "$TEMPDIR_NEW"/var/mobile/Library/pkgmirror/DEBIAN "$TEMPDIR_NEW"/var/mobile/Library/pkgmirror/DEBIAN.$DEB_PACKAGE
    cp "$TEMPDIR_NEW"/DEBIAN/*.roothidepatch "$TEMPDIR_NEW"/var/mobile/Library/pkgmirror/DEBIAN.$DEB_PACKAGE/ >/dev/null 2>&1 || true
    chown -R 501:501 "$TEMPDIR_NEW"/var/mobile/Library/pkgmirror/
    chmod -R 0755 "$TEMPDIR_NEW"/var/mobile/Library/pkgmirror/
fi

$SED -i '/^$/d' "$TEMPDIR_NEW"/DEBIAN/control
$SED -i 's|iphoneos-arm64|iphoneos-arm64e|g' "$TEMPDIR_NEW"/DEBIAN/control

if [ "$3" == "AutoPatches" ]; then
    PreDepends="rootless-compat(>= 0.1)"
elif [ "$3" == "DynamicPatches" ]; then
    $SED -i "/^Version\:/d" "$TEMPDIR_NEW"/DEBIAN/control
    echo "Version: $DEB_VERSION~roothide" >> "$TEMPDIR_NEW"/DEBIAN/control
    PreDepends="patches-$DEB_PACKAGE(= $DEB_VERSION~roothide)"
fi

if [ "$PreDepends" != "" ]; then
    if grep -q '^Pre-Depends:' "$TEMPDIR_NEW"/DEBIAN/control; then
        $SED -i "s/^Pre-Depends\:/Pre-Depends: $PreDepends,/" "$TEMPDIR_NEW"/DEBIAN/control
    else
        echo "Pre-Depends: $PreDepends" >> "$TEMPDIR_NEW"/DEBIAN/control
    fi
fi

OUTPUT_PATH="$TMPDIR/$DEB_PACKAGE"_"$DEB_VERSION"_"iphoneos-arm64e".deb

if [ ! -z "$2" ]; then OUTPUT_PATH=$2; fi;

find "$TEMPDIR_NEW" -name ".DS_Store" -delete
dpkg-deb -Zzstd -b "$TEMPDIR_NEW" "$OUTPUT_PATH"
chown 501:501 "$OUTPUT_PATH"

### Real script end

$ECHO "\nfinished. cleaning up..."

if [ "$(sw_vers -productName)" != "macOS" ]; then
    rm -rf "$TEMPDIR_OLD" "$TEMPDIR_NEW"
    rm -f $1
fi
