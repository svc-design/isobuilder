#!/bin/bash

number=`cat db/count`
count=$[ $number + 1]
echo ${count} > db/count
export BuildID="$(date +%Y%m%d)-B${count}"
export ProduceName=$1
export ReleaseID=$2

function do_clean
{
    rm -rvf ./iso-temp/
    rm -f   ./*.log
}

do_clean
yum clean all && yum update
lorax -p "${ProduceName}" -v ${ReleaseID} -r ${ReleaseID} --isfinal -s https://mirrors.tuna.tsinghua.edu.cn/centos/7.4.1708/os/x86_64/ ./iso-temp/

mkdir -pv iso-temp/Packages/  
yumdownloader --archlist=x86_64 --destdir=iso-temp/Packages/ `cat project/core.list`
rm -rvf iso-temp/Packages/*.i686.rpm
cd iso-temp/ && createrepo -g ../project/minimal-x86_64-comps.xml . && cd ../

genisoimage -U -r -v -T -J -joliet-long                                      \
            -V ${ProduceName} -A ${ProduceName} -volset ${ProduceName}	     \
            -c isolinux/boot.cat    -b isolinux/isolinux.bin                 \
            -no-emul-boot -boot-load-size 4 -boot-info-table                 \
            -eltorito-alt-boot -e images/efiboot.img -no-emul-boot           \
            -o ../centos7-custom-${ReleaseID}-${BuildID}.iso \
	    iso-temp                                                     
implantisomd5 ../centos7-custom-${ReleaseID}-${BuildID}.iso
do_clean
