---
title: "Dell Chromebook fan control - Part I: The ec build system"
date: 2018-09-15T15:55:17+01:00
draft: false
tags: ["ctempd", "chromebook", "engineering log"]
---

I have an old Dell Chromebook 11 that I rather like and use. It's pretty good
for what it is or at least it was at the time when it came out, I haven't looked
at the market to say whether or not that still hold true; it came with an Intel®
Pentium® 3556U CPU and 4G of RAM. However it also came with one massive
drawback: an over-zealous fan controller and a small high pitched fan. A common
complaint for this laptop is that the fan comes on too early (from 38C on) and
quickly ramps up to full speed (46C). This makes the Chromebook needlessly
noisy.

Turns out Intel have released a tool for interacting with the Chromium Embedded
Controller - ectool. One of the functions that this tool has is controlling the
fan speed *directly*. Now having a terminal open and remembering to set the fan
speed higher and lower is a potential solution (or even assigning keyboard
shortcuts), but its not very elegant. I know more than once I forgot to up the
fan speed whilst outputting high def video on HDMI; this taxes the Chromebook
quite a bit and I don't want it to overheat. So a little daemon to do this is
userland would be better.

##### NB: Doing this in kernel land would be even better still, and having a hardware watchdog that would ramp the fan speed up should there be a lockup would be even better. But right now I cant think of an adequate solution for this, so a userland daemon will have to do. It's risky if it crashes or the system locks up.  

## The build system - prerequisites  

Before I decide on the language for this project and thus the build system it
will use, it's best to have a look at `ectool` itself - the way in which its
built and written would dictate the path of least resistance for my own project.
My first step was cloning `ectool-samus-git` from the Arch Linux User Repository
(AUR), and having a look at how `ectool` is built on my platform. This also
nicely provides me with the list of build tools that I will need. A simple
`makepgk -s` will suffice here.  

It's a pretty straighforward `PKGBUILD`, we can see that in the `build()` hook
one substitution is needed:

```make
sed -i "s/-Werror /-std=gnu90 /g" Makefile.toolchain
```  

There is a little bug on the next line too, we build using:

```make
make PREFIX=/usr -j5 BOARD=samus
```

This is fine for 4 core systems, however my desktop has 8 and I would like to
use more. If I build this on my chromebook, it only has 2 cores so `j5` would
actually launch more make processes than is optimal for my system. This
parameter is an optimisation and should be left to the users system
configuration in `/etc/makepkg.conf`. I will need to submit a PR or something on
this AUR package to fix it...

## Building ectool  

Build output is inside the `build` directory and looks something like this:

```sh
build
└── samus
    ├── ec_version.h
    ...
    └── util
        ├── cbi-util
        ├── cbi-util.d
        ├── ec_parse_panicinfo
        ├── ec_parse_panicinfo.d
        ├── ec_sb_firmware_update
        ├── ec_sb_firmware_update.d
        ├── ectool
        ├── ectool.d
        ├── ec_uartd
        ├── ec_uartd.d
        ├── export_taskinfo_ro.o
        ├── export_taskinfo_ro.o.d
        ├── export_taskinfo_rw.o
        ├── export_taskinfo_rw.o.d
        ├── export_taskinfo.so
        ...
```  

So `ectool` is a "util", interestingly some libraries are also built.  

## Exploring ec Makefiles  

The main files of interest are *Makefile.rules* and *util/build.mk*. Figuring
out whats going on exactly will take you on a fantastic adventure through the
whole repo but hopefully I'll mention enough to provide a guide for quick
traversal.

*Makefile.rules* defines a PHONY `utils` target. `utils-host` builds ectool,
`utils-art` gives us the *export_taskinfo.so* library. Lets look at utils-host
first, in *Makefile.rules*; this depends on `host-utils`, which will build
sources defined by `host-srcs`:

```make
$(foreach u,$(host-util-bin),$(sort $($(u)-objs:%.o=util/%.c) $(wildcard util/$(u).c)))
```

