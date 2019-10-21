#
KERNCONF=GENERIC-MMCCAM
UBOOT_DIR="u-boot-rock-pi-4"
UBOOT_PATH="/usr/local/share/u-boot/${UBOOT_DIR}"
UBOOT_BIN="u-boot.itb"
IMAGE_SIZE=$((1000 * 1000 * 1000))
TARGET_ARCH=aarch64
TARGET=aarch64

rockpi4_check_uboot ( ) {
	uboot_port_test ${UBOOT_DIR} ${UBOOT_BIN}
}

strategy_add $PHASE_CHECK rockpi4_check_uboot

#
# RockPi4 uses EFI, so the first partition will be a FAT partition.
#
rockpi4_partition_image ( ) {
	echo "Installing Partitions on ${DISK_MD}"
	dd if=${UBOOT_PATH}/idbloader.img of=/dev/${DISK_MD} conv=sync bs=512 seek=64
	dd if=${UBOOT_PATH}/${UBOOT_BIN}  of=/dev/${DISK_MD} conv=sync bs=512 seek=16384
	disk_partition_mbr
	disk_fat_create 16m 16 1m
	disk_ufs_create
}
strategy_add $PHASE_PARTITION_LWW rockpi4_partition_image

rockpi4_boot_install ( ) {
	mkdir -p efi/boot
	echo bootaa64 > startup.nsh
}
strategy_add $PHASE_BOOT_INSTALL rockpi4_boot_install

# Build & install loader.efi.
strategy_add $PHASE_BUILD_OTHER  freebsd_loader_efi_build
strategy_add $PHASE_BOOT_INSTALL mkdir -p efi efi/boot
strategy_add $PHASE_BOOT_INSTALL freebsd_loader_efi_copy efi/boot/bootaa64.efi

# Khadas EDGE puts the kernel on the FreeBSD UFS partition.
strategy_add $PHASE_FREEBSD_BOARD_INSTALL board_default_installkernel .

# overlay/etc/fstab mounts the FAT partition at /boot/msdos
strategy_add $PHASE_FREEBSD_BOARD_INSTALL mkdir -p boot/msdos

fix_dtb_path ( ) {
	echo "Fix DTB path to ${BOARD_FREEBSD_MOUNTPOINT}/boot/dtb"
	DTBFILE="${BOARD_FREEBSD_MOUNTPOINT}/boot/dtb/rockchip/rk3399-rock-pi-4.dtb"
	if [ -f ${DTBFILE} ] ; then
		cp ${DTBFILE} ${BOARD_FREEBSD_MOUNTPOINT}/boot/dtb
	fi
}

PRIORITY=200 strategy_add $PHASE_FREEBSD_OPTION_INSTALL fix_dtb_path

