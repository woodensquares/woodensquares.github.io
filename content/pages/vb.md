+++
type = "code"
title = "vb"
description = ""
tags = [
]
date = "2016-09-04T10:34:00-08:00"
categories = [
]
shorttitle = "vb"
changelog = [ 
    "Initial release - 2016-09-04",
]
+++

This script is used to start my VirtualBox VMs. It will first check if
the VM is running already, if so it will switch to its workspace it via
the [i3switch script](/pages/i3switch.html) and otherwise it will first
start it, then wait for a few seconds (this needs to be adjusted to your
environment) and then call the [already mentioned]({{< ref "i3-part-1.md#vboxputmount" >}}) vboxputmount script to
have the disk encryption password be entered.

[link to the source file](/code/vb.txt)

```bash
#!/bin/bash

wanted=$1
if vboxmanage showvminfo $wanted --machinereadable | grep -Fxq 'VMState="running"'; then
  i3switch -o $wanted
else
  vboxmanage startvm $wanted
  sleep 3
  vboxputmount $wanted
fi
```
