#!/usr/bin/env bash
# Builds the Qt edition's Linux AppImage into target/dist/:
#   MisterDownloadManager-Qt-<version>-linux-x86_64.AppImage        runs on most distros, Qt inside
#   MisterDownloadManager-Qt-<version>-linux-x86_64.AppImage.zsync  its updates (AppImage tools)
#   SHA256SUMS-linux-qt.txt
# Needs: cargo, Qt 6.4+ with QML modules (Ubuntu: qt6-base-dev qt6-declarative-dev
# qml6-module-qtquick-controls qml6-module-qtquick-layouts qml6-module-qtquick-window
# qml6-module-qtquick-templates qml6-module-qtquick-dialogs qml6-module-qtqml-workerscript),
# cmake, libclang-dev, python3 with Pillow (the icon), network access (linuxdeploy and its Qt
# plugin are fetched), and zsyncmake if the AppImage plugin doesn't write the .zsync itself.
# Build on the oldest Ubuntu you want to support: the program needs its glibc or newer.
#   tools/installer/build-linux-qt.sh [--no-build]
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
dist="$root/target/dist"
version="$(sed -n 's/^version *= *"\([^"]*\)".*/\1/p' "$root/Cargo.toml" | head -1)"
[ -n "$version" ] || { echo "no version in Cargo.toml" >&2; exit 1; }
name="MisterDownloadManager-Qt-$version-linux-x86_64"
exe=misterdownloadmanager-qt
repo="${MDM_QT_REPO:-naufalalamsyah453/misterdownloadmanager-qt}"

if [ "${1:-}" != "--no-build" ]; then
  # The build machine's paths out of the program: cargo's folder and this checkout.
  CARGO_ENCODED_RUSTFLAGS="--remap-path-prefix=${CARGO_HOME:-$HOME/.cargo}=cargo"$'\x1f'"--remap-path-prefix=$root=mdm" \
    cargo build --release -p mdm-qt
fi

mkdir -p "$dist"
stage="$dist/stage-linux-qt"
rm -rf "$stage"
mkdir -p "$stage/AppDir/usr/bin"
install -m 755 "$root/target/release/$exe" "$stage/AppDir/usr/bin/$exe"
strip --strip-all "$stage/AppDir/usr/bin/$exe"

python3 - "$root/art/Mister Download Manager.png" "$stage/misterdownloadmanager-qt.png" <<'PY'
import sys
from PIL import Image
Image.open(sys.argv[1]).convert("RGBA").resize((256, 256), Image.LANCZOS).save(sys.argv[2])
PY
cat > "$stage/misterdownloadmanager-qt.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Mister Download Manager (Qt)
Comment=Download manager
Exec=$exe %U
Icon=misterdownloadmanager-qt
Terminal=false
Categories=Network;FileTransfer;
DESKTOP

# linuxdeploy and its Qt plugin: they copy Qt's libraries, the platform plugins and the QML
# modules the window imports (QML_SOURCES_PATHS lets the plugin's scanner read them: the QML
# files are compiled into the program, so it can't find them there).
tools="$stage/tools"
mkdir -p "$tools"
python3 "$root/tools/installer/fetch_release.py" linuxdeploy/linuxdeploy continuous linuxdeploy-x86_64.AppImage "$tools/linuxdeploy"
python3 "$root/tools/installer/fetch_release.py" linuxdeploy/linuxdeploy-plugin-qt continuous linuxdeploy-plugin-qt-x86_64.AppImage "$tools/linuxdeploy-plugin-qt-x86_64.AppImage"
python3 "$root/tools/installer/fetch_release.py" linuxdeploy/linuxdeploy-plugin-appimage continuous linuxdeploy-plugin-appimage-x86_64.AppImage "$tools/linuxdeploy-plugin-appimage-x86_64.AppImage"
chmod +x "$tools"/*

qmake="$(command -v qmake6 || command -v qmake)"
(
  cd "$stage"
  # No FUSE on CI runners: the tools run from their own extracted copies.
  export APPIMAGE_EXTRACT_AND_RUN=1 ARCH=x86_64 PATH="$tools:$PATH"
  export QMAKE="$qmake" QML_SOURCES_PATHS="$root/crates/qtapp/qml" DEPLOY_PLATFORM_THEMES=1
  # Update information: AppImageLauncher, Gear Lever and AppImageUpdate find the latest
  # release's .zsync and download only the parts that changed.
  export LDAI_UPDATE_INFORMATION="gh-releases-zsync|${repo%/*}|${repo#*/}|latest|MisterDownloadManager-Qt-*-linux-x86_64.AppImage.zsync"
  export LDAI_OUTPUT="$name.AppImage"
  linuxdeploy --appdir AppDir --plugin qt \
    --executable "AppDir/usr/bin/$exe" \
    --desktop-file misterdownloadmanager-qt.desktop \
    --icon-file misterdownloadmanager-qt.png \
    --output appimage
)
mv "$stage/$name.AppImage" "$dist/"
[ -f "$stage/$name.AppImage.zsync" ] && mv "$stage/$name.AppImage.zsync" "$dist/"
if [ ! -f "$dist/$name.AppImage.zsync" ] && command -v zsyncmake >/dev/null; then
  (cd "$dist" && zsyncmake -u "$name.AppImage" -o "$name.AppImage.zsync" "$name.AppImage")
fi

rm -rf "$stage"
(cd "$dist" && sha256sum "$name".* > SHA256SUMS-linux-qt.txt)
ls -l "$dist"
