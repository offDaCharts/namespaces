#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
app_path=$($script_dir/build-app.sh release | tail -1)
release_dir="$project_dir/build/release"
mkdir -p "$release_dir"

sign_identity=${NAMESPACES_SIGN_IDENTITY:--}
codesign --force --deep --options runtime --timestamp --sign "$sign_identity" --entitlements "$project_dir/Resources/Namespaces.entitlements" "$app_path"
codesign --verify --deep --strict "$app_path"

dmg_path="$release_dir/Namespaces-0.1.0.dmg"
rm -f "$dmg_path"
hdiutil create -volname Namespaces -srcfolder "$app_path" -ov -format UDZO "$dmg_path" >/dev/null

if [[ -n "${NAMESPACES_NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$dmg_path" --keychain-profile "$NAMESPACES_NOTARY_PROFILE" --wait
    xcrun stapler staple "$dmg_path"
    spctl --assess --type open --context context:primary-signature "$dmg_path"
fi

shasum -a 256 "$dmg_path" > "$dmg_path.sha256"
echo "$dmg_path"
