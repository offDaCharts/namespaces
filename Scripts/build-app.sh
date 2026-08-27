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
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources" "$app_dir/Contents/Frameworks"
cp "$binary_dir/Namespaces" "$app_dir/Contents/MacOS/DeskOrbit"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
cp "$project_dir/Resources/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"
chmod 755 "$app_dir/Contents/MacOS/DeskOrbit"

sparkle_framework="$project_dir/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [[ ! -d "$sparkle_framework" && -d "$project_dir/.release-private/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework" ]]; then
    sparkle_framework="$project_dir/.release-private/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
fi
if [[ ! -d "$sparkle_framework" ]]; then
    echo "Sparkle.framework was not found at $sparkle_framework" >&2
    exit 1
fi
ditto "$sparkle_framework" "$app_dir/Contents/Frameworks/Sparkle.framework"

codesign --force --deep --sign - --entitlements "$project_dir/Resources/Namespaces.entitlements" "$app_dir"
codesign --verify --deep --strict "$app_dir"
echo "$app_dir"
