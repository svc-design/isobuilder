#!/bin/bash
 
set -x

export REPO_LOCAL=file:///mnt/root/repo
export CHROOT=$HOME/chroot
export PKG_CORE="locales,busybox,initramfs-tools,ssh,tar,iptables,linux-image-amd64,grub-efi,live-boot,vim"

rm -rvf $HOME/chroot/
rm -rvf $HOME/LIVE_BOOT/

mkdir -p $HOME/chroot
mkdir -p $HOME/LIVE_BOOT/{scratch,image/live}
apt install debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools -y

#apt-get download `cat mini-base.list`

debootstrap --no-check-gpg --variant=minbase --include=$PKG_CORE --components=main,non-free,contrib --arch=amd64 buster $CHROOT $REPO_LOCAL

mount --bind /dev/   $CHROOT/dev
mount -t proc proc   $CHROOT/proc
mount -t sysfs sysfs $CHROOT/sys


cat <<'EOF' >$HOME/chroot/etc/apt/sources.list
deb [trusted=yes] http://127.0.0.1/repo/ panda main contrib non-free
deb [trusted=yes] http://mirrors.tuna.tsinghua.edu.cn/deepin/ panda main contrib non-free
EOF

cat <<'EOF' >$HOME/chroot/tmp/set-livecd.sh
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
useradd live
groupadd live
mkdir /home/live && chown live:live /home/live/ 
echo "root:live" | chpasswd 
echo "live:live" | chpasswd 
apt update && apt -f install -y
apt install network-manager -y
apt install live-config lightdm -y
apt-get remove linux-image-4.16.0-1-amd64 --purge -y 
apt install fcitx fcitx-frontend-qt5 fcitx-frontend-gtk3 sogoupinyin -y
apt install --no-install-recommends dde deepin-installer deepin-terminal google-chrome-stable -y
apt install xserver-xorg-core xserver-xorg-input-all xserver-xorg-video-all xserver-xorg-input-wacom xinit -y
apt install linux-image-deepin-amd64 linux-headers-4.15.0-29deepin linux-source-4.15.0 firmware-misc-nonfree firmware-linux-free firmware-iwlwifi bluez-firmware -y
apt-get remove xterm --purge -y 
apt install kubeadm kubectl kubelet docker.io ansible teamviewer dingtalk touchpad-indicator deepin-screenshot wps-office thunderbird thunderbird-locale-zh-hans -y
EOF
chmod 755 $HOME/chroot/tmp/set-livecd.sh
chroot $CHROOT "/tmp/set-livecd.sh" 
rm -rvf $CHROOT/var/cache/apt/archives/ 

umount  $CHROOT/dev
umount  $CHROOT/proc
umount  $CHROOT/sys

mksquashfs $HOME/chroot $HOME/LIVE_BOOT/image/live/filesystem.squashfs -comp xz 
cp $HOME/chroot/boot/vmlinuz-* $HOME/LIVE_BOOT/image/vmlinuz
cp $HOME/chroot/boot/initrd.img-* $HOME/LIVE_BOOT/image/initrd

cat <<'EOF' >$HOME/LIVE_BOOT/scratch/grub.cfg

search --set=root --file /DEBIAN_CUSTOM

insmod all_video

set default="0"
set timeout=30

menuentry "Desktop Live" {
    linux /vmlinuz boot=live quiet
    initrd /initrd
}
EOF

touch $HOME/LIVE_BOOT/image/DEBIAN_CUSTOM
grub-mkstandalone --format=x86_64-efi --output=$HOME/LIVE_BOOT/scratch/bootx64.efi --locales="" --fonts="" "boot/grub/grub.cfg=$HOME/LIVE_BOOT/scratch/grub.cfg"
cd $HOME/LIVE_BOOT/scratch                            && \
       	dd if=/dev/zero of=efiboot.img bs=1M count=10 && \
	mkfs.vfat efiboot.img                         && \
	mmd -i efiboot.img efi efi/boot               && \
	mcopy -i efiboot.img ./bootx64.efi ::efi/boot/

xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "DEBIAN_CUSTOM" \
    -eltorito-alt-boot \
    -e EFI/efiboot.img \
    -no-emul-boot \
    -append_partition 2 0xef ${HOME}/LIVE_BOOT/scratch/efiboot.img \
    -graft-points "${HOME}/LIVE_BOOT/image" /EFI/efiboot.img=$HOME/LIVE_BOOT/scratch/efiboot.img \
    -output "${HOME}/LIVE_BOOT/deepin-desktop-core-20181210.iso"
