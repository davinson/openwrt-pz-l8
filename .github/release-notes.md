## OpenWrt Firmware for CMCC PZ-L8

**Branch:** main

### Patches

- [PR #21495](https://github.com/openwrt/openwrt/pull/21495) (PZ-L8 device support + ath11k-smallbuffers)

### Files

| File | Mode | Description |
|------|------|-------------|
| `openwrt-pz-l8-factory-ap.ubi` | AP | Factory UBI image (SSH/U-Boot) |
| `openwrt-pz-l8-sysupgrade-ap.bin` | AP | Sysupgrade image |
| `openwrt-pz-l8-factory-router.ubi` | Router | Factory UBI image (SSH/U-Boot) |
| `openwrt-pz-l8-sysupgrade-router.bin` | Router | Sysupgrade image |

### AP Mode

- All ports bridged (lan1, lan2, lan3, wan)
- DHCP client with 192.168.10.1 fallback
- 802.11s mesh support + usteer
- No firewall, no DHCP server

### Router Mode

- Full router features
- WAN: wan port (DHCP or PPPoE)
- LAN: lan1, lan2, lan3 bridged
- Firewall, NAT, IPv6 support

### Common Features

- WiFi: 2.4GHz (IPQ5000) + 5GHz (QCN6102)
- Driver: ath11k-smallbuffers (256MB RAM optimized)
- ZRAM: lzo-rle (default) / zstd (optional)

### ZRAM Compression

- Supported: lzo, lzo-rle, zstd
- Default: lzo-rle (low CPU usage)
- Switch: `echo zstd > /sys/block/zram0/comp_algorithm`
- UCI: `option zram_comp_algo zstd`

### Installation

#### Method 1: SSH (from stock firmware)

1. Enable SSH on stock firmware
2. Upload factory.ubi to /tmp
3. Run:
   ```sh
   export rootfs=$(cat /proc/mtd | grep rootfs | grep -v _ | cut -d: -f1)
   ubidetach -f -p /dev/${rootfs}
   ubiformat /dev/${rootfs} -y -f /tmp/factory.ubi
   reboot
   ```

#### Method 2: U-Boot TFTP

1. Place factory.ubi on TFTP server
2. Enter U-Boot CLI and run:
   ```
   tftpboot <server_ip>:factory.ubi
   flash rootfs
   reset
   ```

#### Method 3: Sysupgrade (from existing OpenWrt)

```sh
sysupgrade /tmp/sysupgrade.bin
```

Use `sysupgrade -n` only if you want to reset all settings to defaults.
