#!/bin/bash

cache="/var/cache/lxc/ubuntu"

arch=$(arch)
if [ "$arch" == "x86_64" ]; then
    arch=amd64
fi

if [ "$arch" == "i686" ]; then
    arch=i386
fi

if [ -e "$cache/rootfs-$arch" ]; then
	echo "Cache rootfs already exists!"
	exit 0
fi

chef_packages=ruby,rubygems1.8,ruby-dev,libopenssl-ruby,build-essential,wget,ssl-cert
packages=dialog,apt,apt-utils,resolvconf,iproute,inetutils-ping,dhcp3-client,ssh,lsb-release,wget,gpgv,gnupg,$chef_packages

# check the mini ubuntu was not already downloaded
mkdir -p "$cache/partial-$arch"
if [ $? -ne 0 ]; then
	echo "Failed to create '$cache/partial-$arch' directory"
	exit 1
fi

# download a mini ubuntu into a cache
echo "Downloading ubuntu minimal ..."
debootstrap --verbose --variant=minbase --components=main,universe --arch=$arch --include=$packages lucid $cache/partial-$arch
if [ $? -ne 0 ]; then
	echo "Failed to download the rootfs, aborting."
	exit 1
fi

mv "$cache/partial-$arch" "$cache/rootfs-$arch"
echo "Download complete."

# install chef
cat <<EOF > "$cache/rootfs-$arch/tmp/install-chef.sh"
echo "deb http://apt.opscode.com/ `lsb_release -cs`-0.10 main" | tee /etc/apt/sources.list.d/opscode.list

mkdir -p /etc/apt/trusted.gpg.d
gpg --keyserver keys.gnupg.net --recv-keys 83EF826A
gpg --export packages@opscode.com | tee /etc/apt/trusted.gpg.d/opscode-keyring.gpg > /dev/null
apt-get update
apt-get install ucf --force-yes -y
yes | apt-get install opscode-keyring --force-yes -y # permanent upgradeable keyring

export DEBIAN_FRONTEND=noninteractive
apt-get install chef --force-yes -qy
EOF
chroot "$cache/rootfs-$arch" bash /tmp/install-chef.sh

