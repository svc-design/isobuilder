#!/bin/bash
 
set -x

export REPO_NET=http://mirrors.tuna.tsinghua.edu.cn/deepin/
export DIST=lion
export CHROOT=$HOME/chroot
export PKG_CORE="locales,busybox,systemd,systemd-sysv,initramfs-tools,linux-image-amd64,grub-efi,live-boot"

function do_prep()
{
    rm -rvf  $HOME/chroot/
    rm -rvf  $HOME/LIVE_BOOT/
    apt install debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools -y
}

#apt-get download `cat mini-base.list`

function do_first_stage()
{

ln -sv /usr/share/debootstrap/scripts/sid /usr/share/debootstrap/scripts/lion -f
debootstrap --no-check-gpg --variant=minbase --include=$PKG_CORE --components=main,non-free,contrib --arch=amd64 $DIST $CHROOT $REPO_NET

mount --bind /dev/   $CHROOT/dev
mount -t proc proc   $CHROOT/proc
mount -t sysfs sysfs $CHROOT/sys

cat <<'EOF' >${CHROOT}/etc/apt/sources.list
deb [trusted=yes] http://mirrors.tuna.tsinghua.edu.cn/deepin/ lion main contrib non-free
EOF

cat <<'EOF' >${CHROOT}/tmp/set-livecd.sh
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
useradd live
groupadd live
mkdir /home/live && chown live:live /home/live/ 
echo "root:live" | chpasswd 
echo "live:live" | chpasswd 
apt update && apt install ssh tar iptables vim isc-dhcp-client iproute2 deepin-keyring -y
EOF
chmod 755 $HOME/chroot/tmp/set-livecd.sh
chroot $CHROOT "/tmp/set-livecd.sh" 
}


function do_second_stage()
{

cat <<'EOF' >${CHROOT}/etc/apt/sources.list
deb [trusted=yes] http://mirrors.tuna.tsinghua.edu.cn/deepin/ lion main contrib non-free
EOF

cat <<'EOF' >${CHROOT}/tmp/set-livecd.sh
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt update && apt -f install -y
apt install live-config linux-image-deepin-amd64 linux-tools-4.15.0-30deepin linux-headers-4.15.0-30deepin linux-source-4.15.0 firmware-misc-nonfree firmware-linux-free firmware-iwlwifi bluez-firmware network-manager lightdm fcitx fcitx-frontend-qt5 fcitx-frontend-gtk3 sogoupinyin xserver-xorg-core xserver-xorg-input-all xserver-xorg-video-all xserver-xorg-input-wacom xinit -y
apt install --no-install-recommends dde deepin-installer deepin-terminal google-chrome-stable deepin-appstore -y
apt-get remove linux-image-amd64 linux-image-4.9.0-8-amd64  xterm --purge -y 
update-initramfs -u
#apt install kubeadm kubectl kubelet docker.io ansible teamviewer dingtalk foxitreader touchpad-indicator deepin-screenshot shadowsocks-qt5 wps-office thunderbird thunderbird-locale-zh-hans electronic-wechat -y
EOF
chmod 755 $HOME/chroot/tmp/set-livecd.sh
chroot $CHROOT "/tmp/set-livecd.sh" 
}

function do_umount()
{
umount  $CHROOT/dev
umount  $CHROOT/proc
umount  $CHROOT/sys
}

function do_clean()
{
rm -rvf $CHROOT/var/cache/apt/archives/ 
}

function do_mk_file()
{

mkdir -p $HOME/chroot
mkdir -p $HOME/LIVE_BOOT/{scratch,image/live}
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
menuentry "Desktop Live overlay" {
    linux /vmlinuz boot=live union=overlay quiet
    initrd /initrd
}
EOF

touch $HOME/LIVE_BOOT/image/DEBIAN_CUSTOM
grub-mkstandalone --format=x86_64-efi --output=$HOME/LIVE_BOOT/scratch/bootx64.efi --locales="" --fonts="" "boot/grub/grub.cfg=$HOME/LIVE_BOOT/scratch/grub.cfg"
cd $HOME/LIVE_BOOT/scratch                      && \
dd if=/dev/zero of=efiboot.img bs=1M count=10	&& \
mkfs.vfat efiboot.img							&& \
mmd -i efiboot.img efi efi/boot					&& \
mcopy -i efiboot.img ./bootx64.efi ::efi/boot/

}

function do_mkiso()
{

xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "DEBIAN_CUSTOM" \
    -eltorito-alt-boot \
    -e EFI/efiboot.img \
    -no-emul-boot \
    -append_partition 2 0xef ${HOME}/LIVE_BOOT/scratch/efiboot.img \
    -graft-points "${HOME}/LIVE_BOOT/image" /EFI/efiboot.img=$HOME/LIVE_BOOT/scratch/efiboot.img \
    -output "${HOME}/LIVE_BOOT/Deepin-15.9.2-custom-LiveCD.iso"
}

do_prep
do_first_stage
do_second_stage
do_umount
do_clean
do_mk_file
do_mkiso
