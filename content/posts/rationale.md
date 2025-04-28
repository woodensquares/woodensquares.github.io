+++
type = "post"
title = "A VirtualBox VMs based Linux installation"
description = ""
tags = [
    "site",
]
date = "2016-01-01T12:22:00-08:00"
categories = [
    "Site",
]
modified = "2016-01-10"
shorttitle = "Rationale"
changelog = [ 
    "Initial release - 2016-01-01",
    "Move links here from About - 2016-01-10",
    "Added Xen links - 2018-01-14",
]
+++

Security decisions should not be made in isolation but should be taken
in response to specific threat scenarios as there is no such thing as a
completely secure system that is capable of defending against any
possible avenue of attack.

For my specific computing needs I am interested in protecting myself
against the following threats:

-   My computer being stolen while offline and the data it contains
    being accessed
-   A web-based or software-based compromise causing a malware
    installation leading to botnet behavior or information exfiltration

I am not interested in protection against hardware attacks or attacks
that require physical access to my running machine (like a two-pronged
malware + theft attack), so it should be possible to create a set-up
that fulfills these requirements without it being too cumbersome to use
in practice.

I have been very interested in Qubes [^1] from the perspective of
isolating applications in containers and wanted something similar
conceptually, but without having to be tied to a specific distribution,
and with a more easily configurable firewall.

Since the security threats I am interested in protecting myself against
are a lot less severe than the ones Qubes is targeted at, I have decided
to go for an environment based on a fairly minimal Debian installation
running VirtualBox, on a fully encrypted disk, and with pfSense [^2] in
control of the container networking. Although likely not as secure as
Xen against a determined attacker, this should be good enough for my
needs given the scenarios described above.

I decided to run a Debian-stable-based system for reasons of stability
and predictability, as much as I enjoy the Arch Linux [^3] philosophy
for example, I don't want to have a rolling-release distribution as the
basis of my environment, not wanting to risk a bug or update to give me
unexpected downtime.

From a compartmentalization perspective, the VirtualBox host, which I
call Dom0 inside this blog, although we are not running Xen, contains
very few applications and does not connect to the Internet outside the
Debian repositories, so its surface of attack should be minimal, as long
as proper software hygiene principles are followed.

All the software I need for my day-to-day computing needs is run inside
VirtualBox VMs. Every VM and Dom0 can access the internet only through a
pfSense VM, configured with several adapters in order to allow different
network access permissions for different VMs and network isolation
in-between them.

The idea of having all internet access go through pfSense comes from
these two blog posts / series [^4] [^5], and installing LUKS with an
encrypted /boot comes from this other post instead [^6].

These sites together with investigating Qubes have been the main reason
why I have decided to set my system up this way, and I thought it would
be worth sharing my set-up with others as it has been working well for
me for some time.

As you can see in the other posts on this site I have installed the
system without using an installer to have complete control on what
packages are actually going to be used, I wanted to keep Dom0 as light
as possible and so without a desktop environment or other packages that
tend to be part of the base installation nowadays.

As much as this site is written from the perspective of using Debian as
a Dom0 distribution, you should be able to replicate this set-up in
whatever distribution you use, the main differences among distributions,
besides the package manager specifics, will likely be whether or not
systemd will be available (if it isn't, you will have to change the few
systemd units to rc.d scripts) and if the distribution can be installed
via debootstrap or if you'll need to do something else to get a minimal
system up and running with the partitioning scheme that is advocated
here.

Either way the advantage of this way of running Linux is that pretty
much all applications live in their own VM, so if some day you decide to
change Dom0 to a different distribution, it'd be simply a matter of
moving the VMs over once you have VirtualBox up and running. Since the
only purpose of Dom0 is really to run VirtualBox and X11, what
distribution you use should not impact you much on a day-to-day basis.

The posts on this site that are relevant to setting the system up this
way are the following:

[Debian installation part 1]({{< ref "debian-installation-part-1.md" >}})

[Debian installation part 2]({{< ref "debian-installation-part-2.md" >}})

[pfSense installation part 1]({{< ref "pfsense-installation.md" >}})

[pfSense installation part 2]({{< ref "pfsense-installation-2.md" >}})

[pfSense installation part 3]({{< ref "pfsense-installation-3.md" >}})

[pfSense configuration part 1]({{< ref "pfsense-configuration.md" >}})

[pfSense configuration part 2]({{< ref "pfsense-configuration-2.md" >}})

this would give you the minimal setup with pfSense firewalling, you can
then continue with

[Debian installation part 3]({{< ref "debian-installation-part-3.md" >}})

[Debian installation part 4]({{< ref "debian-installation-part-4.md" >}})

for a few extra bits and pieces if needed. Other Debian/system-related posts
are more stand-alone and should not be required for the basic set-up, but
might have ways to smooth out its day-to-day operation.

Another series of posts on this site that should be looked at together is the
following, related to setting up a Xen / Kubernetes cluster on bare metal.

[Kubernetes and Xen part 1]({{< ref "xen-1.md" >}})

[Kubernetes and Xen part 2]({{< ref "xen-2.md" >}})

[Kubernetes and Xen part 3]({{< ref "xen-3.md" >}})

[Kubernetes and Xen part 4]({{< ref "xen-4.md" >}})

[Kubernetes and Xen part 5]({{< ref "xen-5.md" >}})

[Kubernetes and Xen part 6]({{< ref "xen-6.md" >}})

[Kubernetes and Xen final]({{< ref "xen-final.md" >}})

[^1]: https://www.qubes-os.org/

[^2]: http://pfsense.org/

[^3]: https://www.archlinux.org/

[^4]: http://brezular.com/2015/01/18/pfsense-virtualbox-appliance-as-personal-firewall-on-linux/

[^5]: http://timita.org/wordpress/2011/07/29/protect-your-windows-laptop-with-pfsense-and-virtualbox-part-1-preamble/

[^6]: http://www.pavelkogan.com/2014/05/23/luks-full-disk-encryption/

