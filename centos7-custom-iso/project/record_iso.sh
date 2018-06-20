#!/bin/sh
ISO=$1
xorrecord -v dev=/dev/sr0 speed=8 fs=8m -waiti -multi --grow_overwriteable_iso -eject padsize=300k $ISO
