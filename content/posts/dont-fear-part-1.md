+++
type = "post"
title = "Don't fear the command line, bare metal"
description = ""
tags = [
    "debian",
]
date = "2025-04-27T14:31:11-06:00"
categories = [
    "Debian",
]
shorttitle = "DFTCL 1 - bare metal"
changelog = [ 
    "Initial release - 2025-04-27",
]
+++

{{< toc >}}

## Let's begin!

As discussed in [the initial post of this new series]({{< ref
"dont-fear-part-0.md" >}}) we will now start from scratch and install
a base debian system. This is going to be a similar post [to the previous pfSense series]({{< ref
"debian-installation-part-1.md" >}}) but updated for the current debian stable
distribution (bookworm at this time) and an EFI boot.

The following instructions assume that the installation will be of the
stable version of debian in a bare-metal configuration using EFI boot
as these days legacy booting is not really that useful anymore.

If a dual/multi-boot setup is required, you might want to follow a different guide 
to set up your partitions and continue from [the installation instructions after the partitioning
step](#installing-the-base-debian-distribution).

These installation instructions have been written when Debian Bookworm was the
current stable release, and they might also work for later releases, [let me know]({{< ref
"about.md" >}}) if that is the case and you are installing some other Debian
release using them.

## Prerequisites

### An x86 computer or VM with a clean disk

Goes without saying that if you want to follow a bare metal guide, you need
a bare computer (or VM). If you are installing on bare metal, before going
further I suggest you also do some minimal sanity testing of your hardware,
via something like [memtest86+](https://www.memtest.org/) (where you can get
badmem lines in case you have to exclude some bad memory) as well as by running
something like [stress-ng](https://github.com/ColinIanKing/stress-ng) from the
Debian LiveCD (you likely will have to install it via apt-get as usual).

### No secure boot

Although it is possible nowadays to install linux with secure boot turned on,
given this installation is meant as a development environment I do not find
the tradeoffs worth it, so I keep it off and the guide assumes as much.

### Boot media

In order to install debian using debootstrap, most LiveCD linux
distributions can be used: the following assume booting from a Debian
installation disk, which means a couple of extra steps are required to
get the packages needed to complete the installation.

To "*burn*" the Debian live CD just download the iso and 
**sudo cp livecd.iso /dev/sdX** where *sdX* is your USB disk. 

### Boot the live CD

After selecting 'Live (amd64)' in the Debian boot disk, login with
**user / live** as the username and password if using a text mode
live CD, otherwise just open a terminal either way and **sudo -i** to get
root and then update your apt

```terminal { title="Live CD" }
!!user!!livecd!!~!!sudo -i
!!root!!livecd!!~!!apt-get update
  Get:1 http://deb.debian.org/debian bookworm InRelease [116 kB]
  Get:2 http://deb.debian.org/debian bookworm/main amd64 Packages [8,183 kB]
  Get:3 http://deb.debian.org/debian bookworm/main Translation-en [6,240 kB]
  Get:4 http://deb.debian.org/debian bookworm/main amd64 DEP-11 Metadata [4,049 kB]
  Get:5 http://deb.debian.org/debian bookworm/main DEP-11 48x48 Icons [3,478 kB]                                                                                                                                                                            
  Get:6 http://deb.debian.org/debian bookworm/main DEP-11 64x64 Icons [7,315 kB]                                                                                                                                                                            
  Get:7 http://deb.debian.org/debian bookworm/main DEP-11 128x128 Icons [11.4 MB]                                                                                                                                                                           
  Fetched 40.8 MB in 19s (2,114 kB/s)                                                                                                                                                                                                                       
  Reading package lists... Done
!!root!!livecd!!~!!apt autoremove
  Reading package lists... Done
  Building dependency tree... Done
  Reading state information... Done
  The following packages will be REMOVED:
    libeatmydata1
  0 upgraded, 0 newly installed, 1 to remove and 0 not upgraded.
  After this operation, 44.0 kB disk space will be freed.
  Do you want to continue? [Y/n]
  (Reading database ... 287159 files and directories currently installed.)
  Removing libeatmydata1:amd64 (105-9) ...
  Processing triggers for libc-bin (2.31-13+deb11u5) ...
!!root!!livecd!!~!!
```

In general when installing a new computer I tend to work from my main
workstation, as it makes it easier to cut+paste and I have everything
configured the way I prefer it. If you want to do the same just install
**openssh-server** first after updating the APT sources and start it
via **systemctl start sshd.service** and then just ssh to your IP address
(easily found via running **ip addr**, *192.168.1.161* in the following
example).

```terminal { title="Live CD" }
!!root!!livecd!!~!!apt-get install -y openssh-server
  Reading package lists... Done
  Building dependency tree... Done
  Reading state information... Done
  The following additional packages will be installed:
    openssh-sftp-server
!.
  Created symlink /etc/systemd/system/multi-user.target.wants/ssh.service → /lib/systemd/system/ssh.service.
  /usr/sbin/policy-rc.d returned 101, not running 'start rescue-ssh.target'
  invoke-rc.d: policy-rc.d denied execution of start.
  Processing triggers for man-db (2.9.4-2) ...
!!root!!livecd!!~!!systemctl start sshd.service
!!root!!livecd!!~!!ip addr | grep inet
      inet 127.0.0.1/8 scope host lo
      inet 192.168.1.161/24 brd 192.168.1.255 scope global dynamic noprefixroute enp6s0
```

**NOTE** if you are using ssh to install, note that for some reason sometimes
NIC drivers these days appear to "sleep" the card if no traffic is detected
for a while, easiest fix is to just open a terminal and leave a ping to your
router IP running while you connect via ssh from your other workstation.

### Install some tools and set up APT

In order to install things we need a couple of extra programs not normally
present on the LiveCD, first of all let's find out our fastest Debian mirror
by using netselect.

```terminal { title="Live CD" }
!!root!!livecd!!~!!apt-get install -y netselect-apt debootstrap
  Reading package lists... Done
  Building dependency tree... Done
  Reading state information... Done
  The following additional packages will be installed:
    netselect wget arch-test
!.
  Setting up netselect (0.3.ds1-29) ...
  Setting up netselect-apt (0.3.ds1-29) ...
  Processing triggers for man-db (2.9.4-2) ...
  Processing triggers for install-info (6.7.0.dfsg.2-6) ...
!!root!!livecd!!~!!netselect-apt -n -o /etc/apt/sources.list
  Using distribution stable.
  Retrieving the list of mirrors from www.debian.org...
  
  --2023-02-04 22:18:17--  http://www.debian.org/mirror/mirrors_full
  Resolving www.debian.org (www.debian.org)... 128.31.0.62, 149.20.4.15, 2001:4f8:1:c::15, ...
  Connecting to www.debian.org (www.debian.org)|128.31.0.62|:80... connected.
  HTTP request sent, awaiting response... 302 Found
!.  
  Of the hosts tested we choose the fastest valid for http:
          http://yourmirror.net.net/debian/
  
  Writing /etc/apt/sources.list.
  /etc/apt/sources.list exists, moving to /etc/apt/sources.list.1675549114
  Done.
!!root!!livecd!!~!!vi /etc/apt/sources.list
!.
!!root!!livecd!!~!!cat /etc/apt/sources.list
  # Debian packages for stable
  deb http://yourmirror.net.net/debian/ stable main contrib non-free
  # Uncomment the deb-src line if you want 'apt-get source'
  # to work with most packages.
  # deb-src http://yourmirror.net.net/debian/ stable main contrib non-free
  
  # Security updates for stable
  deb http://security.debian.org/debian-security stable-security main contrib non-free
!!root!!livecd!!~!!apt-get update
  Hit:1 http://yourmirror.net.net/debian stable InRelease
  Get:2 http://security.debian.org/debian-security stable-security InRelease [48.4 kB]
  Get:3 http://security.debian.org/debian-security stable-security/main amd64 Packages [222 kB]
  Get:4 http://security.debian.org/debian-security stable-security/main Translation-en [145 kB]
  Get:5 http://security.debian.org/debian-security stable-security/non-free amd64 Packages [528 B]
  Get:6 http://security.debian.org/debian-security stable-security/non-free Translation-en [344 B]
!.
  Reading package lists... Done
!!root!!livecd!!~!!
```

note it seems necessary to have to edit manually the sources.list file after
netselect-apt writes it, as the repository line for debian security will
need updating to avoid an error like 
*E: The repository \'http://security.debian.org stable/updates Release\' does not have a Release file.*.

## Partition the disk

These days it is usually recommended to use UEFI as the installation scheme,
if you already have an EFI partition (dual booting maybe) do not delete it, but
assuming a completely empty disk let's set it up as follows, from now on we will
assume that **/dev/nvme0n1** is your target disk, it could be **/dev/sda** or
something else, just to be sure run **lsblk** before installing and also use
something like **smartctl -a /dev/nvme0n1** to confirm it is the right drive.

```terminal { title="Live CD" }
!!root!!livecd!!~!!lsblk
  NAME    MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
  loop0     7:0    0   2.8G  1 loop /usr/lib/live/mount/rootfs/filesystem.squashfs
  sda       8:0    1  14.3G  0 disk
  ├─sda1    8:1    1   3.4G  0 part /usr/lib/live/mount/medium
  └─sda2    8:2    1   4.9M  0 part
  nvme0n1 259:0    0 238.5G  0 disk
!!root!!livecd!!~!!smartctl -a /dev/nvme0n1
  smartctl 7.2 2020-12-30 r5155 [x86_64-linux-5.10.0-20-amd64] (local build)
  Copyright (C) 2002-20, Bruce Allen, Christian Franke, www.smartmontools.org
  
  === START OF INFORMATION SECTION ===
  Model Number:                       KBG30ZMV256G TOSHIBA
!.
  Error Information (NVMe Log 0x01, 16 of 64 entries)
  No Errors Logged
!!root!!livecd!!~!!apt-get install cryptsetup lvm2 parted debootstrap
  Reading package lists... Done
  Building dependency tree... Done
  Reading state information... Done
  cryptsetup is already the newest version (2:2.3.7-1+deb11u1).
  cryptsetup set to manually installed.
  lvm2 is already the newest version (2.03.11-2.1).
  lvm2 set to manually installed.
  parted is already the newest version (3.4-1).
  parted set to manually installed.
!.
  Setting up debootstrap (1.0.123+deb11u1) ...
  Setting up arch-test (0.17-1) ...
  Processing triggers for man-db (2.9.4-2) ...
!!root!!livecd!!~!!
```

given the above we have an empty 250GB Toshiba NVME drive, which is where
we are going to install our debian system. These days LiveCDs already seem
to come with most of the tools we need, however let's make sure by asking
for the specific packages above.

### Create the EFI partition

As discussed before let's first create our EFI partition: size-wise I would 
recommend 1GB to have plenty of space just in case. Let's also have parted
figure out the alignment for the partition and format it.

```terminal { title="Live CD" }
!!root!!livecd!!~!!parted -s /dev/nvme0n1 mklabel gpt
!!root!!livecd!!~!!parted -s /dev/nvme0n1 -a optimal mkpart "'EFI system partition'" fat32 0% 1GiB
!!root!!livecd!!~!!parted -s /dev/nvme0n1 set 1 esp on
!!root!!livecd!!~!!mkfs.fat -F32 /dev/nvme0n1p1
!!root!!livecd!!~!!parted -s /dev/nvme0n1 print
  Model: KBG30ZMV256G TOSHIBA (nvme)
  Disk /dev/nvme0n1: 256GB
  Sector size (logical/physical): 512B/512B
  Partition Table: gpt
  Disk Flags:
  
  Number  Start   End     Size    File system  Name                  Flags
   1      1049kB  1074MB  1073MB  fat          EFI system partition  boot, esp
!!root!!livecd!!~!!
```

### Create the encrypted LUKS partition

similarly we can create our main partition, which will contain our encrypted
linux installation: for the partition name I am just picking today's date

```terminal { title="Live CD" }
!!root!!livecd!!~!!parted -s /dev/nvme0n1 -a optimal mkpart "'20250527'" 1GB 100%
!!root!!livecd!!~!!parted -s /dev/nvme0n1 print
  Model: KBG30ZMV256G TOSHIBA (nvme)
  Disk /dev/nvme0n1: 256GB
  Sector size (logical/physical): 512B/512B
  Partition Table: gpt
  Disk Flags:
  
  Number  Start   End     Size    File system  Name                  Flags
   1      1049kB  1074MB  1073MB  fat32        EFI system partition  boot, esp
   2      1074MB  256GB   255GB                20220204
!!root!!livecd!!~!!
```

at this time theoretically grub should be able to deal with LUKS2 partitions,
however just to be on the safe side let's use LUKS1. If you prefer LUKS2 of course
feel free to change the line below

```terminal { title="Live CD" }
!!root!!livecd!!~!!cryptsetup --type luks1 luksFormat /dev/nvme0n1p2
  
  WARNING!
  ========
  This will overwrite data on /dev/nvme0n1p2 irrevocably.
  
  Are you sure? (Type 'yes' in capital letters): YES
  Enter passphrase for /dev/nvme0n1p2:
  Verify passphrase:
!!root!!livecd!!~!!cryptsetup luksDump /dev/nvme0n1p2
  LUKS header information for /dev/nvme0n1p2
  
  Version:       	1
  Cipher name:   	aes
  Cipher mode:   	xts-plain64
  Hash spec:     	sha256
  Payload offset:	4096
  MK bits:       	512
  MK digest:     	xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx
  MK salt:       	xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx
                 	xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx
  MK iterations: 	356173
  UUID:          	64e4ea55-6e92-4b60-9163-d34ec98302b6
  
  Key Slot 0: ENABLED
  	Iterations:         	5737760
  	Salt:               	xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx
  	                      	xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx
  	Key material offset:	8
  	AF stripes:            	4000
  Key Slot 1: DISABLED
  Key Slot 2: DISABLED
  Key Slot 3: DISABLED
  Key Slot 4: DISABLED
  Key Slot 5: DISABLED
  Key Slot 6: DISABLED
  Key Slot 7: DISABLED
!!root!!livecd!!~!!
```

### Changing the LUKS password

If you ever want to change the password afterwards, you can do so as follows, first
of all identify which slot the password is in

```terminal { title="Live CD" }
!!root!!livecd!!~!!cryptsetup --verbose open --test-passphrase /dev/nvme0n1p2
  Enter passphrase for /dev/nvme0n1p2: 
  Key slot 0 unlocked.
  Command successful.
!!root!!livecd!!~!!
```

in the above case it is slot 0, so let's change it

```terminal { title="Live CD" }
!!root!!livecd!!~!!cryptsetup luksChangeKey /dev/nvme0n1p2 -S 0
  Enter passphrase to be changed: 
  Enter new passphrase: 
  Verify passphrase: 
!!root!!livecd!!~!!
```

you can now test it again to make sure it was changed correctly by re-entering the
test-passphrase command.

### Create the LVM group and volume

Now we have an encrypted LUKS volume, let's create an LVM group on top of it, using
some shell variables to make things easier (I usually create the volume with today's date
included to avoid conflicts if I have to mount them on a different linux box)

In general I create a super small swap partition just to have it, I have enough RAM
not to use it normally, and for root/home it really depends: having a separate root
filesystem can make things easier if one wants to just reinstall, however it does
require some care as by default things like docker or NVidia's CUDA can put significant amount
of data in /var which can of course cause the root filesystem to become full very easily.

In general it is of course possible to change the location where some things are stored
(like docker) but anyways something to keep in mind. For this particular article I will
just keep things simple and not have a separate home partition but just have the root
filesystem use all of the available space (minus swap and the EFI partition already created)

```terminal { title="Live CD" }
!!root!!livecd!!~!!cryptsetup luksOpen /dev/nvme0n1p2 lvm
  Enter passphrase for /dev/nvme0n1p2:
!!root!!livecd!!~!!export VG=dvg20250527
!!root!!livecd!!~!!vgcreate $VG /dev/mapper/lvm
    Physical volume "/dev/mapper/lvm" successfully created.
    Volume group "dvg20250527" successfully created
!!root!!livecd!!~!!lvcreate -L 2G $VG -n swap
    Logical volume "swap" created.
!!root!!livecd!!~!!lvcreate -l +100%FREE $VG -n root
    Logical volume "root" created.
!!root!!livecd!!~!!lvscan
    ACTIVE            '/dev/dvg20250527/swap' [2.00 GiB] inherit
    ACTIVE            '/dev/dvg20250527/root' [<235.47 GiB] inherit
!!root!!livecd!!~!!mkfs.ext4 /dev/mapper/$VG-root
  mke2fs 1.46.2 (28-Feb-2021)
  Creating filesystem with 61726720 4k blocks and 15433728 inodes
  Filesystem UUID: f6b25a48-ec45-4e23-9864-d538580818a0
  Superblock backups stored on blocks:
  	32768, 98304, 163840, 229376, 294912, 819200, 884736, 1605632, 2654208,
  	4096000, 7962624, 11239424, 20480000, 23887872
  
  Allocating group tables: done
  Writing inode tables: done
  Creating journal (262144 blocks): done
  Writing superblocks and filesystem accounting information: done
  
!!root!!livecd!!~!!mkswap -L swap /dev/mapper/$VG-swap
  Setting up swapspace version 1, size = 2 GiB (2147479552 bytes)
  LABEL=swap, UUID=d25081ac-cdb4-4e86-970b-0a8dcd167a4e
!!root!!livecd!!~!!blkid
  /dev/sda1: BLOCK_SIZE="2048" UUID="2022-12-17-13-13-38-00" LABEL="d-live nf 11.6.0 kd amd64" TYPE="iso9660" PTUUID="66641822" PTTYPE="dos" PARTUUID="66641822-01"
  /dev/loop0: TYPE="squashfs"
  /dev/nvme0n1p1: UUID="F76C-BD6A" BLOCK_SIZE="512" TYPE="vfat" PARTLABEL="EFI system partition" PARTUUID="f286a6cf-db85-4dad-9386-ca94dff39456"
  /dev/nvme0n1p2: UUID="64e4ea55-6e92-4b60-9163-d34ec98302b6" TYPE="crypto_LUKS" PARTLABEL="20220204" PARTUUID="f72d465d-6d8f-42cd-bd57-4fdba711f4e7"
  /dev/sda2: SEC_TYPE="msdos" UUID="DEB0-0001" BLOCK_SIZE="512" TYPE="vfat" PARTUUID="66641822-02"
  /dev/mapper/lvm: UUID="M7eFLc-VGY7-tH1Y-4Sfi-TDwl-5MQl-cNNhua" TYPE="LVM2_member"
  /dev/mapper/dvg20250527-swap: LABEL="swap" UUID="d25081ac-cdb4-4e86-970b-0a8dcd167a4e" TYPE="swap"
  /dev/mapper/dvg20250527-root: UUID="f6b25a48-ec45-4e23-9864-d538580818a0" BLOCK_SIZE="4096" TYPE="ext4"
!!root!!livecd!!~!!
```

For the rest of the article note the IDs above, we will be using them
in various configuration files.

{{< table "table-striped table-wide" >}}
| UUID      | What is it for          |
|-----------|-------------------------|
| F76C-BD6A    | The EFI boot partition  |
| 64e4ea55-6e92-4b60-9163-d34ec98302b6 | The LUKS partition      |
| d25081ac-cdb4-4e86-970b-0a8dcd167a4e | The swap partition      |
| f6b25a48-ec45-4e23-9864-d538580818a0 | The ext4 root partition |
{{< /table >}}

## Installing the base debian distribution

Let's first mount our newly created root partition and bootstrap the current
debian stable distribution (bookworm) from the mirror we selected before (your
mirror will likely be different)

```terminal { title="Live CD" }
!!root!!livecd!!~!!mount /dev/mapper/$VG-root /mnt/
!!root!!livecd!!~!!cat /etc/apt/sources.list
  # Debian packages for stable
  deb http://yourmirror.net.net/debian/ stable main contrib non-free
  # Uncomment the deb-src line if you want 'apt-get source'
  # to work with most packages.
  # deb-src http://yourmirror.net.net/debian/ stable main contrib non-free
  
  # Security updates for stable
  deb http://security.debian.org/debian-security stable-security main contrib non-free
!!root!!livecd!!~!!debootstrap --arch amd64 bookworm /mnt/ http://yourmirror.net.net/debian/
  I: Target architecture can be executed
  I: Retrieving InRelease
  I: Checking Release signature
  I: Valid Release signature (key id A4285295FC7B1A81600062A9605C66F00D6C9793)
  I: Retrieving Packages
  I: Validating Packages
  I: Resolving dependencies of required packages...
  I: Resolving dependencies of base packages...
!.
  I: Configuring iproute2...
  I: Configuring isc-dhcp-client...
  I: Configuring ifupdown...
  I: Configuring tasksel-data...
  I: Configuring tasksel...
  I: Configuring libc-bin...
  I: Base system installed successfully.
!!root!!livecd!!~!!
```

You should now check if you can see your EFI variables, if not you want
to run **modprobe efivars**, if it is loaded this directory should have
various files

```terminal { title="Live CD" }
!!root!!livecd!!~!!ls -la /sys/firmware/efi/efivars/
  total 0
  drwxr-xr-x 2 root root    0 Feb  5 22:11 .
  drwxr-xr-x 6 root root    0 Feb  5 22:11 ..
  -rw-r--r-- 1 root root    6 Feb  5 22:11 ALC210CommandFlag-2960f2bb-4cd3-4392-b73d-00b26468ebf8
  -rw-r--r-- 1 root root   14 Feb  5 22:11 AmdAcpiVar-79941ecd-ed36-49d0-8124-e4c31ac75cd4
!.
  -rw-r--r-- 1 root root    8 Feb  5 22:11 WpBufAddr-cba83c4a-a5fc-48a8-b3a6-d33636166544
  -rw-r--r-- 1 root root   68 Feb  5 22:11 WriteOnceStatus-4b3082a3-80c6-4d7e-9cd0-583917265df1
!!root!!livecd!!~!!
```

let's now mount our various efi and device files inside our bootstrapped
partition so that we can execute commands we need there, and verify they are mounted

```terminal { title="Live CD" }
!!root!!livecd!!~!!for i in /dev /dev/pts /proc /sys /sys/firmware/efi/efivars /run; do mkdir -p /mnt$i; done
!!root!!livecd!!~!!for i in /dev /dev/pts /proc /sys /sys/firmware/efi/efivars /run; do mount -B $i /mnt$i; done
!!root!!livecd!!~!!mount | grep /mnt
  /dev/mapper/dvg20250527-root on /mnt type ext4 (rw,relatime)
  udev on /mnt/dev type devtmpfs (rw,nosuid,relatime,size=32521856k,nr_inodes=8130464,mode=755)
  devpts on /mnt/dev/pts type devpts (rw,nosuid,noexec,relatime,gid=5,mode=620,ptmxmode=000)
  proc on /mnt/proc type proc (rw,nosuid,nodev,noexec,relatime)
  sysfs on /mnt/sys type sysfs (rw,nosuid,nodev,noexec,relatime)
  efivarfs on /mnt/sys/firmware/efi/efivars type efivarfs (rw,nosuid,nodev,noexec,relatime)
  tmpfs on /mnt/run type tmpfs (rw,nosuid,nodev,noexec,relatime,size=6519956k,mode=755)
!!root!!livecd!!~!!
```

## New system setup

### apt

From now on note the prompt for where the commands are run, livecd is our booted LiveCD
environment, while chroot is the new Debian environment that we are in the process of 
installing:

```terminal { title="Live CD" }
!!root!!livecd!!~!!LANG=C.UTF-8 chroot /mnt /bin/bash 
!!root!!chroot!!/!! 
```

the chroot at this point contains a bare Debian installation, first of all
we should decide what our strategy should be for our Debian packages, I personally
like the setup discussed in [^1] where by default apt will install backports,
but where it is actually possible to install packages from testing (or even unstable)
very easily.

Given this we will create the following files in **/etc/apt**/ as well as make
**/etc/apt/sources.list** an empty file. Note change **yourmirror**
below to your fastest mirror hostname as you found via netselect-apt above.

{{< table "table-striped table-wide" >}}
| File      | Contents          |
|------------------------------------------|---|
| /etc/apt/preferences.d/backports.pref    | <code>Package: *<br/>Pin: release n=bookworm-backports<br/>Pin-Priority: 900</code>  |
| /etc/apt/preferences.d/oldstable.pref    | <code>Package: *<br/>Pin: release n=bookworm<br/>Pin-Priority: 100</code>   |
| /etc/apt/preferences.d/testing.pref      | <code>Package: *<br/>Pin: release n=bookworm<br/>Pin-Priority: 400</code>   |
| /etc/apt/sources.list.d/backports.list   | <code>deb http://yourmirror.net.net/debian/ bookworm-backports main contrib non-free <br/>deb-src http://yourmirror.net.net/debian/ bookworm-backports main contrib non-free</code>  |
| /etc/apt/sources.list.d/fasttrack.list   | <code>deb https://fasttrack.debian.net/debian-fasttrack/ bookworm-fasttrack main contrib non-free<br/>deb https://fasttrack.debian.net/debian-fasttrack/ bookworm-backports-staging main contrib non-free</code>    |
| /etc/apt/sources.list.d/oldstable.list   | <code>deb http://yourmirror.net.net/debian/ bullseye main contrib non-free<br/>deb-src http://yourmirror.net.net/debian/ bullseye main contrib non-free</code>  |
| /etc/apt/sources.list.d/stable.list      | <code>deb http://yourmirror.net.net/debian/ bookworm main contrib non-free<br/>deb-src http://yourmirror.net.net/debian/ bookworm main contrib non-free<br/><br/>deb http://security.debian.org/debian-security bookworm-security main contrib non-free<br/>deb-src http://security.debian.org/debian-security bookworm-security main contrib non-free</code>  |
| /etc/apt/sources.list.d/testing.list     | <code>deb http://yourmirror.net.net/debian/ trixie main contrib non-free<br/>deb-src http://yourmirror.net.net/debian/ trixie main contrib non-free</code>  |
| /etc/apt/sources.list.d/updates.list     | <code>deb http://yourmirror.net.net/debian/ bookworm-updates main contrib non-free<br/>deb-src http://yourmirror.net.net/debian/ bookworm-updates main contrib non-free</code>  |
{{< /table >}}

after adding the files above you need to run the following commands

```terminal { title="Live CD" }
!!root!!chroot!!/!!apt-get update
!# you will get some errors about fasttrack
!!root!!chroot!!/!!apt-get install ca-certificates fasttrack-archive-keyring
!.
!!root!!chroot!!/!!apt-get update
!# now everything should update correctly
```

you can see what versions of a package are available by using apt-cache as follows 

```terminal { title="Live CD" }
!!root!!chroot!!/!!apt-cache policy openssh-server
  openssh-server:
    Installed: 1:9.2p1-2+deb12u2
    Candidate: 1:9.2p1-2+deb12u3
    Version table:
       1:9.9p1-3 400
          400 http://yourmirror.net.net/debian trixie/main amd64 Packages
       1:9.2p1-2+deb12u3 500
          500 http://yourmirror.net.net/debian bookworm/main amd64 Packages
          500 http://security.debian.org/debian-security bookworm-security/main amd64 Packages
   *** 1:9.2p1-2+deb12u2 100
          100 /var/lib/dpkg/status
       1:8.4p1-5+deb11u3 100
          100 http://yourmirror.net.net/debian bullseye/main amd64 Packages
```

by default if we don't specify any options to apt, we will be getting the bookworm
version of this package, however we also have available a newer version from testing as
well as older version from bookworm. Note that installing packages from different
distributions might or might not work, depending on their dependencies, however it often
can work, and if not given that we have **deb-src** lines in the sources, you can always
download the source and try to recompile it.

Now that we have backports as a higher priority than bookworm, let's see if anything from
our base installation can be upgraded and do so: this is also a test of the priorities above as if 
you get a tons of packages listed here there is likely something wrong with the apt configuration.
We also need to add cryptsetup to complete the installation 

```terminal { title="Live CD" }
!!root!!chroot!!/!!apt list --upgradable
  Listing... Done
!.
!!root!!chroot!!/!!apt-get upgrade
  Reading package lists... Done
  Building dependency tree... Done
  Reading state information... Done
  Calculating upgrade... Done
  The following packages have been kept back:
    libbpf0 libsystemd0 systemd
  The following packages will be upgraded:
    e2fsprogs init init-system-helpers iproute2 less libcom-err2 libelf1 libext2fs2 libss2 libssl1.1 libudev1 logsave rsyslog systemd-sysv udev
  15 upgraded, 0 newly installed, 0 to remove and 3 not upgraded.
  Need to get 6626 kB of archives.
  After this operation, 1969 kB of additional disk space will be used.
  Do you want to continue? [Y/n]
!.
  Installing new version of config file /etc/iproute2/rt_protos ...
  Setting up e2fsprogs (1.46.6-1~bpo11+1) ...
  Installing new version of config file /etc/mke2fs.conf ...
  Running in chroot, ignoring command 'daemon-reload'
  Running in chroot, ignoring command 'is-active'
  Running in chroot, ignoring command 'is-active'
  Running in chroot, ignoring command 'is-active'
  Running in chroot, ignoring command 'restart'
  Processing triggers for libc-bin (2.31-13+deb11u5) ...
!!root!!chroot!!/!!apt-get install -y cryptsetup cryptsetup-initramfs
  Reading package lists... Done
  Building dependency tree... Done
  Reading state information... Done
  The following additional packages will be installed:
    cryptsetup-bin busybox console-setup console-setup-linux initramfs-tools initramfs-tools-core kbd keyboard-configuration klibc-utils libklibc linux-base xkb-data zstd
  Suggested packages:
    cryptsetup-initramfs dosfstools keyutils
  The following NEW packages will be installed:
    cryptsetup cryptsetup-bin
!.
!!root!!chroot!!/!!
```
### fstab and friends

Let's quickly create our **/etc/fstab** file so that the system operates properly,
you can get the needed uuids by using *blkid* as follows, the important ones are
your */dev/mapper/dvg-* entries, as well as the *EFI system partition* one

```terminal { title="Live CD" }
!!root!!chroot!!/!!blkid
  /dev/sda1: BLOCK_SIZE="2048" UUID="2022-12-17-13-13-38-00" LABEL="d-live nf 11.6.0 kd amd64" TYPE="iso9660" PTUUID="66641822" PTTYPE="dos" PARTUUID="66641822-01"
  /dev/loop0: TYPE="squashfs"
  /dev/nvme0n1p1: UUID="F76C-BD6A" BLOCK_SIZE="512" TYPE="vfat" PARTLABEL="EFI system partition" PARTUUID="f286a6cf-db85-4dad-9386-ca94dff39456"
  /dev/nvme0n1p2: UUID="64e4ea55-6e92-4b60-9163-d34ec98302b6" TYPE="crypto_LUKS" PARTLABEL="20220204" PARTUUID="f72d465d-6d8f-42cd-bd57-4fdba711f4e7"
  /dev/sda2: SEC_TYPE="msdos" UUID="DEB0-0001" BLOCK_SIZE="512" TYPE="vfat" PARTUUID="66641822-02"
  /dev/mapper/lvm: UUID="M7eFLc-VGY7-tH1Y-4Sfi-TDwl-5MQl-cNNhua" TYPE="LVM2_member"
  /dev/mapper/dvg20250527-swap: LABEL="swap" UUID="d25081ac-cdb4-4e86-970b-0a8dcd167a4e" TYPE="swap"
  /dev/mapper/dvg20250527-root: UUID="f6b25a48-ec45-4e23-9864-d538580818a0" BLOCK_SIZE="4096" TYPE="ext4"
!!root!!chroot!!/!!vi /etc/fstab
!.
!!root!!chroot!!/!!cat /etc/fstab
  UUID=F76C-BD6A   /boot/efi	vfat	defaults	0	0
  UUID=f6b25a48-ec45-4e23-9864-d538580818a0	/	ext4	defaults,relatime	0	1
  UUID=d25081ac-cdb4-4e86-970b-0a8dcd167a4e	none	swap	defaults	0	0
!!root!!chroot!!/!!
```

in this installation we will have an encrypted */boot* directory as well, so we need a way
for grub to unlock your root disk after booting: this can be done by having a keyfile on disk
that will be used by the boot process, so the flow will be on boot you will enter the crypto
password set above, which will unlock the disk and allow grub to boot, and then grub will use
the keyfile to unlock the root partition and continue.

```terminal { title="Live CD" }
!!root!!chroot!!/!!mkdir -m0700 /etc/keys
!!root!!chroot!!/!!( umask 0077 && dd if=/dev/urandom bs=1 count=64 of=/etc/keys/main.key conv=excl,fsync )
  64+0 records in
  64+0 records out
  64 bytes copied, 0.00447848 s, 14.3 kB/s
!!root!!chroot!!/!!cryptsetup luksAddKey /dev/nvme0n1p2 /etc/keys/main.key
  Enter any existing passphrase: 
!!root!!livecd!!~!!cryptsetup luksDump /dev/nvme0n1p2
  LUKS header information for /dev/nvme0n1p2
  
  Version:       	1
  Cipher name:   	aes
  Cipher mode:   	xts-plain64
  Hash spec:     	sha256
  Payload offset:	4096
  MK bits:       	512
  MK digest:     	xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx
  MK salt:       	xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx
                 	xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx
  MK iterations: 	356173
  UUID:          	64e4ea55-6e92-4b60-9163-d34ec98302b6
  
  Key Slot 0: ENABLED
  	Iterations:         	5737760
  	Salt:               	xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx
  	                      	xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx
  	Key material offset:	8
  	AF stripes:            	4000
  Key Slot 1: ENABLED
  	Iterations:         	5652700
  	Salt:               	xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx
  	                      	xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx
  	Key material offset:	8
  	AF stripes:            	4000
  Key Slot 2: DISABLED
  Key Slot 3: DISABLED
  Key Slot 4: DISABLED
  Key Slot 5: DISABLED
  Key Slot 6: DISABLED
  Key Slot 7: DISABLED
!!root!!livecd!!~!!
```

as you can see now our LUKS password has two ways to be opened, one by the 
password we created originally in slot 0, and one with the keyfile we just
created in slot 1. Let's now add a reference to this file to crypttab and initramfs
(and make sure the generated initramfs is not world readable!).

```terminal { title="Live CD" }
!!root!!chroot!!/!!blkid | grep crypto_LUKS
  /dev/nvme0n1p2: UUID="64e4ea55-6e92-4b60-9163-d34ec98302b6" TYPE="crypto_LUKS" PARTLABEL="20220204" PARTUUID="f72d465d-6d8f-42cd-bd57-4fdba711f4e7"
!!root!!livecd!!~!!vi /etc/crypttab
!.
!!root!!livecd!!~!!cat /etc/crypttab
  lvm UUID=64e4ea55-6e92-4b60-9163-d34ec98302b6 /etc/keys/main.key luks,discard,key-slot=1
!!root!!livecd!!~!!echo "KEYFILE_PATTERN=\"/etc/keys/*.key\"" >>/etc/cryptsetup-initramfs/conf-hook
!!root!!livecd!!~!!echo UMASK=0077 >>/etc/initramfs-tools/initramfs.conf
!!root!!livecd!!~!!
```

as a backup you could print the **main.key** file (it is quite small) and if you ever
forget your password you can use this to open your partition from a LiveCD or other
environment. To print it just do something like **xxd /etc/keys/main.key** and
then you can recreate it via simply **xxd -r the-copy.txt**

Note at this point it would probably also be a good idea to edit **/etc/lvm/lvm.conf** 
and change the **issue_discards=0** line to **issue_discards=1** so that *TRIM* will
work for your SSD. Note that there are security ramifications if
you use TRIM as discussed here [^6].

I have originally found the LUKS keyfile technique described in these two [^4] [^5] blog posts
by Pavel Kogan some years back.

### grub

After the apt sources are set up it's time to install some packages
needed to complete the setup, note I am choosing amd64 for the image, 
to install a 64bit environment, you will also likely be asked what keyboard
and character set layout to use.

```terminal { title="Live CD" }
!!root!!chroot!!/!!apt-get install -y lvm2 grub-efi linux-image-amd64 dhcpcd5 git curl apt-file efibootmgr binutils
!.
  Processing triggers for libc-bin (2.31-13+deb11u5) ...
  Processing triggers for initramfs-tools (0.140) ...
  update-initramfs: Generating /boot/initrd.img-6.0.0-0.deb11.6-amd64
  cryptsetup: WARNING: target 'lvm' not found in /etc/crypttab
  Processing triggers for shim-signed:amd64 (1.38+15.4-7) ...
!!root!!chroot!!/!!apt-file update
!.
!!root!!chroot!!/!!
```

if you get some warnings telling you some firmware is missing, you can use apt-file
to figure out which package provides it, typically it will be network interface drivers,
so if you are missing */lib/some/directory/some/firmware.fw* just run **apt-file search /lib/some/directory/some/firmware.fw**
and install the relevant package before continuing (you will need to *apt-get install -y apt-file; apt-file update* for that to work)

It is also a good idea to just run **lsmod** on your LiveCD and see what modules are loaded,
especially if you are running a "non-free" LiveCD with firmware available. For example for my
AMD motherboard + CPU combination I have to install the following packages to have my WIFI
card working, as well as my AMD GPU be supported: **firmware-misc-nonfree firmware-linux firmware-iwlwifi firmware-amd-graphics**

Note at this point the various installed grub packages will have the signed shims
so that it is possible to use grub with secure boot on, the problem with this, which might
not be a problem for you of course, is that it will put all the EFI files in a **debian** directory,
which means that you will NOT be able to dual boot two separate debian distributions in the same EFI
volume. This is not acceptable to me, so since I said at the beginning I will keep secure boot disabled,
let's remove all the various shims so we can install the normal grub and not the signed shim instead.

Note we need to pass **--allow-remove-essential** to be able to remove the signed shim. 

```terminal { title="Live CD" }
!!root!!chroot!!/!!apt-get remove -y shim-helpers-amd64-signed shim-signed shim-signed-common shim-unsigned grub-efi-amd64-signed --allow-remove-essential
  Reading package lists... Done
  Building dependency tree... Done
  Reading state information... Done
  The following package was automatically installed and is no longer required:
    mokutil
  Use 'apt autoremove' to remove it.
  The following packages will be REMOVED:
    grub-efi-amd64-signed shim-helpers-amd64-signed shim-signed shim-signed-common shim-unsigned
  0 upgraded, 0 newly installed, 5 to remove and 3 not upgraded.
  After this operation, 19.5 MB disk space will be freed.
  (Reading database ... 21265 files and directories currently installed.)
  Removing grub-efi-amd64-signed (1+2.06+3~deb11u5) ...
  Removing shim-signed:amd64 (1.38+15.4-7) ...
  No DKMS packages installed: not changing Secure Boot validation state.
  Removing shim-helpers-amd64-signed (1+15.4+7) ...
  Removing shim-signed-common (1.38+15.4-7) ...
  Removing shim-unsigned (15.4-7) ...
!!root!!chroot!!/!!apt-get -y autoremove
  Reading package lists... Done
  Building dependency tree... Done
  Reading state information... Done
  The following packages will be REMOVED:
    mokutil
  0 upgraded, 0 newly installed, 1 to remove and 3 not upgraded.
  After this operation, 81.9 kB disk space will be freed.
  (Reading database ... 21232 files and directories currently installed.)
  Removing mokutil (0.6.0-2~deb11u1) ...
!!root!!chroot!!/!!
```

we can now edit our grub configuration where we will tell grub which disk to use
and other options: you can look at grub's manpage to figure out anything else
you need.

```terminal { title="Live CD" }
!!root!!chroot!!/!!blkid | grep crypto_LUKS
  /dev/nvme0n1p2: UUID="64e4ea55-6e92-4b60-9163-d34ec98302b6" TYPE="crypto_LUKS" PARTLABEL="20220204" PARTUUID="f72d465d-6d8f-42cd-bd57-4fdba711f4e7"
!!root!!chroot!!/!!vi /etc/default/grub
!.
!!root!!chroot!!/!!cat /etc/default/grub | grep -v \#
  GRUB_DEFAULT=0
  GRUB_TIMEOUT=5
  GRUB_DISTRIBUTOR=`lsb_release -i -s 2> /dev/null || echo Debian`
  GRUB_CMDLINE_LINUX_DEFAULT="quiet"
!# The above are defaults, update the below as needed  
  GRUB_CMDLINE_LINUX="loglevel=6 ipv6.disable=1 net.ifnames=1 cryptdevice=/dev/disk/by-uuid/64e4ea55-6e92-4b60-9163-d34ec98302b6 systemd.unified_cgroup_hierarchy=0"
!# an example of a custom parameter
  GRUB_BADRAM="0x0000000054b3e148,0xffffffffffffff8"
!# Add this so that we can boot our encrypted disk
  GRUB_ENABLE_CRYPTODISK=y
!# Optionally choose a resolution that works for you
  GRUB_GFXMODE=1920x1080x32,1024x768x32,auto
  GRUB_GFXPAYLOAD_LINUX=keep
!!root!!chroot!!/!!
```

This is optional but with an EFI boot we can add a couple more menu entries
to grub in case you quickly need to do something

```terminal { title="Live CD" }
!!root!!chroot!!/!!vi /etc/grub.d/40_custom
!. 
!!root!!chroot!!/!!cat /etc/grub.d/40_custom 
  #!/bin/sh
  exec tail -n +3 $0
  # This file provides an easy way to add custom menu entries.  Simply type the
  # menu entries you want to add after this comment.  Be careful not to change
  # the 'exec tail' line above.
  
  menuentry "System shutdown" {
  	echo "System shutting down..."
  	halt
  }
  
  menuentry "System restart" {
  	echo "System rebooting..."
  	reboot
  }
  
  if [ ${grub_platform} == "efi" ]; then
  	menuentry 'UEFI Firmware Settings' --id 'uefi-firmware' {
  		fwsetup
  	}
  
  	menuentry "UEFI Shell" {
  		insmod fat
  		insmod chain
  		search --no-floppy --set=root --file /shellx64.efi
  		chainloader /shellx64.efi
  	}
  fi
```

we can now install grub to our disk (NOT to our partition) as follows, **main** in this
case will be the directory in the EFI boot partition where the debian bootloader will exist.

```terminal { title="Live CD" }
!!root!!chroot!!/!!mkdir /boot/efi
!!root!!chroot!!/!!mount /boot/efi
!!root!!chroot!!/!!grub-install --bootloader-id=main --no-uefi-secure-boot --target=x86_64-efi /dev/nvme0n1
  Installing for x86_64-efi platform.
  Installation finished. No error reported.
  root@debian:~# ls -la /boot/efi/EFI/main/
  total 248
  drwxr-xr-x 2 root root   4096 Feb 11 22:57 .
  drwxr-xr-x 3 root root   4096 Feb 11 22:57 ..
  -rwxr-xr-x 1 root root 245760 Feb 11 22:57 grubx64.efi
!!root!!chroot!!/!!efibootmgr -v
  BootCurrent: 0001
  Timeout: 1 seconds
  BootOrder: 0000,0001,0002
  Boot0000* main	HD(1,GPT,f286a6cf-db85-4dad-9386-ca94dff39456,0x800,0x1ff800)/File(\EFI\main\grubx64.efi)
  Boot0001* UEFI:  USB	PciRoot(0x0)/Pci(0x8,0x1)/Pci(0x0,0x4)/USB(4,0)/CDROM(1,0x678,0x9d68)..BO
  Boot0002* UEFI:  USB, Partition 2	PciRoot(0x0)/Pci(0x8,0x1)/Pci(0x0,0x4)/USB(4,0)/HD(2,MBR,0x66641822,0x678,0x275a)..BO
!!root!!chroot!!/!!update-grub
  Generating grub configuration file ...
  Found linux image: /boot/vmlinuz-6.0.0-0.deb11.6-amd64
  Found initrd image: /boot/initrd.img-6.0.0-0.deb11.6-amd64
  Warning: os-prober will be executed to detect other bootable partitions.
  Its output will be used to detect bootable binaries on them and create new boot entries.
  grub-probe: error: cannot find a GRUB drive for /dev/sda1.  Check your device.map.
  Adding boot menu entry for UEFI Firmware Settings ...
  done
!!root!!chroot!!/!!
```

note the single **grubx64.efi** file there without any shims like **shimx64.efi** etc.
and also note it is correctly set in the EFI boot manager record. The sda1 error can be
ignored as it is the liveCD USB, you might have a similar error for a different device
depending how you booted it.

### WIFI packages

Note if you plan to use WIFI later on, you should install the relevant packages now,
otherwise you might end up with your clean base system with no networking and no way
to install them (without booting manually to your LiveCD and remounting your root
directory same as above, and chrooting into it again).

```terminal { title="Live CD" }
!!root!!chroot!!/!!apt-get install -y wireless-regdb wireless-tools wpasupplicant net-tools ifmetric
```

### final setup

Don't forget to change your root password otherwise you won't be able to login! Also
in order to continue the setup remotely we should install the ssh server, and create
a non privileged user. Having man pages available is also quite helpful so let's install
man-db as well.

```terminal { title="Live CD" }
!!root!!chroot!!/!!passwd
  New password:
  Retype new password:
  passwd: password updated successfully
!!root!!chroot!!/!!apt-get install -y openssh-server sudo man-db
  Reading package lists... Done
  Building dependency tree... Done
  Reading state information... Done
  The following additional packages will be installed:
!.
  Setting up libpam-systemd:amd64 (252.5-2~bpo11+1) ...
  Setting up dbus-user-session (1.12.24-0+deb11u1) ...
  Processing triggers for libc-bin (2.31-13+deb11u5) ...
!!root!!chroot!!/!!systemctl enable ssh.service
  Synchronizing state of ssh.service with SysV service script with /lib/systemd/systemd-sysv-install.
  Executing: /lib/systemd/systemd-sysv-install enable ssh
  Running in chroot, ignoring command 'daemon-reload'
  Running in chroot, ignoring command 'daemon-reload'
!!root!!chroot!!/!! addgroup --gid 1000 luser
  Adding group `luser' (GID 1000) ...
  Done.
!!root!!chroot!!/!!adduser --uid 1000 --gid 1000 luser
  Adding user `luser' ...
  Adding new user `luser' (1000) with group `luser' ...
  Creating home directory `/home/luser' ...
  Copying files from `/etc/skel' ...
  New password:
  Retype new password:
  passwd: password updated successfully
  Changing the user information for luser
  Enter the new value, or press ENTER for the default
  	Full Name []:
  	Room Number []:
  	Work Phone []:
  	Home Phone []:
  	Other []:
  Is the information correct? [Y/n]
!!root!!chroot!!/!!adduser luser luser
  Adding user `luser' to group `luser' ...
  Adding user luser to group luser
  Done.
!!root!!chroot!!/!!adduser luser sudo
  Adding user `luser' to group `sudo' ...
  Adding user luser to group sudo
  Done.
!!root!!chroot!!/!!adduser luser users
  Adding user `luser' to group `users' ...
  Adding user luser to group users
  Done.
!!root!!chroot!!/!!adduser luser staff
  Adding user `luser' to group `staff' ...
  Adding user luser to group staff
  Done.
!!root!!chroot!!/!!adduser luser audio
  Adding user `luser' to group `audio' ...
  Adding user luser to group audio
  Done.
!!root!!chroot!!/!!vi /etc/hostname
!# put whatever single-word hostname you'd like rather than debian
!!root!!chroot!!/!!
```

I also like that the console remains as-is and is not cleared on boot, so let's
create an override

```terminal { title="Live CD" }
!!root!!chroot!!/!!mkdir /etc/systemd/system/getty\@tty1.service.d/ 
!!root!!chroot!!/!!echo '[Service]' > /etc/systemd/system/getty\@tty1.service.d/override.conf  
!!root!!chroot!!/!!echo 'TTYVTDisallocate=no' >> /etc/systemd/system/getty\@tty1.service.d/override.conf  
```

## Reboot!

We can now reboot and remove the liveCD / usb stick and if everything goes well we should be booting
into our new system! Although the following steps should not be necessary, it would be a good idea to unmount
everything manually before shutdown to make sure everything is closed properly, however this typically
does not succeed, so it is ok to just proceed to systemctl poweroff if you see anything failing with
"filesystem in use" or similar.

```terminal { title="Live CD" }
!!root!!chroot!!/!!umount /boot/efi
!!root!!chroot!!/!!exit
!!root!!livecd!!/!!for i in /dev /dev/pts /proc /sys /sys/firmware/efi/efivars /run; do umount /mnt$i; done
!!root!!livecd!!/!!umount /mnt
!!root!!livecd!!/!!lvchange -an /dev/dvg20250527/swap
!!root!!livecd!!/!!lvchange -an /dev/dvg20250527/root
!!root!!livecd!!/!!vgchange -an dvg20250527
    0 logical volume(s) in volume group "dvg20250527" now active
!!root!!livecd!!/!!cryptsetup luksClose lvm
!!root!!livecd!!/!!lsblk
  NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
  loop0         7:0    0   2.8G  1 loop /usr/lib/live/mount/rootfs/filesystem.squashfs
  sda           8:0    1  14.3G  0 disk
  ├─sda1        8:1    1   3.4G  0 part /usr/lib/live/mount/medium
  └─sda2        8:2    1   4.9M  0 part
  nvme0n1     259:0    0 238.5G  0 disk
  ├─nvme0n1p1 259:1    0  1023M  0 part
  └─nvme0n1p2 259:2    0 237.5G  0 part
!!root!!livecd!!/!!systemctl poweroff
```
Continue now to [the next part of the guide]({{< ref
"dont-fear-part-2.md" >}})

[^1]: [https://difyel.com/linux/etc/apt/preferences/](https://difyel.com/linux/etc/apt/preferences/)

[^4]: [http://www.pavelkogan.com/2014/05/23/luks-full-disk-encryption/](http://www.pavelkogan.com/2014/05/23/luks-full-disk-encryption/)

[^5]: [http://www.pavelkogan.com/2015/01/25/linux-mint-encryption/](http://www.pavelkogan.com/2015/01/25/linux-mint-encryption/)

[^6]: [http://asalor.blogspot.ca/2011/08/trim-dm-crypt-problems.html](http://asalor.blogspot.ca/2011/08/trim-dm-crypt-problems.html)

[^7]: [https://wiki.debian.org/SSDOptimization](https://wiki.debian.org/SSDOptimization)

  