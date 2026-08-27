#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
app_path=$($script_dir/build-app.sh release | tail -1)
release_dir="$project_dir/build/release"
mkdir -p "$release_dir"
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$project_dir/Resources/Info.plist")

sign_identity=${DESKORBIT_SIGN_IDENTITY:-${NAMESPACES_SIGN_IDENTITY:--}}
if [[ "$sign_identity" == "-" ]]; then
    codesign --force --deep --sign - --entitlements "$project_dir/Resources/Namespaces.entitlements" "$app_path"
else
    codesign --force --deep --options runtime --timestamp --sign "$sign_identity" --entitlements "$project_dir/Resources/Namespaces.entitlements" "$app_path"
fi
codesign --verify --deep --strict "$app_path"

dmg_path="$release_dir/DeskOrbit-$version.dmg"
zip_path="$release_dir/DeskOrbit-$version-macos-universal.zip"
checksums_path="$release_dir/SHA256SUMS.txt"
rm -f "$dmg_path" "$dmg_path.sha256" "$zip_path" "$checksums_path"
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$zip_path"

notary_profile=${DESKORBIT_NOTARY_PROFILE:-${NAMESPACES_NOTARY_PROFILE:-}}
notary_key=${DESKORBIT_NOTARY_KEY:-}
notary_key_id=${DESKORBIT_NOTARY_KEY_ID:-}
notary_issuer=${DESKORBIT_NOTARY_ISSUER:-}
notary_args=()
if [[ -n "$notary_profile" ]]; then
    notary_args=(--keychain-profile "$notary_profile")
elif [[ -n "$notary_key" && -n "$notary_key_id" && -n "$notary_issuer" ]]; then
    notary_args=(--key "$notary_key" --key-id "$notary_key_id" --issuer "$notary_issuer")
fi

if (( ${#notary_args[@]} )); then
    xcrun notarytool submit "$zip_path" "${notary_args[@]}" --wait
    xcrun stapler staple "$app_path"
    ditto -c -k --sequesterRsrc --keepParent "$app_path" "$zip_path"
fi

hdiutil create -volname DeskOrbit -srcfolder "$app_path" -ov -format UDZO "$dmg_path" >/dev/null
if [[ "$sign_identity" != "-" ]]; then
    codesign --force --timestamp --sign "$sign_identity" "$dmg_path"
fi

if (( ${#notary_args[@]} )); then
    xcrun notarytool submit "$dmg_path" "${notary_args[@]}" --wait
    xcrun stapler staple "$dmg_path"
    spctl --assess --type execute --verbose=2 "$app_path"
    spctl --assess --type open --context context:primary-signature "$dmg_path"
fi

(
    cd "$release_dir"
    shasum -a 256 "${dmg_path:t}" "${zip_path:t}" > "${checksums_path:t}"
)

sparkle_tools=${DESKORBIT_SPARKLE_TOOLS:-"$project_dir/.build/artifacts/sparkle/Sparkle/bin"}
if [[ -x "$sparkle_tools/generate_appcast" ]]; then
    sparkle_dir="$project_dir/build/sparkle"
    mkdir -p "$sparkle_dir"
    cp "$zip_path" "$sparkle_dir/${zip_path:t}"
    cp "$project_dir/Docs/RELEASE_NOTES.md" "$sparkle_dir/${zip_path:t:r}.md"
    sparkle_args=(
        --download-url-prefix "https://github.com/offDaCharts/namespaces/releases/download/v$version/"
        --link "https://deskorbit.kauibungalow.com"
        --maximum-versions 1
        -o appcast.xml
    )
    if [[ -n "${DESKORBIT_SPARKLE_PRIVATE_KEY_FILE:-}" ]]; then
        sparkle_args+=(--ed-key-file "$DESKORBIT_SPARKLE_PRIVATE_KEY_FILE")
    fi
    "$sparkle_tools/generate_appcast" "${sparkle_args[@]}" "$sparkle_dir"
    cp "$sparkle_dir/appcast.xml" "$release_dir/appcast.xml"
fi
echo "$release_dir"
