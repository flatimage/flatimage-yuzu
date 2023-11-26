#!/usr/bin/env bash

######################################################################
# @author      : Ruan E. Formigoni (ruanformigoni@gmail.com)
# @file        : build
# @created     : Friday Nov 24, 2023 19:06:13 -03
#
# @description : 
######################################################################

set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

build_dir="$SCRIPT_DIR/build"

rm -rf "$build_dir"; mkdir "$build_dir"; cd "$build_dir"

# Fetch latest release
read -r url_yuzu < <(wget --header="Accept: application/vnd.github+json" -O - \
  https://api.github.com/repos/yuzu-emu/yuzu-mainline/releases 2>&1 |
  grep -o "https://.*\.AppImage" | sort | tail -n1)

wget "$url_yuzu"

# Fetched file name
appimage_yuzu="$(basename "$url_yuzu")"

# Make executable
chmod +x "$build_dir/$appimage_yuzu"

# Extract appimage
"$build_dir/$appimage_yuzu" --appimage-extract

# Fetch container
if ! [ -f "$build_dir/arch.tar.xz" ]; then
  wget "https://gitlab.com/api/v4/projects/43000137/packages/generic/fim/continuous/arch.tar.xz"
fi

# Extract container
[ ! -f "$build_dir/arch.fim" ] || rm "$build_dir/arch.fim"
tar xf arch.tar.xz

# FIM_COMPRESSION_LEVEL
export FIM_COMPRESSION_LEVEL=6

# Resize
"$build_dir"/arch.fim fim-resize 3G

# Update
"$build_dir"/arch.fim fim-root fakechroot pacman -Syu --noconfirm

# Install dependencies
"$build_dir"/arch.fim fim-root fakechroot pacman -S libxkbcommon libxkbcommon-x11 \
  lib32-libxkbcommon lib32-libxkbcommon-x11 libsm lib32-libsm fontconfig \
  lib32-fontconfig noto-fonts --noconfirm

# Install video packages
"$build_dir"/arch.fim fim-root fakechroot pacman -S xorg-server mesa lib32-mesa \
  glxinfo pcre xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon \
  xf86-video-intel vulkan-intel lib32-vulkan-intel vulkan-tools --noconfirm

# Compress main image
"$build_dir"/arch.fim fim-compress

# Compress yuzu
"$build_dir"/arch.fim fim-exec mkdwarfs -i "$build_dir"/squashfs-root/usr -o "$build_dir/yuzu.dwarfs"

# Include yuzu
"$build_dir"/arch.fim fim-include-path "$build_dir"/yuzu.dwarfs "/yuzu.dwarfs"

# Include runner script
{ tee "$build_dir"/yuzu.sh | sed -e "s/^/-- /"; } <<-'EOL'
#!/bin/bash

export LD_LIBRARY_PATH="/yuzu/lib:$LD_LIBRARY_PATH"

/yuzu/bin/yuzu "$@"
EOL
chmod +x "$build_dir"/yuzu.sh
"$build_dir"/arch.fim fim-root cp "$build_dir"/yuzu.sh /fim/yuzu.sh

# Set default command
"$build_dir"/arch.fim fim-cmd /fim/yuzu.sh

# Set perms
"$build_dir"/arch.fim fim-perms-set wayland,x11,pulseaudio,gpu,session_bus,input,usb

# Rename
mv "$build_dir/arch.fim" yuzu-arch.fim


# // cmd: !./%
