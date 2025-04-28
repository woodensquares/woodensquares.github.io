+++
type = "post"
title = "Don't fear the command line"
description = ""
tags = [
    "debian",
]
date = "2025-04-27T14:29:15-06:00"
categories = [
    "Debian",
]
shorttitle = "Don't fear the command line"
changelog = [ 
    "Initial release - 2025-04-27",
]
+++

In my day job I am noticing more and more that especially junior developers
are uncomfortable using the command line to do basic "systems administration"
tasks or to in general do things where the command line is a much faster way
to achieve whatever task they are trying to do.

This is definitely understandable as when people of my generation took breaks
from walking uphill in the snow both ways to get to their computer, their typical
experience started, and often ended, with a text-based screen. Nowadays most people's
first introduction to computers is graphical and often even touch-based, which makes
a terminal window something completely unfamiliar and often arcane looking.

Adding to this the fact that it is quite easy to have a bad day if one executes
commands or scripts without fully understanding what's going on, and this can create
a lot of anxiety.

These days however as a developer you will often be expected to be able to have at least
some rudimentary command-line skills to deal with containerized workloads, kubernetes etc.
where although some GUIs exist, it is often much much much faster to just open a shell
and deal with whatever is needed there.

Although very few people use Linux as their daily driver, I will start this series with
a from-scratch linux setup, just to demistify a bit what goes on behind the scenes and
to help familiarize you with the command line from the very beginning. If you do not
have a bare metal linux machine to set up, you can definitely follow this guide with
a Virtual Machine, if you are instead not interested at all in the linux side of things, you can skip 
any section that looks linux / X11 specific and instead focus on the shell side of things.

Note in some apt command output in part 1 and 2 you might see differences in debian version
(bullseye vs bookworm) and/or package versions, while writing this guide I have installed on
both but have not gotten all the output from the latest, the commands are correct, just the
versions of the packages installed might differ on your system.

Continue now to [the next part of the guide]({{< ref "dont-fear-part-1.md" >}}) if you want to
start from a bare metal installation, from [the X11 configuration]({{< ref "dont-fear-part-3.md" >}})
post, if you want to also configure your X11 environment, or from 
[the actual start of the command-line specific posts]({{< ref "dont-fear-part-4.md" >}}) depending
on what you prefer.
