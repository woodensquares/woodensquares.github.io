+++
type = "post"
title = "A bare-bones Debian installation"
description = ""
tags = [
    "debian",
    "linux",
]
date = "2016-01-01T12:28:00-08:00"
categories = [
    "Debian",
]
shorttitle = "A basic installation"
modified = "2017-12-03"
changelog = [ 
    "Initial release - 2016-01-01",
    "Typo - 2017-11-22",
    "Debian stretch - 2017-11-27",
    "Install aptitude earlier, use_lvmetad - 2017-11-28",
    "New highlighting for commands - 2017-12-03",
    "Debian stretch again - 2018-06-21",
    "Move to the new series of posts - 2023-01-06",
]
+++

## IMPORTANT

If you are looking for more up-to-date instructions targeting the current,
as of this writing, Debian Bullseye release, please follow the instructions
[in the updated guide]({{< ref"dont-fear-part-1.md" >}}) however note that
those instructions do not focus on VirtualBox/pfSense, so if you are interested
in that kind of set-up after having your Debian system up and running you can
come back to this series [at the pfSense installation step]({{< ref"pfsense-installation.md" >}})

<hr>

The following instructions assume that the installation will be of the
stable version of debian in a bare-metal configuration using legacy boot
for maximum compatibility. If a dual/multi-boot setup is required, you
might want to follow a different guide to set up your partitions and
continue from [the installation instructions after the partitioning
step](#formatting).

The installation instructions have been written when Debian Jessie was the
current stable release, they have also been followed for Debian Stretch, and
they might also work for later releases, [let me know]({{< ref
"about.md" >}}) if that is the case and you are installing some other Debian
release using them.

**Note for the remainder of this document jessie and jessie-backports will be
used for the apt/aptitude lines, if you wanted to install stretch, you would
simply change them to stretch/stretch-backports.**

Command output will not be displayed in the pseudo-terminal text screens below
unless relevant, you can also see an ascii video of an actual installation
following these instructions (on Debian Stretch) in [the first post of the
series about installing Xen/Kubernetes]({{< ref "xen-1.md#part-1" >}}).

Prerequisites
-------------

### Boot media

In order to install debian using debootstrap, most LiveCD linux
distributions can be used: the following assume booting from a Debian
installation disk, which means a couple of extra steps are required to
get the packages needed to complete the installation.

### Boot environment

After selecting 'Live (amd64)' in the Debian boot disk, login with
**user / live** as the username and password and **sudo su -** to get
root.

The best Debian mirror should be put it in */etc/apt/sources.list* to
speed up the installation, this can be done by using *netselect-apt*,
note this step would not be applicable if this is done as part of the
[VM installation part of the
guide]({{< ref "debian-installation-part-3.md#noapt" >}}), in that case
*sources.list* should contain the mirror that was selected during the
bare-metal installation and allowed in the pfSense rules.

{{< terminal title="Live CD" >}}
{{< terminal-command user="user" host="livecd" path="~" >}}
sudo -i
{{< /terminal-command >}} 
{{< terminal-command user="root" host="livecd" path="~" >}}
apt-get update
{{< /terminal-command >}} 
{{< terminal-comment >}} 
Note aptitude might already be included in your live CD
{{< /terminal-comment >}} 
{{< terminal-command user="root" host="livecd" path="~" >}}
apt-get install aptitude
{{< /terminal-command >}} 

{{< terminal-command user="root" host="livecd" path="~" >}}
aptitude update
{{< /terminal-command >}} 

{{< terminal-command user="root" host="livecd" path="~" >}}
aptitude install netselect-apt
{{< /terminal-command >}} 

{{< terminal-comment >}} 
For Debian Jessie
{{< /terminal-comment >}} 
{{< terminal-command user="root" host="livecd" path="~" >}}
netselect-apt -n -o /etc/apt/sources.list
{{< /terminal-command >}} 

{{< terminal-comment >}} 
or for Debian Stretch
{{< /terminal-comment >}} 
{{< terminal-command user="root" host="livecd" path="~" >}}
netselect-apt -n -o /etc/apt/sources.list.d/base.list
{{< /terminal-command >}} 

{{< terminal-comment >}} 
Update after getting the new mirror
{{< /terminal-comment >}} 
{{< terminal-command user="root" host="livecd" path="~" >}}
apt-get update
{{< /terminal-command >}} 

{{< /terminal >}}

After setting up the mirror the extra packages we need to continue the
installation can be downloaded.

{{< terminal title="Live CD" >}}
{{< terminal-command user="root" host="livecd" path="~" >}}
aptitude install cryptsetup lvm2 parted debootstrap
{{< /terminal-command >}} 
{{< /terminal >}}

If you are installing in the console it would be useful to also install
**gpm** by adding it to the above line, which would automatically start it and
make it easier to paste the various UUIDs that will be used to set up
the disks. Let's now move on to partitioning and begin the actual
installation process.

Installation
------------

### Partitioning

This section will assume a Debian installation on the **first available
hard drive** (/dev/sda below), and that it is currently unformatted,

### Note that the following steps will completely wipe out any data that was on the hard drive, so please make very sure there is nothing on it currently that needs backing up

In order to make things safer I would also **strongly** suggest that any
other writable drive be disconnected from the system before starting the
installation process, to minimize the chances of finger slips causing
data loss.

If UEFI/GPT are not required, the partitioning is quite simple, 100% of
the disk will end up in a single partition:

{{< terminal title="Live CD" >}}
{{< terminal-command user="root" host="livecd" path="~" >}}
parted -s /dev/sda mklabel msdos
{{< /terminal-command >}}
{{< terminal-command user="root" host="livecd" path="~" >}}
parted -s /dev/sda mkpart primary 2048s 100%
{{< /terminal-command >}}
{{< /terminal >}}

UEFI set-ups can be fairly system dependent, I personally prefer to use
a standard boot to be able to boot easily on a different system in case
of emergencies without having to worry about UEFI compatibility. If an
UEFI installation is required in your environment, I would suggest
looking at these examples: [^1] and [^2].

A UEFI installation would be broadly similar, and mostly a matter of
creating an additional small fat32 partition before the encrypted
LUKS/LVM one, and setting up grub so that the UEFI boot files get put in
the right place for the system.

### Formatting

After the main partition to hold the system it has been created, it
needs formatting, for security reasons this will be LVM over LUKS with a
fully encrypted disk, including /boot.

The set up also has a separate /storage and /home, if you have different
partitioning needs (say, a separate /opt, or /usr/local), they will
impact the commands below. Note I am currently using only 2 gigs for
swap, as I don't expect to be swapping at all, 15 gigs for /, and the
rest for /home.

If this is a [VM
installation]({{< ref "debian-installation-part-3.md" >}}) instead I would
suggest having an even smaller swap partition, I use 256 megs, and a
single root filesystem spanning the whole drive instead of having a
separate home directory, to keep the .vdi disk size as low as possible.

The main Linux installation, which will be called Dom0 from now on, even
though this is not Xen, is not meant to be running very much software,
the vast majority of the disk space should be occupied by virtual
machines and their files, however the values below can be adjusted
depending on individual needs.

{{< terminal title="Live CD" >}}
{{< terminal-command user="root" host="livecd" path="~" >}}
cryptsetup luksFormat /dev/sda1
{{< /terminal-command >}}
{{< terminal-command user="root" host="livecd" path="~" >}}
cryptsetup luksOpen /dev/sda1 lvm
{{< /terminal-command >}}
{{< terminal-comment >}} 
Note that the LVM commands might give a warning about not being able to
connect to lvmetad, that message can be ignored.
{{< /terminal-comment >}} 
{{< terminal-command user="root" host="livecd" path="~" >}}
pvcreate /dev/mapper/lvm
{{< /terminal-command >}}
{{< terminal-command user="root" host="livecd" path="~" >}}
vgcreate dvg /dev/mapper/lvm
{{< /terminal-command >}}
{{< terminal-command user="root" host="livecd" path="~" >}}
lvcreate -L 2G dvg -n swap
{{< /terminal-command >}}
{{< terminal-command user="root" host="livecd" path="~" >}}
lvcreate -L 15G dvg -n root
{{< /terminal-command >}}
{{< terminal-command user="root" host="livecd" path="~" >}}
lvcreate -l +100%FREE dvg -n home
{{< /terminal-command >}}
{{< terminal-command user="root" host="livecd" path="~" >}}
mkswap -L swap /dev/mapper/dvg-swap
{{< /terminal-command >}}
{{< terminal-command user="root" host="livecd" path="~" >}}
mkfs.ext4 /dev/mapper/dvg-root
{{< /terminal-command >}}
{{< terminal-command user="root" host="livecd" path="~" >}}
mkfs.ext4 /dev/mapper/dvg-home
{{< /terminal-command >}}
{{< terminal-command user="root" host="livecd" path="~" >}}
mount /dev/mapper/dvg-root /mnt
{{< /terminal-command >}}
{{< terminal-command user="root" host="livecd" path="~" >}}
mkdir /mnt/home
{{< /terminal-command >}}
{{< terminal-command user="root" host="livecd" path="~" >}}
mount /dev/mapper/dvg-home /mnt/home
{{< /terminal-command >}}
{{< terminal-command user="root" host="livecd" path="~" >}}
swapon /dev/mapper/dvg-swap
{{< /terminal-command >}}
{{< /terminal >}}

### Bootstrapping

At this point there is a clean hard drive mounted under /mnt where the
debian system can be installed, in order to do that let's use
debootstrap asking for a Debian Jessie installation, which was the
current stable release when this blog post was first written:

{{< terminal title="Live CD" >}}
{{< terminal-command user="root" host="livecd" path="~" >}}
debootstrap --arch amd64 jessie /mnt/ http://your.fastest.mirror/debian
{{< /terminal-command >}}
{{< /terminal >}}

<div id="initial"></div>

### Initial configuration

After some time spent downloading and installing there will now be a
base Debian system installed on the partition mounted under /mnt, this
is not yet bootable or complete, so let's continue the configuration by
chrooting inside it

{{< terminal title="Live CD" >}}
{{< terminal-command user="root" host="livecd" path="~" >}}
cd /mnt
{{< /terminal-command >}}
{{< terminal-command user="root" host="livecd" path="/mnt" >}}
mount -t proc proc proc
{{< /terminal-command >}}
{{< terminal-command user="root" host="livecd" path="/mnt" >}}
LANG=C.UTF-8 chroot /mnt /bin/bash     
{{< /terminal-command >}}
{{< /terminal >}}

the location where apt will be downloading the packages from needs to be
set in this chroot as well, you can just reuse the site that was fastest
for you during the netselect task in [the boot environment
step](#boot-environment).

As much as Debian stable will be the base system, there are occasionally
updated packages that might be useful that are only available in other
releases, this post on serverfault [^3] has some comprehensive
instructions on how to set things up to allow packages to be installed
from other Debian releases if required.

I would however suggest to complete the system installation before
setting up the above, and for the time being to create a fairly minimal
*/etc/apt/sources.list* along these lines:

{{< highlight bnf >}}
# Stable packages
deb http://your.fastest.mirror/debian/ jessie main contrib non-free
deb-src http://your.fastest.mirror/debian/ jessie main contrib non-free

# Security updates
deb http://security.debian.org/ jessie/updates main contrib non-free

# Backports
deb http://your.fastest.backports.mirror/debian/ jessie-backports main contrib non-free
deb-src http://your.fastest.backports.mirror/debian/ jessie-backports main contrib non-free
{{< / highlight >}}

After the apt sources are set up it's time to install some packages
needed to complete the setup, **please make sure to skip the grub
configuration** when prompted to do so (select 'yes' when prompted to
continue the installation without configuring grub). Note I am choosing
amd64 for the image, to install a 64bit environment.

{{< terminal title="Live CD" >}}
{{< terminal-command user="root" host="chroot" path="~" >}}
apt-get update
{{< /terminal-command >}}
{{< terminal-comment >}} 
After adding the backports repository, you might want to upgrade any package
that is available there
{{< /terminal-comment >}} 
{{< terminal-command user="root" host="chroot" path="~" >}}
apt-get -t jessie-backports upgrade
{{< /terminal-command >}}
{{< terminal-command user="root" host="chroot" path="~" >}}
apt-get install aptitude
{{< /terminal-command >}}
{{< terminal-command user="root" host="chroot" path="~" >}}
aptitude -t jessie-backports install makedev lvm2 grub2 linux-image-amd64 cryptsetup dhcpcd5 git curl apt-file man-db
{{< /terminal-command >}}
{{< terminal-comment >}} 
Apt-file is quite useful when trying to track down say which package contains /usr/bin/something
{{< /terminal-comment >}} 
{{< terminal-command user="root" host="chroot" path="~" >}}
apt-file update
{{< /terminal-command >}}
{{< /terminal >}}

<div id="rootpassword"></div>

it is now time to set up the devices, after the root password is set up we
will *exit* chroot temporarily to mount some special devices, once back in we
are going to also stop gpm outside chroot (if needed) as it will be run inside
it instead.

{{< terminal title="Live CD" >}}
{{< terminal-command user="root" host="chroot" path="~" >}}
cd /dev
{{< /terminal-command >}}
{{< terminal-command user="root" host="chroot" path="/dev" >}}
MAKEDEV generic
{{< /terminal-command >}}
{{< terminal-comment >}}
You should choose a password for the root account now
{{< /terminal-comment >}}
{{< terminal-command user="root" host="chroot" path="/dev" >}}
passwd
{{< /terminal-command >}}
{{< terminal-command user="root" host="chroot" path="/dev" >}}
exit
{{< /terminal-command >}}
{{< terminal-command user="root" host="livecd" path="/mnt" >}}
cd /mnt/
{{< /terminal-command >}}
{{< terminal-command user="root" host="livecd" path="/mnt" >}}
mount -t sysfs sys sys/
{{< /terminal-command >}}
{{< terminal-command user="root" host="livecd" path="/mnt" >}}
mount -o bind /dev dev/
{{< /terminal-command >}}
{{< terminal-command user="root" host="livecd" path="/mnt" >}}
mount -t devpts pts dev/pts/
{{< /terminal-command >}}
{{< terminal-comment >}}
If you are running gpm
{{< /terminal-comment >}}
{{< terminal-command user="root" host="livecd" path="/mnt" >}}
systemctl stop gpm
{{< /terminal-command >}}
{{< terminal-command user="root" host="livecd" path="/mnt" >}}
Back in chroot now
{{< /terminal-command >}}
{{< terminal-command user="root" host="livecd" path="/mnt" >}}
LANG=C.UTF-8 chroot /mnt/ /bin/bash     
{{< /terminal-command >}}
{{< terminal-command user="root" host="chroot" path="~" >}}
apt-get install gpm
{{< /terminal-command >}}
{{< /terminal >}}

The filesystems now need to be added to */etc/fstab*, note the UUIDs
here are the UUIDs of the LVM partitions, not the physical partition
that contains them, so for example the / UUID is the UUID of the
*/dev/mapper/dvg-root* partition, which can be found out as usual by
running **blkid**

{{< terminal title="Live CD" >}}
{{< terminal-command user="root" host="chroot" path="~" >}}
blkid | grep dvg-
{{< /terminal-command >}}
{{< terminal-output >}}
/dev/mapper/dvg-swap: LABEL="swap" UUID="xxxxxxxxxx" TYPE="swap"
/dev/mapper/dvg-home: UUID="xxxxxxxxx" TYPE="ext4"
/dev/mapper/dvg-root: UUID="xxxxxxxxx" TYPE="ext4"
{{< /terminal-output >}}
{{< /terminal >}}

If copying and pasting the UUIDs please make sure that the UUID= lines
below do **not** have double quotes, blkid will show the values as
UUID="xxxx" but the below has to be UUID=xxxx without the quoting.

{{< terminal title="Live CD" >}}
{{< terminal-command user="root" host="chroot" path="~" >}}
cat /etc/fstab
{{< /terminal-command >}}
{{< terminal-output >}}
UUID=xxxxxxxxxxxx  /              ext4         defaults      0 1
UUID=xxxxxxxxxxxx  /home          ext4         nosuid,nodev  0 2
UUID=xxxxxxxxxxxx  none           swap         nosuid,nodev  0 0
/dev/sr0           /media/cdrom   udf,iso9660  user,noauto   0 0
{{< /terminal-output >}}
{{< /terminal >}}

<div id="encryption"></div>

### Encryption configuration

Normally, with an encrypted /boot one would need to enter their crypto
password twice every boot, once to unlock LUKS for grub, and again to
unlock LUKS to continue the boot. This is inconvenient for a home setup
and at the cost of having a boot key laying around in your filesystem it
can be bypassed.

As I have discussed [in this post]({{< ref "rationale.md" >}}) I am not
interested in defending against the scenario of an attacker first
compromising my online system and then actually physically stealing it,
so having a key on the disk is not an issue for me, because if one is
able to read the key it means the disk is already unlocked, so having
the key would not be any more useful to an attacker.

Given this let's create a keyfile that we can use for LUKS:

{{< terminal title="Live CD" >}}
{{< terminal-command user="root" host="chroot" path="~" >}}
dd bs=512 count=4 if=/dev/urandom of=/bootdata.bin
{{< /terminal-command >}}
{{< terminal-command user="root" host="chroot" path="~" >}}
cryptsetup luksAddKey /dev/sda1 /bootdata.bin
{{< /terminal-command >}}
{{< /terminal >}}

I have found this technique described in these two [^4] [^5] blog posts
by Pavel Kogan.

<div id="grub"></div>

### Grub setup

From now on we will be using UUIDs of the physical disk partitions, so
they can be identified by running **blkid** when needed and copy+pasted
them via gpm to avoid typing mistakes. 

{{< terminal title="Live CD" >}}
{{< terminal-command user="root" host="chroot" path="~" >}}
blkid | grep /dev/sda
{{< /terminal-command >}}
{{< terminal-output >}}
/dev/sda1: UUID="xxxxxxxxxx" TYPE="crypto_LUKS" PARTUUID="...."
{{< /terminal-output >}}
{{< /terminal >}}

For example here and in crypttab xxxxxxxxxxxxxx is the UUID of the physical /dev/sda1 partition

{{< terminal title="Live CD" >}}
{{< terminal-command user="root" host="chroot" path="~" >}}
vi /etc/default/grub
{{< /terminal-command >}}
{{< terminal-command user="root" host="chroot" path="~" >}}
cat /etc/default/grub
{{< /terminal-command >}}
{{< terminal-output >}}
GRUB_CMDLINE_LINUX="cryptdevice=/dev/disk/by-uuid/xxxxxxxxxxxxxxx:lvm"
GRUB_ENABLE_CRYPTODISK=y
{{< /terminal-output >}}
{{< /terminal >}}

The GRUB\_CMDLINE\_LINUX line is a replacement of the one already in the
file, the GRUB\_ENABLE\_CRYPTODISK line should be added. If this is an
SSD installation you should consider whether or not you'd like to enable
TRIM on your drives, note [^6] that there are security ramifications if
you do so. If you are ok with them you can add allow-discards to lvm, so
*xxxx:lvm:allow-discards* but you will also have to edit
**/etc/lvm/lvm.conf** and change the **issue\_discards** line from 0 to
1 as well as add *,discard* to the /etc/crypttab line discussed below if
you don't plan to run fstrim manually.

On stretch you also might want to edit **/etc/lvm/lvm.conf** and change the
use_lvmetad=1 line to use_lvmetad=0 to avoid messages about it displayed on
startup (for a basic lvm setup lvmetad does not seem necessary)

This as well as other optimizations are discussed in the Debian wiki
SSDOptimization page [^7]. Note also the different fstab options, I
don't suggest adding the commit=600 line as write endurance of modern
SSDs is quite high, however please do add *noatime* for faster
operation. I prefer not to mount with discard but just to run fstrim via
cron daily or weekly.

After all this we also need to set up our crypttab to be able to boot
from our device

{{< terminal title="Live CD" >}}
{{< terminal-command user="root" host="chroot" path="~" >}}
echo 'lvm UUID=xxxxxxxxxxxxxxx /bootdata.bin luks,keyscript=/bin/cat' >> /etc/crypttab
{{< /terminal-command >}}
{{< /terminal >}}

If TRIM is to be used on an SSD don't forget to add ,discard here to
these options. The keyfile will be copied to the boot environment by a
custom initramfs hook script that needs to be put in
**/etc/initramfs-tools/hooks/bootdata**

```bash
#!/bin/sh
cp /bootdata.bin "${DESTDIR}"
```

After creating this file initramfs can be set up

{{< terminal title="Live CD" >}}
{{< terminal-command user="root" host="chroot" path="~" >}}
chmod a+x /etc/initramfs-tools/hooks/bootdata
{{< /terminal-command >}}
{{< terminal-comment >}}
Note the update-initramfs command might tell you that you have some firmware
missing, in that case use apt-file to find out which package your firmware is
in, for example in my case it will tell me that I am missing rtl_nic firmware,
which means I should install the firmware-realtek package
{{< /terminal-comment >}}
{{< terminal-command user="root" host="chroot" path="~" >}}
update-initramfs -u -k all
{{< /terminal-command >}}
{{< terminal-command user="root" host="chroot" path="/tmp" >}}
cd /tmp
{{< /terminal-command >}}
{{< terminal-command user="root" host="chroot" path="/tmp" >}}
mkdir check-initramfs
{{< /terminal-command >}}
{{< terminal-command user="root" host="chroot" path="/tmp" >}}
cd check-initramfs
{{< /terminal-command >}}
{{< terminal-command user="root" host="chroot" path="/tmp/check-initramfs" >}}
zcat /boot/initrd.xxxxxxxx | cpio -i
{{< /terminal-command >}}
{{< terminal-command user="root" host="chroot" path="/tmp/check-initramfs" >}}
ls -la ./bootdata.bin
{{< /terminal-command >}}
{{< terminal-output >}}
-rw-r--r-- 1 root root 2048 XXX  X XX:XX ./bootdata.bin
{{< /terminal-output >}}
{{< terminal-command user="root" host="chroot" path="/tmp/check-initramfs" >}}
ls -la ./sbin/cryptsetup
{{< /terminal-command >}}
{{< terminal-output >}}
-rw-r--r-- 1 root root 2048 XXX  X XX:XX ./sbin/cryptsetup
{{< /terminal-output >}}
{{< terminal-command user="root" host="chroot" path="/tmp/check-initramfs" >}}
cd ..
{{< /terminal-command >}}
{{< terminal-command user="root" host="chroot" path="/tmp" >}}
rm -rf check-initramfs
{{< /terminal-command >}}
{{< /terminal >}}

at the step where *zcat | cpio* is being run, you need to check that the
initram image contains both **bootdata.bin** and **sbin/cryptsetup**, if
both are there the installation should be bootable.

<div id="misc"></div>

### Miscellaneous

If persistent network interface names are preferable, it's a good idea
to set that up now before the first boot, **/etc/default/grub** can be
edited and **net.ifnames=1** added to the CMDLINUX line.

If net.ifnames=1 is set after the first boot, it might be necessary to
remove **/etc/udev/rules.d/70-persistent-net.rules** to get it to work.

The PC speaker can also be easily silenced by creating a file named
**/etc/modprobe.d/pcspkr-blacklist.conf** which consists of only one
line **blacklist pcspkr**

<div id="finalsteps"></div>

### Final steps

The default timezone should now be adjusted to your location and dhcpcd
disabled, unless this is a VM installation, as on bare metal we will be
running without physical networking in Dom0 given that our networking
will run through the [virtual pfSense
installation]({{< ref "pfsense-installation.md" >}}).

{{< terminal title="Live CD" >}}
{{< terminal-command user="root" host="chroot" path="/tmp" >}}
cd /etc
{{< /terminal-command >}}
{{< terminal-command user="root" host="chroot" path="/etc" >}}
mv localtime localtime.utc ; ln -s /usr/share/zoneinfo/x/y localtime
{{< /terminal-command >}}
{{< terminal-command user="root" host="chroot" path="/etc" >}}
update-rc.d dhcpcd disable
{{< /terminal-command >}}
{{< /terminal >}}

choose a hostname

{{< terminal title="Live CD" >}}
{{< terminal-command user="root" host="chroot" path="/etc" >}}
echo andromeda > /etc/hostname
{{< /terminal-command >}}
{{< terminal-comment >}}
Also add your hostname at the end of the 127.0.0.1 line
{{< /terminal-comment >}}
{{< terminal-command user="root" host="chroot" path="/etc" >}}
vi /etc/hosts
{{< /terminal-command >}}
{{< /terminal >}}

make it so after booting messages are not cleared from your console,
this is optional but I prefer to leave the existing messages on the
screen in case there are issues that need debugging

{{< terminal title="Live CD" >}}
{{< terminal-command user="root" host="chroot" path="/etc" >}}
mkdir /etc/systemd/system/getty\@tty1.service.d/
{{< /terminal-command >}}
{{< terminal-command user="root" host="chroot" path="/etc" >}}
echo '[Service]' > /etc/systemd/system/getty\@tty1.service.d/override.conf
{{< /terminal-command >}}
{{< terminal-command user="root" host="chroot" path="/etc" >}}
echo 'TTYVTDisallocate=no' >> /etc/systemd/system/getty\@tty1.service.d/override.conf
{{< /terminal-command >}}
{{< /terminal >}}

install grub

{{< terminal title="Live CD" >}}
{{< terminal-command user="root" host="chroot" path="/etc" >}}
grub-mkconfig -o /boot/grub/grub.cfg
{{< /terminal-command >}}
{{< terminal-command user="root" host="chroot" path="/etc" >}}
grub-install /dev/sda
{{< /terminal-command >}}
{{< /terminal >}}

exit chroot and reboot

{{< terminal title="Live CD" >}}
{{< terminal-command user="root" host="chroot" path="/etc" >}}
exit
{{< /terminal-command >}}
{{< terminal-command user="root" host="livecd" path="/mnt" >}}
systemctl reboot
{{< /terminal-command >}}
{{< /terminal >}}

if everything was installed correctly you should now be able to enter
your LUKS password once and find yourself at the login prompt of your
Debian installation!

Note that when booting grub will try and fail to find your LVM volume
the first time around, so it will wait 3 seconds, try again and succeed:
I have not been able to find a way to silence this error message, if you
know how please [let me know](/pages/about.html).

Continue now to [the next part of the guide]({{< ref
"debian-installation-part-2.md" >}})

[^1]: [https://www.variantweb.net/blog/install-arch-linux-with-gpt-and-uefi/](https://www.variantweb.net/blog/install-arch-linux-with-gpt-and-uefi/)

[^2]: [https://wiki.archlinux.org/index.php/GRUB/EFI_examples](https://wiki.archlinux.org/index.php/GRUB/EFI_examples)

[^3]: [http://serverfault.com/questions/22414/how-can-i-run-debian-stable-but-install-some-packages-from-testing](http://serverfault.com/questions/22414/how-can-i-run-debian-stable-but-install-some-packages-from-testing)

[^4]: [http://www.pavelkogan.com/2014/05/23/luks-full-disk-encryption/](http://www.pavelkogan.com/2014/05/23/luks-full-disk-encryption/)

[^5]: [http://www.pavelkogan.com/2015/01/25/linux-mint-encryption/](http://www.pavelkogan.com/2015/01/25/linux-mint-encryption/)

[^6]: [http://asalor.blogspot.ca/2011/08/trim-dm-crypt-problems.html](http://asalor.blogspot.ca/2011/08/trim-dm-crypt-problems.html)

[^7]: [https://wiki.debian.org/SSDOptimization](https://wiki.debian.org/SSDOptimization)

