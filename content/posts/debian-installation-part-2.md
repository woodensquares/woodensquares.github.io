+++
type = "post"
title = "Setting up a minimal X environment"
description = ""
tags = [
    "debian",
    "linux",
    "nvidia",
]
date = "2016-01-01T12:29:00-08:00"
categories = [
    "Debian",
]
modified = "2017-12-03"
shorttitle = "A minimal X setup"
changelog = [ 
    "Initial release - 2016-01-01",
    "Added mention of xserver-xorg-legacy - 2016-09-04",
    "Stretch updates - 2017-11-27",
    "Add sshd - 2017-11-29",
    "New highlighting for commands - 2017-12-03",
    "Debian stretch again - 2018-06-21",
]
+++

At the [end of the minimal installation instructions]({{< ref
"debian-installation-part-1.md#finalsteps" >}}) we
ended up with a bare-bones Debian installation, where we can now login
as root with the password that was entered [as part of the
installation]({{< ref "debian-installation-part-1.md#rootpassword" >}}).

A normal user account should be created, I personally set things up so
that my normal user account is uid/gid 1000 and add other groups to it,
the uid/gids can of course be changed as needed. This is also a good
time to install sudo and add the non-privileged user to it.

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
aptitude -t jessie-backports install sudo
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
addgroup --gid 1000 luser
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
adduser --uid 1000 --gid 1000 luser
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
addgroup luser sudo
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
addgroup luser users
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
addgroup luser staff
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
addgroup luser audio
{{< /terminal-command >}}
{{< /terminal >}}

let's now set up the locale, the following steps depend on where you
live, the example here is for a US English locale.

