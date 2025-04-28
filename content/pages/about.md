+++
type = "about"
title = "About this site"
description = ""
tags = [
]
date = "2015-12-22T15:44:00-08:00"
categories = [
]
shorttitle = "About this site"
changelog = [
"Initial release - 2016-01-01",
"Move links to rationale - 2016-01-10",
"Hugo rewrite - 2017-10-23",
"Added tty-player dependencies - 2017-10-25",
"Hugo updates, moved to Dart SASS - 2022-11-22",
]
+++

After several years using other OSs as my day-to-day environment, I have
decided to once again run Linux as my main desktop OS and I wanted to
have an installation that was reasonably secure, where I could have a
fair amount of control over what was running and where different tasks /
environments could be isolated from each other. The rationale for my
choices and links to the posts describing how to set the system up [are
discussed in this post]({{< ref "rationale.md" >}})

This site has been set up primarily to capture how I have configured
this environment and any other tips / gotchas / software / information I
have found useful, I have many times in my personal and professional
life benefited from others sharing their work, and hopefully what I
write here will be beneficial.

If anything is unclear, or wrong, or you see any issues with the site in
general, please email me at issues@ this domain and I will get
back to you as soon as I can.

THANKS
------

I have used the following packages to generate this site:

- [Hugo](https://gohugo.io/) ( Apache 2.0 license:
  [https://gohugo.io/about/license/](https://gohugo.io/about/license/)
  \)
- [Dart SASS](http://sass-lang.com/dart-sass) ( MIT license:
  [https://github.com/sass/dart-sass/blob/stable/MIT-LICENSE](https://github.com/sass/dart-sass/blob/stable/MIT-LICENSE)
  )
- [CSS3 breadcrumbs](https://github.com/komputerwiz/css3-breadcrumbs) (
  Public domain license:
  [https://github.com/komputerwiz/css3-breadcrumbs/blob/master/README.md#license](https://github.com/komputerwiz/css3-breadcrumbs/blob/master/README.md#license)
  )

In previous versions of the site, before moving on to Dart SASS, I have used the following

- [Compass](http://compass-style.org/) ( modified MIT license:
  [https://github.com/Compass/compass/blob/stable/LICENSE.markdown](https://github.com/Compass/compass/blob/stable/LICENSE.markdown)
  )
- [Susy](https://github.com/oddbird/susy/) ( BSD 3-clause license:
  [https://github.com/oddbird/susy/blob/master/LICENSE.txt](https://github.com/oddbird/susy/blob/master/LICENSE.txt)
  )
- [breakpoint](http://breakpoint-sass.com/) ( GPL/MIT licenses:
  [https://github.com/at-import/breakpoint](https://github.com/at-import/breakpoint)
  )
- [sass-math](https://github.com/adambom/Sass-Math/) ( MIT license:
  [https://github.com/adambom/Sass-Math/blob/master/LICENSE](https://github.com/adambom/Sass-Math/blob/master/LICENSE)
  )
- [normalize.css](https://necolas.github.io/normalize.css/)
  ( MIT license:
  [https://github.com/necolas/normalize.css/blob/master/LICENSE.md](https://github.com/necolas/normalize.css/blob/master/LICENSE.md)
  )
- [modular scale](https://github.com/modularscale/modularscale-sass)
  ( MIT license:
  [https://github.com/modularscale/modularscale-sass/blob/2.x/license.md](https://github.com/modularscale/modularscale-sass/blob/2.x/license.md)
  )

The site is in general plain html+css, however in a couple of posts I
might use javascript for specific requirements (for example to show a
live terminal demo) and hosting it locally. The following are the
current packages I am using.

- [Webcomponents polyfills](https://www.webcomponents.org/polyfills/) ( BSD 3-clause license:
  [https://github.com/webcomponents/webcomponentsjs/blob/master/LICENSE.md](https://github.com/webcomponents/webcomponentsjs/blob/master/LICENSE.md)
  )
- [term.js](https://github.com/chjj/term.js) ( MIT license:
  [https://github.com/chjj/term.js/blob/master/LICENSE](https://github.com/chjj/term.js/blob/master/LICENSE)
  )
- [tty-player](http://tty-player.chrismorgan.info/) ( MIT license:
  [https://github.com/chris-morgan/tty-player/blob/master/LICENSE](https://github.com/chris-morgan/tty-player/blob/master/LICENSE)
  )

and I wish to thank to all the people that have worked on the above for
their excellent products and for choosing to release them under licenses
allowing me to use them. The initial version of the site was developed
using [Pelican](https://getpelican.com/), many thanks also to its
developers for their efforts.

The technique used on this site to generate the archive page was
described by Parsia Hakimian on his blog[^6], I have also followed posts by
Bryce Wray[^7] for various CSS/Hugo techniques. For dark mode articles by 
Wickert Ackerman[^8] and Ken Muse[^9] were very useful

The logo image on this page, which is also used for the main site's logo
background, has been sourced from Wikimedia [^1], other pictures are
shots I took myself. The images on this site have been compressed with
MozJPEG [^2] and Zopfli [^3] and diagrams have been created using Dia
[^4].

I am a back-end developer by trade, so hopefully the CSS theme I put
together renders properly in whatever browser you are using to access
this site, I have written ALT tags for all the pictures so the site
should be usable even if you are using a screen reader or text browser
in general, let me know if this is not the case.

Posts on this site have both a first-published-on date in the header, and
a changelog entry at the bottom right of the post, if changes
are required due to errata or other issues, information about the
modifications will be added to the relevant page's changelog.

LICENSE
-------

When writing posts I have always tried to give credit and link to sites
where I found particular ideas or techniques, let me know if I missed
anything, any other content written by myself is licensed under a
Creative Commons Attribution-NonCommercial-ShareAlike 4.0 (CC BY-NC-SA
4.0) License [^5]

DISCLAIMER
----------

As much as I have spent significant effort to make sure the instructions
provided here are correct, if you decide to follow them and something
bad happens, you are on your own: besides many steps that could end up
causing data loss, the security aspects of the installation rely on all
the software you are using not having any exploits, so if tomorrow a
VM-escape critical bug is discovered in VirtualBox, you will obviously
be at risk; security is always an ongoing exercise in balancing security
and convenience, the tradeoffs between the two are dependent on your
particular environment.

**THIS SITE AND ITS CONTENTS ARE PROVIDED "AS IS", WITHOUT WARRANTY OF
ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NON INFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SITE, ITS CONTENTS OR THE USE OR OTHER DEALINGS IN IT.**

[^1]: [https://commons.wikimedia.org/wiki/File:16_wood_samples.jpg](https://commons.wikimedia.org/wiki/File:16_wood_samples.jpg)

[^2]: [https://github.com/mozilla/mozjpeg/](https://github.com/mozilla/mozjpeg/)

[^3]: [https://github.com/google/zopfli/](https://github.com/google/zopfli/)

[^4]: [http://dia-installer.de/](http://dia-installer.de/)

[^5]: [http://creativecommons.org/licenses/by-nc-sa/4.0/](http://creativecommons.org/licenses/by-nc-sa/4.0/)

[^6]: [https://parsiya.net/blog/2016-02-14-archive-page-in-hugo/](https://parsiya.net/blog/2016-02-14-archive-page-in-hugo/)

[^7]: [https://www.brycewray.com/](https://www.brycewray.com/)

[^8]: [https://www.wiggy.net/posts/hugo-dark-mode/](https://www.wiggy.net/posts/hugo-dark-mode/)

[^9]: [https://www.kenmuse.com/blog/adopting-a-dark-theme-in-hugo](https://www.kenmuse.com/blog/adopting-a-dark-theme-in-hugo)