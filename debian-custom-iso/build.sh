#!/bin/bash
set -x

export release=$1 

case $release in
	deepin)  source CONF/deepin.conf  ;;
	debian8) source CONF/debian8.conf ;;
	debian9) source CONF/debian9.conf ;;
	*) source CONF/deepin.conf ;;
esac

mkdir -pv ${WORKDIR}/isotree/
mkdir -pv ${WORKDIR}/isotree/{boot,efi,isolinux,installer,.disk}
mkdir -pv ${WORKDIR}/isotree/efi/boot/
touch     ${WORKDIR}/isotree/.disk/{base_components,base_installable,cd_type,info,udeb_include}

# 将安装器相关的启动文件解压到模板目录中

cd ${WORKDIR}/
wget ${installer_url}/debian-cd_info.tar.gz
wget ${installer_url}/initrd.gz
wget ${installer_url}/vmlinuz
mkdir -pv tmp && tar -xvpf debian-cd_info.tar.gz -C tmp
cp    -av ./{vmlinuz,initrd.gz}                                       isotree/installer            
mcopy     -i tmp/grub/efi.img ::efi/boot/bootx64.efi                  isotree/efi/boot/bootx64.efi
mv        tmp/grub/                                                   isotree/boot/
cp -av    tmp/*                                                       isotree/isolinux/
cp        /usr/lib/ISOLINUX/isolinux.bin                              isotree/isolinux/
cp        splash.png                                                  isotree/isolinux/splash.png  
cp        /usr/lib/syslinux/modules/bios/{ldlinux.c32,libcom32.c32,libutil.c32,vesamenu.c32} isotree/isolinux/

# Boot Menu for BIOS

cat > isotree/isolinux/txt.cfg << EOF
default install
label install
	menu label ^Install
	menu default
        kernel /installer/vmlinuz
        append initrd=/installer/initrd.gz file=/cdrom/preseed.cfg vga=788 --- quiet
EOF

# Boot Menu for UEFI

cat >> isotree/boot/grub/grub.cfg << EOF

menuentry 'Install' {
    set background_color=black
    linux    /installer/vmlinuz  vga=788 file=/cdrom/preseed.cfg --- quiet 
    initrd   /installer/initrd.gz
}
EOF

# 获取cdrom需要的deb包和udeb包

sudo ln -sv /usr/share/debootstrap/scripts/sid /usr/share/debootstrap/scripts/$codename

cd ${WORKDIR}/
mkdir tmp/rootfs
sudo debootstrap --no-check-gpg --download-only --include=$pkgs --components=main,non-free,contrib --arch=amd64 $codename tmp/rootfs $repo_url  
#cd tmp/rootfs/var/cache/apt/archives/
#sudo apt-get download `cat $pkgs`

wget ${repo_url}/dists/${codename}/main/debian-installer/binary-amd64/Packages.gz
zcat Packages.gz | grep Filename | awk  '{print $2}' > all_udeb.list
sed -i "s@^@$repo_url/@g" all_udeb.list  
mkdir -pv tmp/udeb/ && wget -i all_udeb.list -P tmp/udeb/

cd isotree/ && mkdir conf
cat > conf/distributions << EOF
Codename: $codename 
Description: cdrom intra repository
Architectures: i386 amd64
Components: main contrib non-free
UDebComponents: main
Contents: .gz
Suite: stable
EOF

reprepro includedeb $codename ../tmp/rootfs/var/cache/apt/archives/*.deb
reprepro includeudeb $codename ../tmp/udeb/*.udeb

echo $volid > .disk/info
find . -type f | grep -v -e ^\./\.disk -e ^\./dists | xargs md5sum >> md5sum.txt

#生成最终定制版本的ISO

cd ${WORKDIR}/
xorriso -as mkisofs -r -V "$volid"                                                                           \
    -J -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin                                                      \
    -J -joliet-long                                                                                       \
    -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot                                           \
    -boot-load-size 4 -boot-info-table -eltorito-alt-boot                                                 \
    -e boot/grub/efi.img -no-emul-boot -isohybrid-gpt-basdat -isohybrid-apm-hfsplus isotree/              \
    -o $isoname.iso