{{< terminal title="andromeda" >}}
{{< terminal-comment >}}
This should display only C, C.UTF-8 and POSIX at this point
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
locale -a
{{< /terminal-command >}}
{{< terminal-output >}}
C
C.UTF-8
POSIX
{{< /terminal-output >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
aptitude install locales
{{< /terminal-command >}}
{{< terminal-comment >}}
Edit this file and uncomment the wanted locale(s), say en_US.UTF-8
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
vi /etc/locale.gen
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
cat /etc/locale.gen | grep -v \#
{{< /terminal-command >}}
{{< terminal-output >}}
en_US.UTF-8 UTF-8
{{< /terminal-output >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
locale-gen
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
echo 'LANG=en_US.UTF-8' > /etc/default/locale
{{< /terminal-command >}}
{{< /terminal >}}

after regenerating the locales and setting the default, running *env* in
a login shell should display the *LANG=custom\_locale* environmental
variable.

By default *journalctl* is run in non-persistent mode, to enable
persistence just *mkdir /var/log/journal* the maximum size used for this
can be configured in */etc/systemd/journald.conf* with **SystemMaxUse**,
the default is 10% of the filesystem, after changing this file restart
the journal by running *systemctl restart systemd-journald*

It is now time to install more packages. If dhcpcd was disabled earlier,
manually start it for the time being and update the package database, and
upgrade any needed packages

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
/etc/init.d/dhcpcd start
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
aptitude update
{{< /terminal-command >}}
{{< terminal-comment >}}
See below for more information on what to do in aptitude
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
aptitude -t jessie-backports
{{< /terminal-command >}}
{{< /terminal >}}

In general I prefer to run backported packages whenever possible, at the
time of this writing stable was jessie and testing was stretch, so I
usually alias '*sudo aptitude -t jessie-backports*' to **ap** to
minimize typing, however in this guide I will write out the aptitude
command line fully.

After updating the packages I run *aptitude -t jessie-backports* and upgrade
installed packages to their jessie-backports versions, typing **u**,
**shift+u**, **g** and **g** again.

For a bare-metal installation I tend to be conservative and might or might not
upgrade the kernel to the backports version (currently for example jessie is
on 3.16 while jessie-backports is on 4.2). If you want to experiment it would
probably be a good idea to, after installing, set up /etc/default/grub with
**GRUB\_DEFAULT=saved** and set the kernel you want to normally boot with
*grub-set-default*.

Either way after the above the headers of whichever kernel is in use should be
installed at this point via **aptitude install linux-headers-amd64** or
**aptitude -t jessie-backports install linux-headers-amd64** depending on the
kernel choice.

It is a good idea to now install sshd, to make it easier to debug issues from
other computers, and also to set up some dependencies, like dbus, that will be
used by later packages

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
aptitude -t jessie-backports install openssh-server
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
systemctl enable ssh.service
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
systemctl start ssh.service
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
systemctl reboot
{{< /terminal-command >}}
{{< /terminal >}}

Note that apparently in stretch you can start the sshd server both by using
ssh.service and sshd.service, but the service can be enabled only by using
ssh.service.

<div id="x11"></div>

X11 installation
----------------

In order to continue with the set-up of the system and its networking
X11 needs to be running. I have moved to an i3-based set up some time
ago and am quite enjoying it both in terms of minimalism and usability,
it is extremely fast, configurable and fits in very well with the way I
use the system, so from now on the installation instructions assume this
is what will be used both in terms of packages installed and
configuration.

The package list we will be using is this

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
aptitude -t jessie-backports install i3 xterm pulseaudio xinit dkms x11-xserver-utils dbus-x11 
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
addgroup luser pulse
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
addgroup luser pulse-access
{{< /terminal-command >}}
{{< /terminal >}}

Note in some newer debian releases you might also need to install
xserver-xorg-legacy.

Before continuing it's also a good idea to make sure you are getting the
best font experience you can, if you are running an LCD screen I would
suggest creating the following symlinks to enable subpixel anti-aliasing
and hinting, note some of these links might already exist, so use -sf
here just in case. Also note the below assume that your LCD screen has
its phosphors laid out as RGB, if it is different please use one of the
other subpixel hinting files

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
cd /etc/fonts/conf.d
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/etc/fonts/conf.d" >}}
ln -s /usr/share/fontconfig/conf.avail/10-sub-pixel-rgb.conf
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/etc/fonts/conf.d" >}}
ln -s /usr/share/fontconfig/conf.avail/10-autohint.conf
{{< /terminal-command >}}
{{< terminal-comment >}}
Note lcdfilter might already be there
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="/etc/fonts/conf.d" >}}
ln -s /usr/share/fontconfig/conf.avail/11-lcdfilter-default.conf
{{< /terminal-command >}}
{{< /terminal >}}

<div id="nvidia"></div>

After these packages it's time to configure the video card, unfortunately
in Jessie nouveau was not able to drive my main monitor at its native resolution over
hdmi for some reason, while Nvidia's proprietary drivers could, therefore I had
to install their package according to the Debian wiki instructions [^1]
however note [this followup post]({{< ref "xen-1.md#nvidia" >}}) if you are in
need of a more up-to-date driver for things like CUDA etc.

Note that in more recent debian releases (i.e. stretch) nvidia-xconfig would
not strictly be needed anymore, so it could be omitted from the below lines.

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
aptitude -t jessie-backports install nvidia-detect
{{< /terminal-command >}}
{{< terminal-comment >}}
Make sure your video card is supported, this is an example of a supported card
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
nvidia-detect
{{< /terminal-command >}}
{{< terminal-output >}}
Detected NVIDIA GPUs:
02:00.0 VGA compatible controller [0300]: NVIDIA Corporation GK106 [GeForce GTX 660] [10de:11c0] (rev a1)
Your card is supported by the default drivers and legacy driver series 304.
It is recommended to install the
    nvidia-driver
package.
{{< /terminal-output >}}
{{< terminal-comment >}}
Now install the drivers
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
aptitude -t jessie-backports install nvidia-kernel-dkms xorg-server-source nvidia-xconfig
{{< /terminal-command >}}
{{< terminal-comment >}}
This might or might not be needed in recent drivers
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
nvidia-xconfig
{{< /terminal-command >}}
{{< terminal-comment >}}
Now reboot to blacklist nouveau and use the nvidia driver don't forget to restart dhcpcd afterwards if you need to
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
systemctl reboot
{{< /terminal-command >}}
{{< /terminal >}}

If you are using this installation guide to install a VirtualBox VM, you
should install the following packages instead and add your user to the
vboxsf group to be able to have access to the shared folders.

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
aptitude -t jessie-backports install virtualbox-guest-dkms virtualbox-guest-x11 virtualbox-guest-utils
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
addgroup luser vboxsf
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
systemctl reboot
{{< /terminal-command >}}
{{< /terminal >}}

at this point if you login with your user account and type startx you
should be able to get to your chosen graphical enviroment, if you are
using i3 you will have to answer a question of which key you prefer to
use as your i3 modifier, and after that you can press this modifier key
and *Enter* to start your xterm.

After confirming that the X environment works, the system can be set up
so it boots automatically in it. Given that to actually boot the system
one needs to know the LUKS password, having to type the
username/password to login as well at every boot does not seem to
significantly enhance the system's security.

An *override.conf* file for tty1 has already been created in [the
previous instructions]({{< ref
"debian-installation-part-1.md#finalsteps" >}}), so
it can be modified as follows:

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
root@andromeda:~# cat /etc/systemd/system/getty@tty1.service.d/override.conf
{{< /terminal-command >}}
{{< terminal-output >}}
[Service]
TTYVTDisallocate=no
Type=simple
ExecStart=
ExecStart=-/sbin/agetty --autologin luser --noclear %I 38400 linux
{{< /terminal-output >}}
{{< /terminal >}}

this will log into the selected user after booting, in order for X to
start a bash login file also needs to be created for the user that does
so if it's not running already:

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
echo '[[ -z $DISPLAY && $XDG_VTNR == 1 ]] && exec startx' > ~luser/.bash_profile
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
chown luser:luser ~luser/.bash_profile
{{< /terminal-command >}}
{{< /terminal >}}
<div id="audio"></div>

Audio considerations
--------------------

Debugging pulseaudio issues is definitely beyond the scope of this
guide, if you are experiencing problems I suggest checking out this
excellent guide on Arch wiki [^2] however a few suggestions would be to
first of all blacklist any USB or HDMI sound devices

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
aptitude -t jessie-backports install alsa-utils
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
echo blacklist snd_usb_audio > /etc/modprobe.d/sound.blacklist.conf
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
echo blacklist snd_hda_codec_hdmi >> /etc/modprobe.d/sound.blacklist.conf
{{< /terminal-command >}}
{{< /terminal >}}

after rebooting you can check your sound by running **speaker-test -c 2
-t wav**, if everything is ok you should hear a left/right voice from
your speakers. If you can't hear anything you should first of all make
sure that all the outputs listed by alsamixer both for pulseaudio and
for your physical card have a green **00** under it to make sure they
are not muted

{{< terminal title="andromeda" >}}
{{< terminal-comment >}}
this should cover pulseaudio
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
alsamixer
{{< /terminal-command >}}
{{< terminal-comment >}}
this should give you your physical devices
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
alsamixer -c 0 -D sysdefault
{{< /terminal-command >}}
{{< terminal-comment >}}
this might or might not be needed to persist your changes
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
alsactl store
{{< /terminal-command >}}
{{< /terminal >}}

if you still don't have sound you might also want to try running
**amixer -c 0 sset "Auto-Mute Mode" Disabled**

Optionally you can also install **pavucontrol** to fine-tune your
pulseaudio configuration, or follow one of Arch Linux wiki guides to set
up Jack or OSS.

<div id="done"></div>

And we're done!
---------------

after you reboot you should find yourself at your X screen, the
instructions from this point on will assume you are running in X as your
chosen user, and so will use sudo whenever needed, we can now continue
[to and set up networking in pfSense]({{< ref "pfsense-installation.md" >}})

[^1]: [https://wiki.debian.org/NvidiaGraphicsDrivers#Debian_8_.22Jessie.22](https://wiki.debian.org/NvidiaGraphicsDrivers#Debian_8_.22Jessie.22)

[^2]: [https://wiki.archlinux.org/index.php/PulseAudio/Troubleshooting](https://wiki.archlinux.org/index.php/PulseAudio/Troubleshooting)

