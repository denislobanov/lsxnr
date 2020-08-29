---
title: "Forcing systemd initramfs to boot into recovery shell"
tags: ["linux", "systemd"]
date: 2017-11-04T19:19:51Z
draft: false
---

I have been trying to debug an initramfs hook that I wrote, which wasnt doing
what I wanted it to (namely it did literally nothing at all). Some debugging was
in order. I wanted get into the initramfs image environment and see what was
going on and what assumptions I have made that turned out to be incorrect.

<!--more--> However, I am using a systemd based initramfs image so the
[usual](http://jlk.fjfi.cvut.cz/arch/manpages/man/mkinitcpio.8#EARLY_INIT_ENVIRONMENT)
`break[=<premount|postmount>` or the legacy `break=y` wont work. Instead I had
to add a [systemd specific](https://freedesktop.org/wiki/Software/systemd/Debugging/)
kernel parameter:

```cfg
systemd.unit=emergency.target
```

Now I need to figure out how to get it to boot into a shell like before mounting
root (like `break=premount` does).

