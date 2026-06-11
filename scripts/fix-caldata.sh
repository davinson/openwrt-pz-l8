#!/bin/sh
# Enhance cmcc,pz-l8 caldata entries in ath11k caldata script
#
# PR #21495 adds basic caldata_extract entries for cmcc,pz-l8.
# This script replaces them with full entries that also include
# MAC address patching, regdomain removal, and macflag setting.
#
# Expected input: the caldata file AFTER PR #21495 has been applied
# (must contain existing cmcc,pz-l8 entries).

set -e

CALDATA="$1"

if [ -z "$CALDATA" ]; then
    echo "Usage: $0 <caldata-file>"
    exit 1
fi

if [ ! -f "$CALDATA" ]; then
    echo "ERROR: $CALDATA not found"
    exit 1
fi

if ! grep -q 'cmcc,pz-l8' "$CALDATA"; then
    echo "ERROR: $CALDATA does not contain cmcc,pz-l8 entries."
    echo "PR #21495 must be applied before running this script."
    exit 1
fi

echo "=== Enhancing cmcc,pz-l8 caldata entries ==="

# Replace PR's basic entries with our full entries.
# Use awk to find cmcc,pz-l8 case blocks and replace their body
# (between "cmcc,pz-l8)" and ";;").
awk '
/^[ \t]*cmcc,pz-l8\)/ { in_block=1; print; next }
in_block && /^[ \t]*;;/ {
    # Output the full entry based on which section we are in
    if (in_24ghz) {
        print "\t\tlabel_mac=$(mtd_get_mac_binary 0:art 0)"
        print "\t\tath11k_patch_mac $(macaddr_add $label_mac 2) 0"
        print "\t\tath11k_remove_regdomain"
        print "\t\tath11k_set_macflag"
    } else if (in_5ghz_qcn6122) {
        print "\t\tlabel_mac=$(mtd_get_mac_binary 0:art 0)"
        print "\t\tath11k_patch_mac $(macaddr_add $label_mac 3) 0"
        print "\t\tath11k_remove_regdomain"
        print "\t\tath11k_set_macflag"
    }
    print $0
    in_block=0
    next
}
in_block { next }  # Skip the original body (caldata_extract line)
# Track which section we are in
/"ath11k\/IPQ5018\/hw1\.0\/cal-ahb-c000000\.wifi\.bin"/ { in_24ghz = 1; in_5ghz_qcn6122 = 0 }
/"ath11k\/QCN6122\/hw1\.0\/cal-ahb-b00a040\.wifi\.bin"/ { in_5ghz_qcn6122 = 1; in_24ghz = 0 }
{ print }
' "$CALDATA" > "${CALDATA}.tmp"

mv "${CALDATA}.tmp" "$CALDATA"

# Verify result has no syntax errors
if ! bash -n "$CALDATA"; then
    echo "ERROR: Generated caldata file has syntax errors!"
    exit 1
fi

echo "=== Result ==="
echo "--- 2.4GHz (IPQ5018) ---"
grep -n -B 1 -A 8 "cmcc,pz-l8)" "$CALDATA" | head -20
echo ""
echo "--- 5GHz (QCN6122) ---"
grep -n -B 1 -A 8 "cmcc,pz-l8)" "$CALDATA" | tail -12

echo ""
echo "Caldata entries enhanced successfully."
