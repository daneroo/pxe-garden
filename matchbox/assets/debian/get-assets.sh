# Create a directory for Debian assets
mkdir -p /var/lib/matchbox/assets/debian

# Download the kernel for Debian 11 (Bullseye)
wget -O /var/lib/matchbox/assets/debian/bullseye-linux http://ftp.debian.org/debian/dists/bullseye/main/installer-amd64/current/images/netboot/debian-installer/amd64/linux
# Download the initrd for Debian 11 (Bullseye)
wget -O /var/lib/matchbox/assets/debian/bullseye-initrd.gz http://ftp.debian.org/debian/dists/bullseye/main/installer-amd64/current/images/netboot/debian-installer/amd64/initrd.gz

# # Download the kernel (Stable)
# wget -O /var/lib/matchbox/assets/debian/linux http://ftp.debian.org/debian/dists/stable/main/installer-amd64/current/images/netboot/debian-installer/amd64/linux
# # Download the initrd (Stable)
# wget -O /var/lib/matchbox/assets/debian/initrd.gz http://ftp.debian.org/debian/dists/stable/main/installer-amd64/current/images/netboot/debian-installer/amd64/initrd.gz
