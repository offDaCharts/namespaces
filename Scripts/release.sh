#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
app_path=$($script_dir/build-app.sh release | tail -1)
release_dir="$project_dir/build/release"
mkdir -p "$release_dir"
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$project_dir/Resources/Info.plist")

sign_identity=${NAMESPACES_SIGN_IDENTITY:--}
if [[ "$sign_identity" == "-" ]]; then
    codesign --force --deep --sign - --entitlements "$project_dir/Resources/Namespaces.entitlements" "$app_path"
else
    codesign --force --deep --options runtime --timestamp --sign "$sign_identity" --entitlements "$project_dir/Resources/Namespaces.entitlements" "$app_path"
fi
codesign --verify --deep --strict "$app_path"

dmg_path="$release_dir/Namespaces-$version.dmg"
zip_path="$release_dir/Namespaces-$version-macos-universal.zip"
checksums_path="$release_dir/SHA256SUMS.txt"
rm -f "$dmg_path" "$dmg_path.sha256" "$zip_path" "$checksums_path"
hdiutil create -volname Namespaces -srcfolder "$app_path" -ov -format UDZO "$dmg_path" >/dev/null
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$zip_path"

if [[ -n "${NAMESPACES_NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$dmg_path" --keychain-profile "$NAMESPACES_NOTARY_PROFILE" --wait
    xcrun stapler staple "$dmg_path"
    spctl --assess --type open --context context:primary-signature "$dmg_path"
fi

(
    cd "$release_dir"
    shasum -a 256 "${dmg_path:t}" "${zip_path:t}" > "${checksums_path:t}"
)
echo "$release_dir"
