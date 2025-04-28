+++
type = "post"
title = "A more full-featured Debian installation"
description = ""
tags = [
    "debian",
    "linux",
]
date = "2016-01-01T15:41:00-08:00"
categories = [
    "Debian",
]
modified = "2017-11-27"
shorttitle = "Add more functionality"
changelog = [ 
    "Initial release - 2016-01-01",
    "VirtualBox multiple screens - 2017-11-27",
]
+++

At the [end of the minimal installation
instructions]({{< ref "debian-installation-part-2.md" >}}) we ended up
with a basic X installation running the i3 window manager, after this if
you have [followed the suggested installation
path]({{< ref "pfsense-installation.md" >}}) you should have your pfSense
based virtual networking up and running.

Your Dom-0 installation should remain fairly minimal, ideally you would
not run anything but VirtualBox and aptitude in it, however it really
depends from your typical use-case, as in some situations running
specific applications on your bare metal system available can be useful.

This said I would suggest that you create a new VirtualBox VM to serve
as the 'base' VM for most of your typical Linux environments, for
example the VM you will likely use to compile software for your base
system and other VMs.

The amount of RAM and CPU you are going to give your VMs really depends
on what kind of hardware your host system is running, however the other
configuration settings should be pretty much similar.

After creating a new network and setting up the needed rules as
described at the end [of the pfSense configuration
instructions]({{< ref "pfsense-configuration-2.md#newnetwork" >}}) let's
now set up the new VM with everything set to default but these settings

-   clipboard: Host-to-guest
-   chipset: ICH9
-   display: 128MB
-   storage: new 23GB vdi, debian iso in the CD drive
-   network: an internal network name, virtio interface
-   audio: pulseaudio

If you have issues with choppy audio in your VMs, you might have to
change the above to alsa, from pulseaudio, it might work better but in
that case it might also disallow you from using audio in your Dom0 by
taking the audio device access, depending if you plan to use audio there
(say, for notifications) this might or might not be a big deal for you.

For the network it should be attached to whichever pfSense interface you
have configured with the access you need; for a base vm it's probably a
good idea to have it by default attached to a fairly locked pfSense
interface, but it's really up to you.

After creating the VM, boot it and follow the
[two]({{< ref "debian-installation-part-1.md" >}})
[previous]({{< ref "debian-installation-part-2.md" >}}) parts of the
installation guide again (note the different video settings) until you
have your base debian system installed.

<div id="noapt"></div>

Note that the initial step of updating aptitude and installing
netselect-apt would not be meaningful for this installation, as the
pfSense rules discussed will open http access only to your local debian
mirror; you should instead edit */etc/apt/sources.list* manually to make
it the same as your Dom0 before using apt/aptitude.

The passwords and keyfiles you pick for your LUKS installation are up to
you, VirtualBox 5.x now supports encrypting VMs, however I prefer to not
depend on this functionality and just install LUKS in the VM as well.

I am suggesting 23GB above for an easy way to back-up these VMs on
inexpensive single-layer blu-ray disks without having to worry about vdi
files being too large (you can add more vdis/controllers if needed
easily enough). Having LUKS in your installed VM means the VMs can be
backed up without worrying about encrypting them further, however for
cases in which your VM is not running full disk encryption this
extensive tutorial [^1] explains how it could be done. As much as you
probably wouldn't want to depend only on writable discs for backups, I
find they are a good and fairly inexpensive addition to a typical NAS +
offsite/cloud disaster recovery strategy.

After the base VM is installed, it can be used via cloning as a starting
point for your other VM installations.

When cloning VMs, besides reinitializing the MAC address of the network
interface, you also want to on your first log in change the hostname in
*/etc/hostname* and remove the */etc/dhcpcd.duid* file that was created
by your initial 'base' boot, otherwise your pfSense installation DHCP
leases will not work correctly (before removing this file remember to
*systemctl stop dhcpcd.service* to release the lease).

If this file exists dhcpcd will reuse the duid in it so from the pfSense
perspective it'd be as if the same host kept requesting leases, a
symptom of that would be that the DNS resolution of pfSense host leases
would not work (but [note that DNS resolution might not work for other
reasons]({{< ref "pfsense-configuration.md#dhcpleases" >}}))

