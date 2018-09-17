---
title: "Change resolution and renderer in Homeworld under wine"
date: 2018-09-16T18:51:41+01:00
draft: false
tags: ["wine", "linux", "gaming"]
---

There are very few computer games that I think have *really* captured my imagination, Homeworld is one of them. I still have the original CD and box so I though it best to clone it for safekeeping. So after borrowing a USB CD drive and running `dd` I decided to launch it for some nostalgia. Turns out though you can't change the resolution in-game due to a wine bug, two in fact:  
[Bug 23714 - Homeworld : Can't change resolution](https://bugs.winehq.org/show_bug.cgi?id=23714)  
[Bug 38763 - Homeworld hangs when changing screen resolution or switching renderer](https://bugs.winehq.org/show_bug.cgi?id=38763)  

<br/>
However running a game at 640 on a 32" 2K monitor is a bit... Too nostalgic. :) We can work around this bug by forcing *homeworld.exe* to start at our desired resolution, and with a different renderer rather than switching later; and we can make it convenient by setting this in the registry. You can run `wine homeworld.exe /help` to see all your options:
<br/>
<br/>
```
Invalid or unrecognised command line option: '/help'

SYSTEM OPTIONS
    /heap <n> - Sets size of global memory heap to [n].
    /prepath <path> - Sets path to search for opening files.
    /CDpath <path> - Sets path to CD-ROM in case of ambiguity.

PROCESSOR OPTIONS
    /enableSSE - allow use of SSE if support is detected.
    /forceSSE - force usage of SSE even if determined to be unavailable.
    /enable3DNow - allow use of 3DNow! if support is detected.

SOUND OPTIONS
    /dsound - forces mixer to write to DirectSound driver, even if driver reports not certified.
    /dsoundCoop - switches to co-operative mode of DirectSound (if supported) to allow sharing with other applications.
    /waveout - forces mixer to write to Waveout even if a DirectSound supported object is available.
    /reverseStereo - swap the left and right audio channels.

DETAIL OPTIONS
    /rasterSkip - enable interlaced display with software renderer.
    /noBG - disable display of galaxy backgrounds.
    /noFilter - disable bi-linear filtering of textures.
    /noSmooth - do not use polygon smoothing.
    /stipple - enable stipple alpha with software renderer.
    /noShowDamage - Disables showing ship damage effects.

VIDEO MODE OPTIONS
    /safeGL - don't use possibly buggy optimized features of OpenGL for rendering.
    /triple - use when frontend menus are flickering madly.
    /nodrawpixels - use when background images don't appear while loading.
    /noswddraw - don't use DirectDraw for the software renderer.
    /noglddraw - don't use DirectDraw to setup OpenGL renderers.
    /sw - reset rendering system to defaults at startup.
    /noFastFE - disable fast frontend rendering.
    /fullscreen - display fullscreen with software renderer (default).
    /window - display in a window.
    /noBorder - no border on window.
    /640 - run at 640x480 resolution (default).
    /800 - run at 800x600 resolution.
    /1024 - run at 1024x768 resolution.
    /1280 - run at 1280x1024 resolution.
    /1600 - run at 1600x1200 resolution.
    /device <dev> - select an rGL device by name, eg. sw, fx, d3d.
    /nohint - disable usage of OpenGL perspective correction hints.

TEXTURES
    /nopal - disable paletted texture support.

MISC OPTIONS
    /pilotView - enable pilot view.  Focus on single ship and hit Q to toggle.
```

<br/>
So first step is to run iw with something other than `sw`:
```sh
wine homeworld.exe /disableAVI /device d3d /1600
```

<br/>
Quit once it starts. The relevant registry entries have been added, now we just tweak them (some lines removed):
```
[HKEY_LOCAL_MACHINE\Software\Wow6432Node\Sierra On-Line\Homeworld]
"d3dToSelect"=""
"deviceToSelect"="d3d"
"glToSelect"="rgl.dll"
"screenDepth"=dword:00000020
"screenHeight"=dword:000005a0
"screenWidth"=dword:00000a00
```

<br/>
The pertinent ones are `"deviceToSelect"="d3d"`, which gets us using **D3D** (I will need to explore getting OGL to work next), `"screenDepth"=dword:00000020` which gives us 32 bit depth, and `screenWidth` & `screenHeigh` which I've set to 2560x1440. Of course, you can now just add these registery keys yourself and not bother with the CLI options, but I do suggest trying `/pilotView` if you haven't :)

##### Edit: At 2k Homeworld starts to struggle, I'm getting mouse pointer trails everywhere... Maybe I'll buy Homeworld Remastered (and upgrade to some 4K monitors), if it can run on Linux. In fact I found that this is a problem under all resolutions above 1600x1200 that I tried.