This foreach loop is interesting, it hides some magic in the `sort` block. Sort
just takes a space separated list so we are actually conjugating two lists here,
both of which are built by the foreach loop from the list defined by
`host-util-bin` in *build.mk*.

The first list takes each element of `host-util-bin` and appends `-objs` to it,
this will be important later when we look at *ectool.c* code. The second list
prepends `util/` and appends `.c`. This gives us a list of source files to build
executables out of and allows *build.mk* to define targets for building their
dependencies. We can have a look at what the sorted loop looks like by adding
`$(info ${host-srcs})` to the `$(host-utils):` make block and the output should
look something a little like this:  

 ```
util/comm-dev.c util/comm-host.c util/comm-i2c.c util/comm-lpc.c util/ec_flash.c util/ec_panicinfo.c util/ectool.c util/ectool_keyscan.c util/lock/android.c util/lock/file_lock.c util/lock/gec_lock.c util/misc_util.c util/comm-dev.c util/comm-host.c util/comm-i2c.c util/comm-lpc.c util/lbplay.c util/lock/android.c util/lock/file_lock.c util/lock/gec_lock.c util/misc_util.c util/stm32mon.c util/comm-dev.c util/comm-host.c util/comm-i2c.c util/comm-lpc.c util/ec_sb_firmware_update.c util/lock/android.c util/lock/file_lock.c util/lock/gec_lock.c util/misc_util.c util/powerd_lock.c util/lbcc.c util/ec_panicinfo.c util/ec_parse_panicinfo.c
```

`utils-art` builds a shared library, convinient since I want a library
containing all the things that `ectool` calls into to change fan speeds (will
mention code exploration later); here we call `build-art` which simply adds the
build destination to all objects defined in `build-util-art`:

```make
$(foreach u,$(build-util-art),$(out)/$(u))
```  

The interesting things happen in `build.mk`, we define how to build 
`export_taskinfo.so` (in `$out`) here:

```make
$(out)/util/export_taskinfo.so: $(out)/util/export_taskinfo_ro.o \
        $(out)/util/export_taskinfo_rw.o
$(call quiet,link_taskinfo,BUILDLD)
```  

The other two `.o` files are defined on the following lines, but the `$(call` is
interesting. `link_taskinfo` can be found in *Makefiles.rules* again, I can't
remember the process I went through to find how `call` works so will have to
update this post later. It will however call into `cmd_link_taskinfo` in
*Makefiles.rules*:

```make
cmd_link_taskinfo = $(BUILDCC) $(BUILD_CFLAGS) --shared -fPIC $^ \
	$(BUILD_LDFLAGS) -flto -o $@
```

This gives us a shared library (.so). We'll have to write our own "cmd" to build
static libraries, but for now this is enough to experiment and see if we can
build something that will let us call into ec and control the fan.

## Code exploration  

I've had my vegitables, time for the meat; we start at *ectool.c*. It has the
contents of its -h output at the top, setting fan speed is handled by the
`fanduty` param, and we can see which functions map to which cli args in the
command struct

```c
/* NULL-terminated list of commands */
const struct command commands[] = {
{"autofanctrl", cmd_thermal_auto_fan_ctrl},
//...
{"fanduty", cmd_fanduty},
```

Looking through `cmd_fanduty()` tells us to be aware of a few considerations:

```c
int cmdver = 1;

if (!ec_cmd_version_supported(EC_CMD_PWM_SET_FAN_DUTY, cmdver)) {
```

There are different ec command versions, maybe this is to support other boards
or maybe it also relates to different revisions of the same board. I will need
to research this a little bit to see if it impacts `samus` - our chromebook
board name. Also we can see that this utilitiy supports setting the speed of
multiple fans

```c
num_fans = get_num_fans();
```

Eventually the magic is called here:

```c
rv = ec_command(EC_CMD_PWM_SET_FAN_DUTY, cmdver,
        &p_v0, sizeof(p_v0), NULL, 0);
```

This function is defined above and calls an `extern` function - so that we can
link different implementation depending on board hardware I guess

