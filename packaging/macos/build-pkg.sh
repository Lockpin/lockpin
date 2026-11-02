#!/bin/sh
# Builds Lockpin's macOS installer packages, one per architecture, from a
# release's darwin archives: a flat pkg installing, in a folder only root
# can change all the way up (Homebrew gives /usr/local to a user on Intel
# Macs, and root runs these),
#   /Library/Application Support/Lockpin/pkg/lockpin        the release's binary, unchanged
#   /Library/Application Support/Lockpin/pkg/fleet-node     the team-node hook (packaging/unix)
#   /Library/Application Support/Lockpin/pkg/uninstall.sh   removes the pkg (a pkg has no uninstaller)
#   /Library/Application Support/Lockpin/pkg/LICENSE, NOTICE
#   /usr/local/bin/lockpin, a link made by postinstall when nothing is there (not
#   in the payload, so the pkg never resets that folder, Homebrew's on Intel Macs)
# with a postinstall that runs the hook. The receipt is dev.lockpin.pkg.
#
#   VERSION=v1.2.3 packaging/macos/build-pkg.sh               from dist/, into dist/packages/
#   DIST=... OUT=... ARCHS="arm64" VERSION=v1.2.3 packaging/macos/build-pkg.sh
#
# Needs a Mac (pkgbuild, productbuild, shasum, tar). NOT RUN by its author,
# who had no Mac: run it, then `pkgutil --payload-files` and
# `pkgutil --expand` on the result, before trusting it.
#
# Signing: with LOCKPIN_PKG_SIGN_IDENTITY="Developer ID Installer: NAME (TEAMID)"
# productbuild signs the pkg. The binary inside is never re-signed here: it
# is the release's, byte for byte, so its Developer ID Application signature
# (hardened runtime, timestamp) belongs in the release job
# (docs/packaging-plan.md). Notarisation needs the owner's Apple Developer
# account; with a keychain profile made by `xcrun notarytool store-credentials`:
#   xcrun notarytool submit dist/packages/lockpin_X_darwin_arm64.pkg --keychain-profile lockpin --wait
#   xcrun stapler staple dist/packages/lockpin_X_darwin_arm64.pkg
set -eu

cd "$(dirname "$0")/../.."
VERSION="${VERSION:?set VERSION to a release tag, vX.Y.Z}"
DIST="${DIST:-dist}"
OUT="${OUT:-dist/packages}"
ARCHS="${ARCHS:-amd64 arm64}"
case "$VERSION" in
  v[0-9]*.[0-9]*.[0-9]*) ;;
  *) echo "build-pkg: VERSION=$VERSION is not a release tag (vX.Y.Z)" >&2; exit 1 ;;
esac
case "$VERSION" in
  *-*) echo "build-pkg: VERSION=$VERSION: a prerelease or a build between tags; the pkg's version must name a release" >&2; exit 1 ;;
esac
NAME="${VERSION#v}"
for tool in pkgbuild productbuild shasum tar; do
  command -v "$tool" >/dev/null || { echo "build-pkg: $tool is required (this script needs a Mac)" >&2; exit 1; }
done
mkdir -p "$OUT"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

for arch in $ARCHS; do
  case "$arch" in
    amd64) host=x86_64 ;;
    arm64) host=arm64 ;;
    *) echo "build-pkg: arch $arch: amd64 or arm64" >&2; exit 1 ;;
  esac
  base="lockpin_${NAME}_darwin_${arch}"
  want="$(awk -v f="$base.tar.gz" '$2 == f || $2 == "*" f { print $1 }' "$DIST/SHA256SUMS")"
  got="$(shasum -a 256 "$DIST/$base.tar.gz" | awk '{ print $1 }')"
  [ -n "$want" ] && [ "$got" = "$want" ] || { echo "build-pkg: $base.tar.gz has SHA-256 $got, SHA256SUMS says '${want}'" >&2; exit 1; }

  root="$stage/$arch/root"
  pkgdir="$root/Library/Application Support/Lockpin/pkg"
  mkdir -p "$pkgdir"
  tar -xzf "$DIST/$base.tar.gz" -C "$stage/$arch" "$base/lockpin"
  install -m 755 "$stage/$arch/$base/lockpin" "$pkgdir/lockpin"
  install -m 755 packaging/unix/fleet-node "$pkgdir/fleet-node"
  install -m 755 packaging/macos/uninstall.sh "$pkgdir/uninstall.sh"
  install -m 644 LICENSE NOTICE "$pkgdir/"
  mkdir -p "$stage/$arch/scripts"
  install -m 755 packaging/macos/scripts/postinstall "$stage/$arch/scripts/postinstall"

  pkgbuild --root "$root" --install-location / --scripts "$stage/$arch/scripts" \
    --identifier dev.lockpin.pkg --version "$NAME" --ownership recommended \
    "$stage/$arch/lockpin-component.pkg"

  cat > "$stage/$arch/distribution.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
  <title>Lockpin $NAME</title>
  <options customize="never" require-scripts="false" hostArchitectures="$host"/>
  <domains enable_anywhere="false" enable_currentUserHome="false" enable_localSystem="true"/>
  <volume-check><allowed-os-versions><os-version min="11.0"/></allowed-os-versions></volume-check>
  <choices-outline><line choice="dev.lockpin.pkg"/></choices-outline>
  <choice id="dev.lockpin.pkg" visible="false"><pkg-ref id="dev.lockpin.pkg"/></choice>
  <pkg-ref id="dev.lockpin.pkg" version="$NAME" onConclusion="none">lockpin-component.pkg</pkg-ref>
</installer-gui-script>
XML

  set -- --distribution "$stage/$arch/distribution.xml" --package-path "$stage/$arch"
  if [ -n "${LOCKPIN_PKG_SIGN_IDENTITY:-}" ]; then
    set -- "$@" --sign "$LOCKPIN_PKG_SIGN_IDENTITY" --timestamp
  fi
  productbuild "$@" "$OUT/$base.pkg"
  [ -z "${LOCKPIN_PKG_SIGN_IDENTITY:-}" ] || pkgutil --check-signature "$OUT/$base.pkg"
  echo "wrote $OUT/$base.pkg (lockpin SHA-256 $(shasum -a 256 "$pkgdir/lockpin" | awk '{ print $1 }'))"
done
