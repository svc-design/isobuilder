#!/bin/bash

set -x

export REPO=https://mirrors.tuna.tsinghua.edu.cn/debian/
export CHROOT=$HOME/chroot
export PKG_CORE="locales,busybox,initramfs-tools,ssh,tar,iptables,linux-image-amd64,grub-efi,live-boot,vim"
export PKG_DESKTOP="deepin-desktop-base,dde-desktop,dde-dock,dde-launcher,dde-control-center,deepin-metacity,deepin-wm,startdde,dde-session-ui,deepin-artwork,dde-file-manager,dde-qt5integration,dde-disk-mount-plugin,deepin-wallpapers,fonts-noto,fonts-noto-color-emoji,deepin-terminal,deepin-screenshot,deepin-system-monitor,deepin-shortcut-viewer,ttf-deepin-opensymbol,lightdm"
export PKG="$PKG_CORE,$PKG_DESKTOP,task-desktop,xserver-xorg-core,xserver-xorg,xinit"

rm -rvf $HOME/chroot/
rm -rvf $HOME/LIVE_BOOT/

mkdir -p $HOME/chroot
mkdir -p $HOME/LIVE_BOOT/{scratch,image/live}
apt install debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools -y

debootstrap --no-check-gpg --include=$PKG_CORE --components=main,non-free,contrib --arch=amd64 buster $CHROOT $REPO 
#debootstrap --no-check-gpg --variant=minbase --include=$PKG_CORE --exclude=360safeforcnos,dbus --components=main,non-free,contrib --arch=amd64 buster $CHROOT $REPO 

#apt-get download `cat mini-base.list`

mount --bind /dev/   $CHROOT/dev
mount -t proc proc   $CHROOT/proc
mount -t sysfs sysfs $CHROOT/sys

#debootstrap --no-check-gpg --include=$PKG_DESKTOP --exclude=360safeforcnos --components=main,non-free,contrib --arch=amd64 unstable $CHROOT $REPO 

cat <<'EOF' >$HOME/chroot/tmp/set-passwd.sh
echo "root:live" | chpasswd
EOF

chmod 755 $HOME/chroot/tmp/set-passwd.sh
chroot $CHROOT "/tmp/set-passwd.sh" 

umount  $CHROOT/dev
umount  $CHROOT/proc
umount  $CHROOT/sys
#rm -rvf $CHROOT/chroot/var/cache/apt/archives/


mksquashfs $HOME/chroot $HOME/LIVE_BOOT/image/live/filesystem.squashfs 
cp $HOME/chroot/boot/vmlinuz-* $HOME/LIVE_BOOT/image/vmlinuz
cp $HOME/chroot/boot/initrd.img-* $HOME/LIVE_BOOT/image/initrd

cat <<'EOF' >$HOME/LIVE_BOOT/scratch/grub.cfg

search --set=root --file /DEBIAN_CUSTOM

insmod all_video

set default="0"
set timeout=30

menuentry "Deepin Desktop Live" {
    linux /vmlinuz boot=live quiet
    initrd /initrd
}
menuentry "Deepin CMD Live" {
    linux /vmlinuz boot=live quiet single nomodeset
    initrd /initrd
}
EOF

touch $HOME/LIVE_BOOT/image/DEBIAN_CUSTOM
grub-mkstandalone --format=x86_64-efi --output=$HOME/LIVE_BOOT/scratch/bootx64.efi --locales="" --fonts="" "boot/grub/grub.cfg=$HOME/LIVE_BOOT/scratch/grub.cfg"
cd $HOME/LIVE_BOOT/scratch && dd if=/dev/zero of=efiboot.img bs=1M count=10 && mkfs.vfat efiboot.img && mmd -i efiboot.img efi efi/boot && mcopy -i efiboot.img ./bootx64.efi ::efi/boot/

xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "DEBIAN_CUSTOM" \
    -eltorito-alt-boot \
    -e EFI/efiboot.img \
    -no-emul-boot \
    -append_partition 2 0xef ${HOME}/LIVE_BOOT/scratch/efiboot.img \
    -graft-points "${HOME}/LIVE_BOOT/image" /EFI/efiboot.img=$HOME/LIVE_BOOT/scratch/efiboot.img \
    -output "${HOME}/LIVE_BOOT/deepin-desktop-live.iso"

