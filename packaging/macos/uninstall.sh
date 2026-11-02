#!/bin/sh
# Removes the Lockpin pkg from this Mac (a pkg has no uninstaller of its
# own): first the team node its settings made, with lockpin node uninstall,
# which keeps the node's folder; then the program and this folder, and the
# package receipt. Run as root:
#   sudo "/Library/Application Support/Lockpin/pkg/uninstall.sh"
# (Jamf and Kandji run it as a script).
#
# Kept: the rest of /Library/Application Support/Lockpin (the node's folder with its
# sealed store, keys file and ledger, the policy folder, fleet-node.conf),
# the _lockpin account, and each person's own Lockpin data.
set -eu
[ "$(id -u)" = 0 ] || { echo "lockpin: run it as root: sudo $0" >&2; exit 1; }
pkg="/Library/Application Support/Lockpin/pkg"
"$pkg/fleet-node" remove
# The link only if it is still ours: a person may have put their own there.
if [ -L /usr/local/bin/lockpin ] && [ "$(readlink /usr/local/bin/lockpin)" = "$pkg/lockpin" ]; then
  rm -f /usr/local/bin/lockpin
fi
rm -rf "$pkg"
/usr/sbin/pkgutil --forget dev.lockpin.pkg >/dev/null 2>&1 || true
echo "lockpin: removed $pkg and the /usr/local/bin/lockpin link; kept the rest of /Library/Application Support/Lockpin and each person's Lockpin data"
