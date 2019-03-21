#!/bin/bash
parted --script /dev/sda \
   　　　　mklabel gpt \
    　　　  mkpart ESP fat32 1MiB 200MiB \
       　　　　　　　name 1 EFI \
        　　　　　　　set 1 esp on \
              mkpart primary fat32 200MiB 100% \
                          name 2 LINUX \
                          set 2 msftdata on

    mkfs.vfat -F32 /dev/sda1
    mkfs.ext4 /dev/sda2
　

mkdir -pv  /mnt/target
mount /dev/sda2 /mnt/target
cp -av /lib/live/mount/rootfs/filesystem.squashfs /mnt/target/
mount /dev/sda1 /mnt/target/boot/efi


mount --bind /dev/   /mnt/target/dev
mount -t proc proc    /mnt/target/proc
mount -t sysfs sysfs  /mnt/target/sys

#安装启动过引导器
chroot /mnt/target/ grub-install /dev/sda　　　　　　　　                   
#删除无用的软件包　　
chroot /mnt/target/ apt remove  live-config　live-boot　deepin-installer -y　                    
#安装内核
chroot /mnt/target/ apt install linux-image-deepin-amd64 -y　　　　　　　　　
#生成　initramfs
chroot /mnt/target/ update-initramfs -u                                                          

cat >/etc/fstab <EOF
UUID=CEA6-99F8      	                    /boot/efi 	vfat      	defaults	0 2
UUID=73f612d6-f41d-4c44-b255-84e237462759	/         	ext4      	defaults	0 1
EOF
