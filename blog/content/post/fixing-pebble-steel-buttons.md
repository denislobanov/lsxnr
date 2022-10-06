---
title: "Fixing Pebble Steel Buttons"
date: 2019-03-24T22:09:47Z
tags: ["hardware", "pebble"]
---

I have an old Pebble Steel that has gone unused for a long time because two of
the three buttons on the right hand side have stopped working. There is a post
on reddit talking about how to fix this, but the original forum thread with
pictures is gone (actually the whole forum appears to be gone), so I though I
would take some and make a little writeup. Possibly you will find this through
google and it may help someone; the process is easier than I thought!  

For reference, the original reddit post is
[here](https://www.reddit.com/r/pebble/comments/5p2jwz/fixing_nonresponsive_buttons_on_pebble_steel/);
we shall fix both the screen tearing and buttons. The proceadure is pretty
straightforward - to fix the buttons an additional wire is soldered onto the
ribbon connecting the buttons, which allows signals from the top 2 buttons to
be sent back to the pebble motherboard.  

## Remove the innards

I didn't take any pictures of this, however you will need a torx head to remove
the 4 bolts on the back of the Pebble Steel (PS). When removing the back cover
be mindful of the fact that the vibrator assembly is glued to it and you will
need to be careful to not damage the wiring. Having removed the back you can
remove the main assembly which is all held together in the black plastic tray.
Look for little tabs on the side of the tray, just visible above the edgeline
of the pebble - put a flat screwdriver in and pivot to lift up. It should look
like this:

![the frame](/images/pebble/buttons.jpg#centered-post)  

## Connecting to TP4

The image above shows the correct orientation to consider for the `bottom left`
contact on the button, TP4 is at the bottom on the same side. Before soldering
a wire on you will need to remove the insulation tape around that area - its
just a small block of yellow translucent tape, pry it off with some pliers. My
advice at this point is to also cover the white backlight screen to avoid
damaging it or any accidental spillages of flux or solder. Masking tape will do
fine, you can stick something to the other side of the tape to prevent it from
sticking to the _screen_ itself.  

![bypassed](/images/pebble/bypassed_wiring.jpg#centered-post)

I do not have any insulation on my wiring, the distance is so short I think it
would melt during the process; you can also see that the guage of the wiring is
maybe a bit too thick for the job. It's hard to tell if I have a dry joint or
not at this point, so some testing will be needed. I advise using a lower gauge
of wire if you can (though this was already hard enough for me); use tweezers
to hold it whilst you solder and cut afterwards.  

## Insulating

I dont want this wire to short to anything so I put the yellow insulation tape
previously removed, _underneath_ the bypass wire. Then I cut a small section of
masking tape and taped over the top. Slightly janky but this does keep
everything insulated.

![janky insulation](/images/pebble/insulated.jpg#centered-post)  

## Assembly, screen tearing

We can put a work-around for the screen tearing now; but first put the frame
back into the metal watch housing. You can cut a strip of paper and fold it a
few times, then put it between the pebbles innards and the back of the watch
case; then screw everything down. It's as simple as that and appears to have
solved the screen tearing issue (I have now tested for a few days).

![working watch](/images/pebble/working.jpg#centered-post)

Congratulations! We now have a working watch! There are of course no more
pebble servers so you'll need to do something on the software side. If you
haven't already you have two options:

1. The [rebble.io surrogate backend](http://rebble.io/), this replaces the
   backend servers provided by pebble allowing you to continue to use the
   pebble app. Things to note: you must register via an SSO provider (facebook,
   twitter, google or github), the default pebble design lets the app know
   *everything* and sends it to this backend.

2.
   [Gadetbridge](https://codeberg.org/Freeyourgadget/Gadgetbridge/wiki/Pebble-Getting-Started),
   this is an alternative to the pebble app but leverages the "appstore"
   [provided by rebble](https://apps.rebble.io). Things to note: gadgetbridge
   does not allow internet connectivity from the watch, but it can proxy *some*
   things and only for [*some*
   apps](https://github.com/Freeyourgadget/Gadgetbridge/issues/482) that have
   it explicity.

