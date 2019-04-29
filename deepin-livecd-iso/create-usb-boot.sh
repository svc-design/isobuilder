
export iso=$1
export disk=$2

mkdir -pv $HOME/LIVE_BOOT/
mount $iso $HOME/LIVE_BOOT/

dd if=/dev/null of=$disk bs=4M count=10

mkdir -p /mnt/{usb,efi}

parted --script $disk \
    mklabel gpt \
    mkpart ESP fat32 1MiB 200MiB \
        name 1 EFI \
        set 1 esp on \
    mkpart primary fat32 200MiB 100% \
        name 2 LINUX \
        set 2 msftdata on

mkfs.vfat -F32 ${disk}1 
mkfs.vfat -F32 ${disk}2

mkdir -p /mnt/{efi,usb}

mount ${disk}1 /mnt/efi
mount ${disk}2 /mnt/usb

grub-install \
    --target=x86_64-efi \
    --efi-directory=/mnt/efi \
    --boot-directory=/mnt/usb/boot \
    --removable \
    --recheck

mkdir -p /mnt/usb/{boot/grub,live}

cp $HOME/LIVE_BOOT/initrd /mnt/usb/
cp $HOME/LIVE_BOOT/vmlinuz /mnt/usb/
cp $HOME/LIVE_BOOT/live/filesystem.squashfs /mnt/usb/live/
cp $HOME/LIVE_BOOT/DEBIAN_CUSTOM /mnt/usb/

cat <<'EOF' >/mnt/usb/boot/grub/grub.cfg

search --set=root --file /DEBIAN_CUSTOM

insmod all_video

set default="0"
set timeout=30

menuentry "DDE Desktop Live" {
    linux /vmlinuz boot=live union=overlay quiet
    initrd /initrd
}
EOF

sync

umount /mnt/{usb,efi}
