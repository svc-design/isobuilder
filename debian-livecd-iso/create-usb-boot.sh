
export disk=/dev/sda

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

cp -r $HOME/LIVE_BOOT/image/* /mnt/usb/
cp $HOME/LIVE_BOOT/scratch/grub.cfg /mnt/usb/boot/grub/grub.cfg

sync

umount /mnt/{usb,efi}
