#!/bin/sh
# Fix PZ-L8 caldata per openwrt-ai review feedback on PR #21495
# https://github.com/openwrt/openwrt/pull/21495
#
# Fix 1 (2.4GHz): pull cmcc,pz-l8 out of xiaomi,ax6000 group
#   - Add MAC patching (ath11k_patch_mac +2)
#   - Add regdomain removal and macflag
#
# Fix 2 (5GHz): correct caldata offset 0x1000 -> 0x26800
#   - Add MAC patching (ath11k_patch_mac +3)
#   - Add regdomain removal and macflag

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

echo "=== Before fix ==="
grep -n "cmcc,pz-l8" "$CALDATA"

awk '
BEGIN { state = "normal"; fix1_done = 0; fix2_done = 0 }

state == "normal" && fix1_done == 0 && /^\tcmcc,pz-l8\|\\$/ {
    state = "skip1"
    print "\tcmcc,pz-l8)"
    print "\t\tcaldata_extract \"0:art\" 0x1000 0x20000"
    print "\t\tlabel_mac=$(mtd_get_mac_binary 0:art 0)"
    print "\t\tath11k_patch_mac $(macaddr_add $label_mac 2) 0"
    print "\t\tath11k_remove_regdomain"
    print "\t\tath11k_set_macflag"
    print "\t\t;;"
    print "\txiaomi,ax6000)"
    print "\t\tcaldata_extract \"0:art\" 0x1000 0x20000"
    print "\t\t;;"
    fix1_done = 1
    next
}

state == "skip1" {
    if (/^\t\t;;$/) { state = "normal" }
    next
}

state == "normal" && fix1_done == 1 && fix2_done == 0 && /^\tcmcc,pz-l8\)$/ {
    print
    state = "in_fix2"
    next
}

state == "in_fix2" && /caldata_extract.*0:art.*0x1000/ {
    sub(/0x1000/, "0x26800")
    print
    print "\t\tlabel_mac=$(mtd_get_mac_binary 0:art 0)"
    print "\t\tath11k_patch_mac $(macaddr_add $label_mac 3) 0"
    print "\t\tath11k_remove_regdomain"
    print "\t\tath11k_set_macflag"
    state = "normal"
    fix2_done = 1
    next
}

{ print }
' "$CALDATA" > "${CALDATA}.tmp"

mv "${CALDATA}.tmp" "$CALDATA"

echo ""
echo "=== After fix ==="
grep -n -A 8 "cmcc,pz-l8)" "$CALDATA" | head -20
echo ""
echo "=== xiaomi,ax6000 (should be unchanged) ==="
grep -n -A 2 "xiaomi,ax6000)" "$CALDATA"

echo ""
echo "Caldata fix applied successfully."
