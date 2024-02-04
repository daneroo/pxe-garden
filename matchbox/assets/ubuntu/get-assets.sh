# See https://ubuntu.com/download/server
# as root on the matchbox server
wget https://releases.ubuntu.com/22.04.3/ubuntu-22.04.3-live-server-amd64.

# Now extract the kernel and initrd from the ISO
mkdir /mnt/iso
mount -o loop ubuntu-22.04.3-live-server-amd64.iso /mnt/iso
cp /mnt/iso/casper/vmlinuz /var/lib/matchbox/assets/ubuntu/ubuntu-22.04.3-live-server-amd64-vmlinuz
cp /mnt/iso/casper/initrd /var/lib/matchbox/assets/ubuntu/ubuntu-22.04.3-live-server-amd64-initrd
umount /mnt/iso
rmdir /mnt/iso
