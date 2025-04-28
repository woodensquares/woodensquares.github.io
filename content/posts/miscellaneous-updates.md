+++
type = "post"
title = "Miscellaneous updates"
description = ""
tags = [
    "site",
    "debian",
]
date = "2025-04-27T12:30:15-06:00"
categories = [
    "Site",
    "Debian",
]
shorttitle = "Miscellaneous updates"
changelog = [ 
    "Initial release - 2025-04-27",
]
+++

As you hopefully did *not* notice (unless you have dark mode enabled) I have updated the site's CSS from 
[Compass](http://compass-style.org/) and related helpers to plain 
[Dart SASS](http://sass-lang.com/dart-sass). This enables me to have the
full CSS be buildable by [Hugo](https://gohugo.io/) together with the site
making for easy changes and faster builds. This required rewriting a fair
bit of the CSS but luckily in the past several years a lot of CSS features
became fairly widely supported, so it feels that the need for something like
Compass is less. I had thought about moving to [Tailwind](http://tailwindcss.com/),
and actually had an integrated build with Hugo, but ultimately I felt that
having to have a full JS environment to develop the site was too much for what it
is.

As I was mentioning above the site should now support dark mode, by respecting
the preference you set in your browser: I decided not to go the route of having
a custom javascript dark mode switcher as I feel this should be under the control
of your browser. If you want to override light/dark just for this site, I am sure
there are add-ons that let you do that.

Besides this I have decided to create new installation pages for the current Debian
release, focusing more on a new series of posts that I am tentatively deciding to
call "don't fear the command line". The focus will be more on setting up a Linux
system, again from scratch, primarily geared towards development, so without as much
of the security aspects I was focusing more on in my previous series. As the years go
by, and more and more supply chain attacks happen, I am finding the need to keep
a completely separate computer for personal stuff from the one I develop on, so having
a local pfSense firewall etc. does not seem as useful as it used to be. This said I do
still think it is useful to have separate VMs entirely for browsing at different
security levels, but it is quite feasible to separate them networking-wise at the
networking layer via VLANs as opposed to on a single box.

Since my last series on Kubernetes, which focused on installing it on bare metal, I
have used a fair bit Kubernetes on docker, which is quite usable and so the series
of posts I was mentioning above will target that. The idea is that following that
series of posts, one could go from a bare metal no-OS x86 computer, to a fully set
up Linux workstation capable of running Kubernetes workloads, with a solid set of
command line utilities and a customized shell environment. Hope you will enjoy the 
journey!
