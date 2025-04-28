+++
type = "post"
title = "Kubernetes and Xen, part 1: prerequisites"
description = ""
tags = [
    "debian",
    "xen",
    "kubernetes"
]
date = "2017-12-14T09:29:27-08:00"
categories = [
    "Debian",
    "Applications",
]
shorttitle = "Kubernetes and Xen - part 1"
changelog = [ 
    "Initial release - 2017-12-14",
]
js = [
    "webcomponents-lite.min.js",
    "term.min.js",
    "tty-player.min.js",
]
css = [
    "tty-player.min.css",
]
+++

Although [Kubernetes](https://kubernetes.io/) supports the excellent
[minikube](https://github.com/kubernetes/minikube) for development purposes,
it is nice to be able to have an actual "real" Kubernetes cluster available at
times to experiment with. 

Although there are many online cloud alternatives, it is a lot more
cost-effective for development purposes to run Kubernetes on a local
bare-metal server, this is achievable on Linux by running the [Xen
hypervisor](https://www.xenproject.org/) and this series of posts will walk
you through its installation and configuration.

Note that it is also possible to achieve a similar result by running
Kubernetes on LXD [as discussed in this page on the Kubernetes
site](https://kubernetes.io/docs/getting-started-guides/ubuntu/local/), with a
one-click install, this guide is more useful if you instead prefer to get your
hands dirty and set things up by yourself of course.

In terms of hardware I would suggest at least a 4-core box, it must also
support the Intel VT-x virtualization extensions, with probably 12-16GB of RAM
and an SSD is definitely a must as having several nodes fighting over a normal
hard drive to launch all the Kubernetes and etcd containers would not work.

Let's first start with a very basic Debian installation, you can follow
previous posts in this guide, and you can also look at the installation being
done in the following windows:

<div id="part-1"></div>

# Part 1, from bare metal to an installed system

As discussed in the [first part]({{< ref "debian-installation-part-1.md" >}})
of the Debian installation guide, starting with a LiveCD we can easily bring
up a debian system. Here I have booted a **Debian Stretch** LiveCD on a system
with an unformatted SSD (and a formatted additional HD) and will ssh to it
from my main system to execute the initial installation.

Note these video have been recorded with
[termrec](https://github.com/kilobyte/termrec) and are being played with
[tty-player](http://tty-player.chrismorgan.info/) which means that besides
being a LOT smaller than an actual video, you can copy/paste from them if
needed which makes them a lot more useful.

{{< ttyplayer autoplay="" loop="" src="/code/part-1.ttyrec" name="p1" >}}

At the end of this video you would execute the systemctl reboot command
however, of course. Note you might get a spurious systemd message about not
being able to connect to the bus, but this will go away later on after other
packages are installed. Another mistake in the video is forgetting to add
,discard to /etc/crypttab which would make fstrim not work.

# Part 2, the first boot

As described in the [next part]({{< ref "debian-installation-part-2.md" >}})
of the guide you should now be on the actual installed system, as opposed to
the LiveCD.

This video was recorded on the console after the first boot, which is why it
has a different geometry. As you can see I first had to fix the lvm.conf file
to disable lvmetad (which might give warnings on boot), you might or might not
want to do this of course.

Also note that there is a pause between about 3:00 and 4:30 where I briefly
paused recording, unfortunately termrec seems to be using epoch timestamps so
when the recording was restarted it did not skip this time.

As a final gotcha, in this video I had tried to enable the sshd service by
using systemctl on it, however although you can in fact enable sshd by
executing *sysctl start sshd.service*, to enable it you have to use
**ssh.service** instead (without the 'd')

{{< ttyplayer autoplay="" loop="" src="/code/part-2.ttyrec" name="p2" >}}

# Part 3, additional configuration

After setting up sshd I could once again ssh into the server, and install a
few additional packages. Since I plan to use this machine purely as a server, I
did not install things like pulseaudio or typical client software. I did
however add X11 just to make it easier in case I needed to do some work on it
locally as opposed as through ssh.

{{< ttyplayer autoplay="" loop="" src="/code/part-3.ttyrec" name="p3" >}}

# Xen prerequisites

At this point it is finally time to take this installation in a new direction
by setting up Xen

{{< terminal title="andromeda" >}}
{{< terminal-comment >}}
Note all the following instructions will assume you are root on the system.
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
sudo -i
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
aptitude -t stretch-backports install xen-linux-system-amd64
{{< /terminal-command >}}
{{< /terminal >}}

since this computer will be running Xen primarily, let's make the Xen appear
first in the grub boot menu

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
dpkg-divert --divert /etc/grub.d/08_linux_xen --rename /etc/grub.d/20_linux_xen 
{{< /terminal-command >}}
{{< /terminal >}}

this particular server will only ever run nouveau, however let's still have
the flexibility to add nvidia later on by making it easy to switch between
Nouveau and Nvidia, it would just be a matter of adding
**modprobe.blacklist=nouveau** to **GRUB_CMDLINE_LINUX** and
**modprobe.blacklist=nvidia,nvidia-drm,nvidia-modeset** to
**GRUB_CMDLINE_LINUX_XEN_REPLACE**

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
update-initramfs -u
{{< /terminal-command >}}
{{< terminal-comment >}}
Edit /etc/default/grub to have the following lines
{{< /terminal-comment >}}
{{< terminal-output >}}
CMDLINE_LINUX="cryptdevice=/dev/disk/by-uuid/2c9ef020-ed38-4ab7-bdbd-928322631b2b:lvm:allow-discards net.ifnames=1"
GRUB_CMDLINE_XEN_DEFAULT="dom0_mem=512M,max:512M dom0_max_vcpus=1 dom0_vcpus_pin"
GRUB_CMDLINE_LINUX="$_CMDLINE_LINUX"
GRUB_CMDLINE_LINUX_XEN_REPLACE="$_CMDLINE_LINUX"
{{< /terminal-output >}}
{{< terminal-comment >}}
edit /etc/default/grub.d/xen.cfg
uncomment the XEN_OVERRIDE_GRUB_DEFAULT=0 line
to avoid warnings every time you update grub
{{< /terminal-comment >}}
{{< terminal-comment >}}
Now update initramfs and grub
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
update-initramfs -u -k all
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
update-grub
{{< /terminal-command >}}
{{< /terminal >}}

with the above lines and some changes below, we will allow only 512 megs to
Dom0 and pin it to one CPU core, leaving the rest of the resources available
for virtualization.

From a networking standpoint you could just have your virtual machines share
their networking with Dom0 by bridging your physical interface, however I
prefer to set things up in a way so that only Dom0 is accessible from outside
the box, but all the Kubernetes nodes on it instead are on a private
192.168.100.1/24 network, which is accessible from the outside only via
specific port forwarding to be done in Dom0.

I do however enable masquerading so the nodes can connect to the outside world
directly in order not to have also to set up a docker registry and so on.

Given this, let's update our /etc/network/interfaces file to contain the
following (note the physical interface name is likely going to be different
from *eno1* in your case, just get its name by running *ip addr*)


{{< highlight bnf >}}
# Loopback
auto lo
iface lo inet loopback

# The physical interface, leave it disabled
iface eno1 inet manual

# The main Xen bridge, which will be connected to Dom0 and will acquire
# an address over DHCP from your network
auto xenbr0
iface xenbr0 inet dhcp
   bridge_ports eno1

# The Xen bridge the other domains will connect to, and that will assign
# addresses using dnsmasq
auto virbr1-dummy
iface virbr1-dummy inet manual
    pre-up /sbin/ip link add virbr1-dummy type dummy
    up /sbin/ip link set virbr1-dummy address 00:16:3e:d1:0b:e7

auto virbr1
iface virbr1 inet static
    bridge_ports virbr1-dummy
    bridge_stp on
    bridge_fd 2
    address 192.168.100.1
    netmask 255.255.255.0
    up /bin/systemctl start dnsmasq@virbr1.service || :
    down /bin/systemctl stop dnsmasq@virbr1.service || :
{{< / highlight >}}

Also note you can set whatever MAC you'd prefer for the virtual bridge, I am
using 00:16:3e:xx:xx:xx as the initial octets as those are typically used for
Xen addresses. You can easily generate random addresses with something like

```bash
echo "00:16:3e"$(hexdump -n3 -e '/1 ":%02x"' /dev/urandom)
```

in order to have dnsmasq available let's install it and disable it (since we
don't want it running on our main interface)

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
aptitude -t stretch-backports install dnsmasq
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
systemctl stop dnsmasq.service
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
systemctl disable dnsmasq.service
{{< /terminal-command >}}
{{< /terminal >}}

in order for dnsmasq to work with the above, we should create a systemd unit
file for it in 

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
cat /etc/systemd/system/dnsmasq\@.service
{{< /terminal-command >}}
{{< terminal-output >}}
[Unit]
Description=DHCP and DNS caching server for %i.
After=network-pre.target

[Service]
ExecStart=/usr/sbin/dnsmasq -k --conf-file=/var/lib/dnsmasq/%i/dnsmasq.conf
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
{{< /terminal-output >}}
{{< /terminal >}}

and the relevant configuration files

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
mkdir -p /var/lib/dnsmasq/virbr1
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
touch /var/lib/dnsmasq/virbr1/leases
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
echo 00:16:3e:ee:ee:01,192.168.100.254 > /var/lib/dnsmasq/virbr1/hostsfile
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
cat /var/lib/dnsmasq/virbr1/dnsmasq.conf
{{< /terminal-command >}}
{{< terminal-output >}}
except-interface=lo
interface=virbr1
bind-dynamic

# .1 will be the address your Dom0 will be accessible from the guests
dhcp-range=192.168.100.2,192.168.100.254

dhcp-lease-max=1000
dhcp-leasefile=/var/lib/dnsmasq/virbr1/leases
dhcp-hostsfile=/var/lib/dnsmasq/virbr1/hostsfile
dhcp-no-override
# Might or might not be useful
# https://www.redhat.com/archives/libvir-list/2010-March/msg00038.html
strict-order
{{< /terminal-output >}}
{{< /terminal >}}

this will set up an initial mapping we'll use to validate everything is
working correctly later on.

# Xen configuration

Debian stretch already by default runs the **xl** Xen stack, however we can
make this explicit by setting it in */etc/default/xen* in a **TOOLSTACK=xl**
line

**/etc/xen/xl.conf** in general does not require any changes, since we will
configure guests explicitly, the following should be set in
**/etc/xen/xend-config.sxp** instead

{{< highlight bnf >}}
(network-script /bin/true)
(vif-script vif-bridge)
(dom0-min-mem 512)
(enable-dom0-ballooning no)
(dom0-cpus 1)
{{< / highlight >}}

I also prefer to start/stop domains manually and don't want Xen to interfere,
so edit **/etc/default/xendomains** and change the SAVE/RESTORE lines to

{{< highlight bnf >}}
XENDOMAINS_SAVE=
XENDOMAINS_RESTORE=false
{{< / highlight >}}

after this we can finally reboot and continue now to [the next part of the guide]({{< ref
"xen-2.md" >}})
