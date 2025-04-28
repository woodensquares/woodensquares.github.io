+++
type = "post"
title = "pfSense installation continued, part 2 of 3"
description = ""
tags = [
    "pfSense",
    "security",
]
date = "2016-01-01T12:32:00-08:00"
categories = [
    "Security",
]
shorttitle = "pfSense installation 2"
changelog = [ 
    "Initial release - 2016-01-01",
]
+++

In the [previous step of this tutorial]({{< ref
"pfsense-installation.md" >}}) we set up the pfSense VM
in virtualbox, let's now start it up and actually install pfSense. Allow
the boot to continue until you get to the VLAN prompt we do not need to
set up VLANs for our usage, so press 'n' and continue,

{{< centerimg alt="from now on unless specified these will be text-mode console pfSense screens, this is the beginning of the first boot, the prompt mentioned is 'Do you want to set up VLANs now [y|n]'" src="/images/vbox13.png" >}}

then you just have to enter all the NICs we have until there are no more
and press enter with an empty line

{{< centerimg alt="after pressing n there will be various prompts where one configures the connected interfaces, all of the prompts are of the 'Enter the XX interface name or a for auto-detection' variety, WAN has to be set to vtnet0, LAN to vtnet1" src="/images/vbox14.png" >}}

{{< centerimg alt="continuing with the interfaces, optional 1 to vtnet2, 2 to vtnet3 and so on until you reach optional 14 to vtnet15, having finished simply press enter" src="/images/vbox15.png" >}}

you will now get a recap screen with the assignments that were specified

{{< centerimg alt="recap screen with the previous assignments, WAN to vtnet0, LAN to vtnet1 OPT1 to vtnet2 and so on until OPT14 to vtnet15, with a proceed y/n prompt" src="/images/vbox16.png" >}}

which can be accepted by pressing 'y', afterwards we can move to the
actual HD installation

{{< centerimg alt="the pfSense main text menu, type 99 to select the pfSense installation option" src="/images/vbox17.png" >}}

{{< centerimg alt="in the pfSense installation, configure console screen, select accept these settings with everything set to default" src="/images/vbox18.png" >}}

{{< centerimg alt="in the pfSense installation, select task screen, select quick / easy install" src="/images/vbox19.png" >}}

{{< centerimg alt="in the pfSense installation, are you sure confirmation, select ok" src="/images/vbox20.png" >}}

{{< centerimg alt="in the pfSense installation, install kernel screen, select standard kernel" src="/images/vbox21.png" >}}

{{< centerimg alt="in the pfSense installation, reboot screen, select reboot" src="/images/vbox23.png" >}}

Note depending on the memory and disk size you pick you might get a
warning that your swap partition is not big enough to contain the memory
in case of a crash, up to you if you want to customize the partition
layout or ignore the warning.

You can now reboot (don't forget to take the CD image out of the virtual
drive) and you will be at the pfSense prompt. At this point I usually
remove the 'F1 boot prompt' to speed up the boot process, to do this
follow the steps listed in the official pfSense documentation here [^1]
which will be the following screens

{{< centerimg alt="custom pfSense removal of the boot prompt, at the pfSense menu select option 8 and enter sysctl kern.geom.debugflags=16 then fdisk -B ada0" src="/images/vbox24.png" >}}

{{< centerimg alt="custom pfSense removal of the boot prompt, after the fdisk command will get do you want to change the boot code, enter y" src="/images/vbox25.png" >}}

{{< centerimg alt="custom pfSense removal of the boot prompt, second and final warning, select y" src="/images/vbox26.png" >}}

and reboot the VM. pfSense is now installed, but before we can configure
it via the GUI we have to set up the IP address of the LAN interface,
the one that is connected to our TUN device. At the boot select option
2, *set interfaces IP address*

{{< centerimg alt="back to the pfSense console, select option 2, then 2 again to configure the LAN interface, at the various prompts select 172.31.1.1 for the LAN ipv4 address, 24 for the subnet, an empty gateway and empty ipv6 address, select n to not enable dhcp on this interface" src="/images/vbox27.png" >}}

{{< centerimg alt="after the previous input pfSense will print some status messages following by a you can now access the webConfigurator by opening https://172.31.1.1/" src="/images/vbox28.png" >}}

we do not configure dhcp on our LAN interface as we'll only ever have
our Dom0 connecting there, where we have already set up 172.31.1.2 as
the static ip address in [the systemd unit section]({{< ref
"pfsense-installation.md#pfsensesystemd" >}}) in the
previous configuration step.

After setting up the IP address, [we can now continue the configuration
via the provided GUI]({{< ref "pfsense-installation-3.md" >}}). in the
next part of this tutorial.

[^1]: [https://doc.pfsense.org/index.php/Remove_F1_Boot_Prompt](https://doc.pfsense.org/index.php/Remove_F1_Boot_Prompt)