From now on it will be up to you if you are going to install any package
in your Dom0 system, in your base vmimage, or only in your devel or
other specific VMs. Note though that when compiling something in your
base or devel VM to deploy on your Dom0, you might end up in situations
where your base system does not have the required shared libraries to
run what you have built, use of *apt-file* and *ldconfig* should be
helpful in figuring out what lib packages you'll need to install in Dom0
for things to run if you don't want to build things statically.

The rest of this page will list some possibly useful packages /
applications you might be interested in.

<div id="vboxmultidisplay"></div>

Multiple screens in VirtualBox
------------------------------

As of this writing, current (stretch) VirtualBox packages available in Debian
do not have this issue, however if you are still on Debian Jessie you might
find yourself in the situation where your VirtualBox VMs are not able to
display multiple separate screens (xrandr will report the outputs as disabled,
or won't report them at all, depending on the version of the guest additions
you have installed). This has been discussed [in a bug
report](https://www.virtualbox.org/ticket/14497) and it is possible to
backport this fix by downloading a fixed guest additions distribution, and
simply taking the needed module from it.

First download the 5.0.12 guest additions from the [old
builds](https://www.virtualbox.org/wiki/Download_Old_Builds_5_0) and then:

{{< terminal title="andromeda" >}}
{{< terminal-command user="luser" host="andromeda" path="~" >}}
sudo aptitude -t jessie backports install fuseiso9660
{{< /terminal-command >}}
{{< terminal-command user="luser" host="andromeda" path="~" >}}
fuseiso9660 VBoxGuestAdditions_5.0.12.iso /tmp/vb_iso/
{{< /terminal-command >}}
{{< terminal-command user="luser" host="andromeda" path="~" >}}
./vb_iso/VBoxLinuxAdditions.run --tar xf ./VBoxGuestAdditions-amd64.tar.bz2
{{< /terminal-command >}}
{{< terminal-command user="luser" host="andromeda" path="~" >}}
mkdir x
{{< /terminal-command >}}
{{< terminal-command user="luser" host="andromeda" path="~/x" >}}
cd x
{{< /terminal-command >}}
{{< terminal-command user="luser" host="andromeda" path="~/x" >}}
tar xf ../VBoxGuestAdditions-amd64.tar.bz2
{{< /terminal-command >}}
{{< terminal-command user="luser" host="andromeda" path="~/x" >}}
cd /usr/lib/xorg/modules/
{{< /terminal-command >}}
{{< terminal-command user="luser" host="andromeda" path="/usr/lib/xorg/modules" >}}
sudo cp /tmp/x/lib/VBoxGuestAdditions/vboxvideo_drv_116.so vboxvideo_drv.so
{{< /terminal-command >}}
{{< /terminal >}}

this will overwrite the existing vboxvideo_drv.so module, with the patched one
from the newer guest additions distribution (of course it would be a good idea
for you to make a backup of the original .so file just in case).

After this is done you can reboot the virtual machine to get the new module
picked up, and if you have configured multiple monitors in the VM GUI they
will now correctly show in xrandr although still disabled.

To enable them, you also need to execute the following commands in your Dom0,
for example for a VM with 3 monitors connected named devel you would

{{< terminal title="andromeda" >}}
{{< terminal-command user="luser" host="andromeda" path="~" >}}
vboxmanage controlvm devel setvideomodehint 1920 1080 24 2
{{< /terminal-command >}}
{{< terminal-command user="luser" host="andromeda" path="~" >}}
vboxmanage controlvm devel setvideomodehint 1920 1080 24 1
{{< /terminal-command >}}
{{< /terminal >}}

this will connect the displays, which should now finally work correctly, by
default they will likely be set up with mirroring, so you would turn to xrandr
in the virtual machine to fix this

{{< terminal title="andromeda" >}}
{{< terminal-command user="luser" host="andromeda" path="~" >}}
xrandr --output VGA-1 --right-of VGA-0
{{< /terminal-command >}}
{{< terminal-command user="luser" host="andromeda" path="~" >}}
xrandr --output VGA-2 --left-of VGA-0
{{< /terminal-command >}}
{{< /terminal >}}

<div id="miscdebian"></div>

Miscellaneous Debian packages
-----------------------------

When setting up a development / staging VM, more packages are usually
needed to have a full featured development environment, let's first
start with packages available in the Debian repository.

{{< terminal title="andromeda" >}}
{{< terminal-comment >}}
killall etc.
{{< /terminal-comment >}}
{{< terminal-command user="luser" host="andromeda" path="~" >}}
sudo aptitude -t jessie backports install psmisc
{{< /terminal-command >}}
{{< terminal-comment >}}
C/Python development, as well as some relevant libraries
{{< /terminal-comment >}}
{{< terminal-command user="luser" host="andromeda" path="~" >}}
sudo aptitude -t jessie-backports install cmake cmake-gui g++ libx11-dev libxext-dev gengetopt libxrandr-dev libxfixes3 libxfixes-dev libimlib2 libimlib2-dev python python3 python-pip python3-pip virtualenv virtualenvwrapper python-virtualenv python3-virtualenv python-dev python3-dev ack-grep silversearcher-ag autoconf libglew-dev libglm-dev
{{< /terminal-command >}}
{{< terminal-comment >}}
Miscellaneous development software
{{< /terminal-comment >}}
{{< terminal-command user="luser" host="andromeda" path="~" >}}
sudo aptitude -t jessie-backports install feh stow mtr ssh
{{< /terminal-command >}}
{{< /terminal >}}

I am a fairly recent Debian user, so sometimes I know what executable I
want but not necessarily the name of the package it's contained in, in
these cases I find apt-file to be extremely helpful

{{< terminal title="andromeda" >}}
{{< terminal-command user="luser" host="andromeda" path="~" >}}
aptitude -t jessie-backports install apt-file
{{< /terminal-command >}}
{{< terminal-command user="luser" host="andromeda" path="~" >}}
sudo apt-file update
{{< /terminal-command >}}
{{< /terminal >}}

after this is installed a simple **apt-file search /bin/execname**
usually is all that I need to find what to install to get what I need.

<div id="miscnondebian"></div>

Miscellaneous non-Debian packages
---------------------------------

The following are either not available in Jessie or outdated, they will
be installed in */usr/local/stow/packagename* and use GNU stow in order
to keep things as easily upgradable as possible.

Note that currently gnu stow in Jessie will give you a 'Possible
precedence issue' warning when it's used, this can be fixed by applying
the following patch [^2] to */usr/share/perl5/Stow.pm*.

For self-built packages I usually *untar* or *git clone* in
*/usr/local/src* and build there, after installing in
*/usr/local/stow/packagename* I just **cd /usr/local/stow** and run
**stow packagename** to create the needed symlinks.

Note that if the package you are building has an info dir entry, you
will likely get a conflict when stowing it, I suggest you simply rename
info/dir to something else before calling stow packagename or use
**--defer=info** to skip it (an alternative would be to use xstow
instead and set up merge-info in your xstow.ini)

### GnuPG

Debian repositories do come with GnuPG packages, however currently the
packages available for Jessie are only GnuPG 2.0.x, while I prefer
running the latest 2.1.x series. It is fairly straightforward to install
directly from source and using it via stow.

In your staging/development VM you would want to install the following
build requirements

{{< terminal title="andromeda" >}}
{{< terminal-command user="luser" host="andromeda" path="~" >}}
sudo aptitude -t jessie-backports install libreadline-dev gnutls-dev libldap-dev libusb-dev
{{< /terminal-command >}}
{{< /terminal >}}

afterwards you can download and install the following libraries from the
GPG website: **libassuan**, **libgcrypt**, **libgpg-error**, **libksba**
and **npth**.

All of them can be built with a similar command line, **./configure
--prefix=/usr/local/stow/gpg-2.1.9 --enable-maintainer-mode** and then
make / make install as usual.

After all the libraries are built you can then configure GnuPG itself
with a very similar **./configure --prefix=/usr/local/stow/gpg-2.1.9
--enable-symcryptrun --enable-gpgtar --enable-maintainer-mode** and make
/ make install it to your stow directory.

After building GPG in your development VM and copying it to your Dom0
and activating it via stow, you should install one of the pinentry
packages for it to work correctly.

If you have a card reader or, say, a YubiKey, there are a few more steps
for it to be functional, first you should install some additional
packages

{{< terminal title="andromeda" >}}
{{< terminal-command user="luser" host="andromeda" path="~" >}}
sudo aptitude -t jessie-backports install pinentry-qt4 pcsc-tools pcscd libccid
{{< /terminal-command >}}
{{< /terminal >}}

then run **pcsc\_scan -n**, this should print out however many readers
it can find, for example for my YubiKey it prints out **Yubico Yubikey
NEO OTP+CCID 00 00**. With this information you can create your
**\$HOME/.gnupg/scdaemon.conf** file, where you would insert a line like
**reader-port "Yubico Yubikey NEO OTP+CCID 00 00"**. After doing this
*gpg2 --card-status* should be working correctly (note you want to
reboot after changing *scdaemon.conf*).

<div id="emacsvim"></div>

### Emacs and Vim

For both Emacs and Vim I prefer running the latest available versions,
and again manage them with stow, for emacs to be built with most/all
features enabled you would install the following packages in your build
environment:

{{< terminal title="andromeda" >}}
{{< terminal-command user="luser" host="andromeda" path="~" >}}
sudo aptitude -t jessie-backports install libgtk2.0-dev libxft-dev libxpm-dev libgpm-dev libotf-dev libxml2-dev libmagickwand-dev libm17n-dev libgif-dev libgnutls-openssl-dev libncurses-dev
{{< /terminal-command >}}
{{< /terminal >}}

and configure it with **./configure --prefix=/usr/local/stow/emacs-24.5
--with-xft --with-x-toolkit=gtk2**

For vim I use the following configuration line instead **./configure
--prefix=/usr/local/stow/vim-7.4.927 --with-features=huge --enable-gpm
--disable-gui --enable-multibyte --enable-cscope --disable-netbeans
--enable-pythoninterp --enable-perlinterp --enable-pythoninterp
--disable-rubyinterp --enable-luainterp --with-x** but it is really up
to you what you would prefer to use. I do think it is good to have a
system vim installed anyways, after you do so you would update your
alternatives with, for example, **sudo update-alternatives --set editor
/usr/bin/vim.basic**

<div id="screenshot"></div>

### Screenshot support

For screenshots, I had to take quite a few for these posts, I like the
following no-frills packages

{{< terminal title="andromeda" >}}
{{< terminal-command user="luser" host="andromeda" path="/usr/local/src" >}}
git clone https://github.com/naelstrof/slop
{{< /terminal-command >}}
{{< terminal-command user="luser" host="andromeda" path="/usr/local/src" >}}
cd slop
{{< /terminal-command >}}
{{< terminal-command user="luser" host="andromeda" path="/usr/local/src/slop" >}}
cmake -DCMAKE_INSTALL_PREFIX:PATH=/usr/local/stow/maim -DCMAKE_OPENGL_SUPPORT=true ./ ; make ; make install
{{< /terminal-command >}}
{{< terminal-command user="luser" host="andromeda" path="/usr/local/src/slop" >}}
cd /usr/local/stow && stow slop
{{< /terminal-command >}}
{{< terminal-command user="luser" host="andromeda" path="/usr/local/stow" >}}
cd /usr/local/src
{{< /terminal-command >}}
{{< terminal-command user="luser" host="andromeda" path="/usr/local/src" >}}
git clone https://github.com/naelstrof/maim
{{< /terminal-command >}}
{{< terminal-command user="luser" host="andromeda" path="/usr/local/src" >}}
cd maim
{{< /terminal-command >}}
{{< terminal-command user="luser" host="andromeda" path="/usr/local/src/maim" >}}
cmake -DCMAKE_INSTALL_PREFIX:PATH=/usr/local/stow/maim -DCMAKE_INSTALL_MANDIR:PATH=/usr/local/stow/maim/share/man/ ./ ; make ; make install
{{< /terminal-command >}}
{{< terminal-command user="luser" host="andromeda" path="/usr/local/src/main" >}}
cd /usr/local/stow && stow maim
{{< /terminal-command >}}
{{< /terminal >}}

after they are installed you can simply run **maim -s
screenshot.name.png** and select the area you want to capture, which
will then be saved in the file you specify.

[^1]: [http://www.troubleshooters.com/lpm/201408/201408.htm](http://www.troubleshooters.com/lpm/201408/201408.htm)

[^2]: [http://git.savannah.gnu.org/cgit/stow.git/commit/?id=d788ce0c1c59b3158270143659f7a4363da73056](http://git.savannah.gnu.org/cgit/stow.git/commit/?id=d788ce0c1c59b3158270143659f7a4363da73056)

