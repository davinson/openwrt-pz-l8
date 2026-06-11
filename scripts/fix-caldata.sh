#!/bin/sh
# Insert cmcc,pz-l8 caldata entries into ath11k caldata script
#
# PREREQUISITE: The caldata file must be the clean upstream main version
# (without any cmcc,pz-l8 entries). build.sh ensures this by resetting
# the caldata to HEAD^ (upstream main) before calling this script.
#
# Review-approved settings:
#   2.4GHz (IPQ5018): offset 0x1000, MAC +2, remove_regdomain, set_macflag
#   5GHz  (QCN6122):  offset 0x26800, MAC +3, remove_regdomain, set_macflag

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

# Safety check: file must NOT contain any cmcc,pz-l8 entries
if grep -q 'cmcc,pz-l8' "$CALDATA"; then
    echo "ERROR: $CALDATA already contains cmcc,pz-l8 entries."
    echo "build.sh should reset the caldata file to upstream main first."
    grep -n 'cmcc,pz-l8' "$CALDATA"
    exit 1
fi

echo "=== Inserting cmcc,pz-l8 caldata entries ==="

awk '
BEGIN { in_24ghz = 0; in_5ghz_qcn6122 = 0; inserted_24 = 0; inserted_5 = 0 }

# Track which section we are in
/"ath11k\/IPQ5018\/hw1\.0\/cal-ahb-c000000\.wifi\.bin"/ { in_24ghz = 1; in_5ghz_qcn6122 = 0 }
/"ath11k\/QCN6122\/hw1\.0\/cal-ahb-b00a040\.wifi\.bin"/ { in_5ghz_qcn6122 = 1; in_24ghz = 0 }
/^[ \t]*esac/ && in_24ghz == 1 && inserted_24 == 0 {
    # Insert PZ-L8 2.4GHz entry before esac in the 2.4GHz case block
    print "\tcmcc,pz-l8)"
    print "\t\tcaldata_extract \"0:art\" 0x1000 0x20000"
    print "\t\tlabel_mac=$(mtd_get_mac_binary 0:art 0)"
    print "\t\tath11k_patch_mac $(macaddr_add $label_mac 2) 0"
    print "\t\tath11k_remove_regdomain"
    print "\t\tath11k_set_macflag"
    print "\t\t;;"
    inserted_24 = 1
}
/^[ \t]*esac/ && in_5ghz_qcn6122 == 1 && inserted_5 == 0 {
    # Insert PZ-L8 5GHz (QCN6122) entry before esac in the QCN6122 case block
    print "\tcmcc,pz-l8)"
    print "\t\tcaldata_extract \"0:art\" 0x26800 0x20000"
    print "\t\tlabel_mac=$(mtd_get_mac_binary 0:art 0)"
    print "\t\tath11k_patch_mac $(macaddr_add $label_mac 3) 0"
    print "\t\tath11k_remove_regdomain"
    print "\t\tath11k_set_macflag"
    print "\t\t;;"
    inserted_5 = 1
    in_5ghz_qcn6122 = 0
}
/^[ \t]*esac/ && in_24ghz == 1 && inserted_24 == 1 {
    in_24ghz = 0
}

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
echo "Caldata entries inserted successfully."
