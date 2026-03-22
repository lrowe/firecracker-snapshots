#!/busybox/busybox sh
# /dev is mounted by kernel
/busybox/busybox mount -t proc none /proc
# Report guest boot time back to Firecracker via MMIO
# Invalid MMIO read @ 0xc0000000:0x1: bus_error: MissingAddressRange
# /busybox/busybox devmem 0xc0000000 8 123
/busybox/busybox mount -t sysfs none /sys
exec 0</dev/console
exec 1>/dev/console
exec 2>/dev/console
export PATH=/bin
exec "$@"
