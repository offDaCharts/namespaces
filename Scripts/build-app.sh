#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
configuration=${1:-release}
output_dir="$project_dir/build"
app_dir="$output_dir/DeskOrbit.app"

cd "$project_dir"
build_args=(-c "$configuration")
if [[ "$configuration" == "release" ]]; then build_args+=(--arch arm64 --arch x86_64); fi
swift build "${build_args[@]}"
binary_dir=$(swift build "${build_args[@]}" --show-bin-path)

rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/Namespaces" "$app_dir/Contents/MacOS/DeskOrbit"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
cp "$project_dir/Resources/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"
chmod 755 "$app_dir/Contents/MacOS/DeskOrbit"

codesign --force --deep --sign - --entitlements "$project_dir/Resources/Namespaces.entitlements" "$app_dir"
codesign --verify --deep --strict "$app_dir"
if [[ -d "$app_dir/Contents/Frameworks" || -d "$app_dir/Contents/XPCServices" ]]; then
    echo "DeskOrbit must remain a single-executable app bundle." >&2
    exit 1
fi
echo "$app_dir"
