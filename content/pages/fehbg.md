+++
type = "code"
title = "fehbg"
description = ""
tags = [
]
date = "2017-12-30T14:04:35-08:00"
categories = [
]
shorttitle = "fehbg"
changelog = [ 
    "Initial release - 2017-12-30",
]
+++

This quick & dirty script will enable having different backgrounds on
different monitors, the script shown here works on 4 monitors, but it can
easily be modified, just change the resolutions and remove some concatenations
if you have less. This [was discussed here]({{< ref "i3-part-1.md#fehbg" >}})

This requires [feh to be installed](https://feh.finalrewind.org/) as well as
[Imagemagick](https://www.imagemagick.org/script/index.php). Note it will run
in tmpfs for speed reasons

[link to the source file](/code/fehbg.txt)

{{< highlight bash "linenos=table" >}}
#!/bin/bash
# Adapted from http://ubuntuforums.org/archive/index.pho/t-964558.html
# which does not seem to exist anymore.
WPDIR="$HOME/Pictures/wallpapers"
AX=1920
AY=1200
BX=1680
BY=1050
CX=2560
CY=1440
DX=1920
DY=1080

TEMP_DIR=/run/user/$(id -u)
ATEMP=$TEMP_DIR/dualbackgroundA.$$.$RANDOM
BTEMP=$TEMP_DIR/dualbackgroundB.$$.$RANDOM
CTEMP=$TEMP_DIR/dualbackgroundC.$$.$RANDOM
DTEMP=$TEMP_DIR/dualbackgroundD.$$.$RANDOM

files=( "$WPDIR/"* )

# From http://stackoverflow.com/questions/701505/
FIRST="${files[RANDOM % ${#files[@]}]}"
SECOND="${files[RANDOM % ${#files[@]}]}"
THIRD="${files[RANDOM % ${#files[@]}]}"
FOURTH="${files[RANDOM % ${#files[@]}]}"

# Resize images and store in temp directory
convert "$FIRST" \
-resize x${AY} -resize "${AX}x<" \
-gravity center -crop ${AX}x${AY}+0+0 +repage "$ATEMP"

convert "$SECOND" \
-resize x${BY} -resize "${BX}x<" \
-gravity center -crop ${BX}x${BY}+0+0 +repage "$BTEMP"

convert "$THIRD" \
-resize x${CY} -resize "${CX}x<" \
-gravity center -crop ${CX}x${CY}+0+0 +repage "$CTEMP"

convert "$FOURTH" \
-resize x${DY} -resize "${DX}x<" \
-gravity center -crop ${DX}x${DY}+0+0 +repage "$DTEMP"

# Join images to output file
montage "$ATEMP" "$BTEMP" "$CTEMP" "$DTEMP" -mode Concatenate -tile x1 -gravity north "$TEMP_DIR/final.jpg"

# And have feh display them
feh --no-xinerama --bg-center "$TEMP_DIR/final.jpg"

# Remove temporary files from tmpfs and move the final result to /tmp
rm "$ATEMP"
rm "$BTEMP"
rm "$CTEMP"
rm "$DTEMP"
cp "$TEMP_DIR/final.jpg" /tmp/
rm "$TEMP_DIR/final.jpg"
{{< / highlight >}}