```c
int (*ec_command_proto)(int command, int version,
			const void *outdata, int outsize,
			void *indata, int insize);

int ec_command(int command, int version,
	       const void *outdata, int outsize,
	       void *indata, int insize)
{
	/* Offset command code to support sub-devices */
	return ec_command_proto(command_offset + command, version,
				outdata, outsize,
				indata, insize);
}
```  

A little grep gives interesting results:

```sh
> grep ec_command_proto * -R
comm-dev.c:		ec_command_proto = ec_command_dev_v2;
comm-dev.c:		ec_command_proto = ec_command_dev;
comm-host.c:int (*ec_command_proto)(int command, int version,
comm-host.c:	return ec_command_proto(command_offset + command, version,
comm-host.h: * ec_command_proto().
comm-host.h:extern int (*ec_command_proto)(int command, int version,
comm-i2c.c:	ec_command_proto = ec_command_i2c;
comm-lpc.c:		ec_command_proto = ec_command_lpc_3;
comm-lpc.c:		ec_command_proto = ec_command_lpc;
```

Looks like *comm-dev.c* is doing some magic, along with *comm-i2c.c* and
*comm-lpc.c*. I don't know which of these is actually doing the work when
running on my Chromebook. All three are listen in the `comm-objs` var, which is
appended to `ectool-objs`, which is going to be part of `build-srcs` due to that
`foreach` loop mentioned above. So we know these will always be built regardless
of platform. Lets investigate *comm-dev.c* because it was listen first; grep
output may already be sheding some potential light on this `cmdver` thing:

```c
if (ec_dev_is_v2()) {
    ec_command_proto = ec_command_dev_v2;
    ec_cmd_readmem = ec_readmem_dev_v2;
} else {
    ec_command_proto = ec_command_dev;
    ec_cmd_readmem = ec_readmem_dev;
}
```

I dont know which one it will be for my board and the decision is made at
runtime, I will need to explore this later with radare2. Looking over
`ec_command_dev2()`, just because it's the first one, we can see that in the end
it's just an ioctl call

```c
memcpy(s_cmd->data, outdata, outsize);

r = ioctl(fd, CROS_EC_DEV_IOCXCMD_V2, s_cmd);
```

I can't say this is surprising, but it is a nice result since theoretically that
means I don't actually need much in the way of dependencies for my little
daemon - I can make ioctl calls too! Incidentally `ec_command_dev()` is nothing
surprising either

```c
r = ioctl(fd, CROS_EC_DEV_IOCXCMD, &s_cmd);
```  

Interesting though is that `s_cmd` here passed by reference than by value. I
thought it was a bug until I realised that in `ec_command_dev()` s_cmd is
declared as:

```c
struct cros_ec_command s_cmd;
```  

And in ec_command_dev2 its

```c
struct cros_ec_command_v2 *s_cmd;
```  

Well at least it made me familiarise myself with the man page for `ioctl` again.
Next up is `comm-i2c`; here things are made simpler by

```c
ec_command_proto = ec_command_i2c;
```  

Here we do a bunch of house keeping but the code comments get the point tersely across:

```c
/* send command to EC and read answer */
ret = ioctl(i2c_fd, I2C_RDWR, &data);
```  

A bit more complex, but still an `ioctl`.

Finally `comm-lpc.c` is a bit different. I think it might be bitblasting, but I
dont really want to spend too much time on code right now, there is a more
important question that I brushed over which I will have to answer now - which
one of these implementation functions actually gets called (remember we just
have `ec_command_proto()` everywhere else), and who does the linking? Truthfully
I think the first time I looked over this I went into the deep end and found the
answer in the build system (I *think* `board.h` in `board/samus/` provides the
clue, but no longer can I remember). It's probable that we will have to revisit
this topic when we start implemention, but for now - for this post - it will
suffice...

[Part II >>>](https://lsxnr.com/post/ctemp-ec-lib/)

##### It is at this point that I realise that these theme isn't great for technical posts, but I will try to tweak it...
