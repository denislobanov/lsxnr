---
title: "Dell Chromebook fan control - Part II: Calling ec code"
date: 2018-09-30T13:25:50+01:00
tags: ["ctempd", "chromebook", "engineering log"]
draft: false
---

Having figured out the surface details of how `ectool` sets fan speed, it's time for us to try to do the same on our own and begin building our little fan control daemon in the process.

<!--more-->

## Poor man's backtrace
Having established in the last post that *comm-dev.c*, *comm-i2c.c* and *comm-lpc.c* contain the `ec_command_proto` implementations that `cmd_fanduty()` actually calls, it's time to establish which implementation is used and why. This is where *comm-host.c* comes into play (I skipped over this file last time since it didn't look interesting in our grep output).

<br/>
Lets start with *comm-dev.c* like we did the last time - it's also the one I'm most hopeful will be the implementation since it looks like some neat and tidy `ioctl`s are all that's needed. There are a few functions defined in this file, but the one at the end is now of interest and key to figuring out which implementation is used on the live system - `comm_init_dev()`. A quick grep shows, as expected, that this is a design pattern:
```sh
comm-dev.c:int comm_init_dev(const char *device_name)
comm-host.c:int comm_init_dev(const char *device_name) __attribute__((weak));
comm-host.c:int comm_init_lpc(void) __attribute__((weak));
comm-host.c:int comm_init_i2c(void) __attribute__((weak));
comm-host.c:int comm_init_servo_spi(const char *device_name) __attribute__((weak));
comm-host.c:	if ((interfaces & COMM_DEV) && comm_init_dev &&
comm-host.c:	    !comm_init_dev(device_name))
comm-host.c:	if ((interfaces & COMM_SERVO) && comm_init_servo_spi &&
comm-host.c:	    !comm_init_servo_spi(device_name))
comm-host.c:	if ((interfaces & COMM_LPC) && comm_init_lpc && !comm_init_lpc())
comm-host.c:	if ((interfaces & COMM_I2C) && comm_init_i2c && !comm_init_i2c())
comm-i2c.c:int comm_init_i2c(void)
comm-lpc.c:int comm_init_lpc(void)
comm-servo-spi.c:int comm_init_servo_spi(const char *device_name)
```

<br/>
All three of our *comm-* implementation files have an "init" method and *comm-host.c* decides which to call. It's code contains some helpful comments too:
```c
/* Prefer new /dev method */
if ((interfaces & COMM_DEV) && comm_init_dev &&
    !comm_init_dev(device_name))
    goto init_ok;

if ((interfaces & COMM_SERVO) && comm_init_servo_spi &&
    !comm_init_servo_spi(device_name))
    goto init_ok;

/* Do not fallback to other communication methods if target is not a
 * cros_ec device */
if (strcmp(CROS_EC_DEV_NAME, device_name))
    goto init_failed;

/* Fallback to direct LPC on x86 */
if ((interfaces & COMM_LPC) && comm_init_lpc && !comm_init_lpc())
    goto init_ok;

/* Fallback to direct i2c on ARM */
if ((interfaces & COMM_I2C) && comm_init_i2c && !comm_init_i2c())
    goto init_ok;
```

<br/>
We know that our chromebook isn't running arm so the i2c implementation is out; the fight is between *comm-dev.c* and *comm-lpc.c*. I tried seeing if I could use some existing Linux tools to trace which functions are being called and found some backtracing libraries for C. However, I do not want to go and implement something so huge in this code base, a much simpler approach would be to put some `printf`s in the two files and run it on the target system. If I was more intelligent maybe I could read through the code and figure out which off the `COMM_` flags `if`s would evaluate to true in *comm-host.c*, probably something in the `board/samus/` dir would prove useful... But this was simpler and quicker; and I'm lazy :)
```sh
EC returned error result code 6
ec_command_lpc_3 is called
Fan duty cycle set.
```

<br/>
The error code thing is interesting, I'll have to take a look; and well, we have our result. Unfortunately it's not the nice way of `ioctl`s for me, we use the `ec_command_lpc3()` function defined in *comm-lpc.c*. This file uses `inb()` and `outb()` functions from `sys/io.h` to write bytes to a specific port, there's a bit of logic around setting up the data, headers and correct tx/rx. I don't particularly fancy copying this *ad verbum* so I think I will pursue the path of tweaking the ec Makefiles to give me a library with `ec_command()` that I can call.

<br/>
## Building the library
A static library would be nice here, but we already have all the bits in *Makefiles.rules* to give us *.so*'s so let's use that for now and make it nice later. I added a simple PHONY target to *Makefiles.rules* and how to build it in *build.mk*, it's a bit of a hack but I really wanted something simple and I think this can be boiled down even further, which would allow me to just patch one file before building; ideal considering that these aren't the sort of changes you would want to push upstream :)
```diff
diff --git a/Makefile.rules b/Makefile.rules
index e3d6e3164..2d549c718 100644
--- a/Makefile.rules
+++ b/Makefile.rules
@@ -229,6 +229,9 @@ hex: $(hex-y)
 .PHONY: utils-art
 utils-art: $(build-art)
 
+.PHONY: ctemp-lib
+ctemp-lib: $(out)/util/ctemp.so
+
 .PHONY: utils-host
 utils-host: $(host-utils)
 
diff --git a/util/build.mk b/util/build.mk
index ad9f5656c..72cb39a64 100644
--- a/util/build.mk
+++ b/util/build.mk
@@ -92,4 +92,7 @@ $(out)/util/export_taskinfo_ro.o: util/export_taskinfo.c
 $(out)/util/export_taskinfo_rw.o: util/export_taskinfo.c
        $(call quiet,c_to_taskinfo,BUILDCC,RW)

+$(out)/util/ctemp.so: $(foreach u,$(addsuffix .c,$(basename $(comm-objs))),util/$(u))
+       $(call quiet,link_taskinfo,BUILDLD,RW)
+
 deps-y += $(out)/util/export_taskinfo_ro.o.d $(out)/util/export_taskinfo_rw.o.d
```

You can see all the magic happens in *build.mk*, here we bastardise an existing variable to get us the list of files we want to build our library from - all those that `ectool` needs itself. If this works, we can clean it up further and just define the specific files we need which contain the implementation details we care about rather that everything with the kitchen sink, `ectool` does far more than just fan speed control..
```make
$(out)/util/ctemp.so: $(foreach u,$(addsuffix .c,$(basename $(comm-objs))),util/$(u))
```
All that we're doing here is taking all the *.o* files defined by the `comm-objs` var and renaming them to their *.c* equivalent (that-s the `basename` followed by the `addsufix` operation); then for each of these our `foreach` loop appends `util/` so that the build system can find the source files. Eventually we call `link_taskinfo` which is implemented by `cmd_link_taskinfo` in *Makefile.rules*: builds our source files and links them into a shared library:
```make
cmd_link_taskinfo = $(BUILDCC) $(BUILD_CFLAGS) --shared -fPIC $^ \
	$(BUILD_LDFLAGS) -flto -o $@
```

<br/>
## Sanity
**AAAlmost** ready to code, just need to make sure that what we build is, well, *something*. We can see an output file in `$(out)`:
```sh
build
└── samus
    ...
    └── util
        └── ctemp.so
```

So lets see if it contains any functions
{{< highlight sh "hl_lines=4 9">}}
$ nm ctemp.so
0000000000006da0 d _DYNAMIC
0000000000004230 T ec_cmd_version_supported
0000000000004170 T ec_command
0000000000003790 t ec_command_dev
0000000000003a10 t ec_command_dev_v2
0000000000002660 t ec_command_i2c
0000000000003260 t ec_command_lpc
0000000000002eb0 t ec_command_lpc_3
0000000000007190 B ec_command_proto
0000000000004180 T ec_get_cmd_versions
0000000000007168 B ec_inbuf
000000000000718c B ec_max_insize
0000000000007188 B ec_max_outsize
0000000000007170 B ec_outbuf
0000000000007178 B ec_pollevent
0000000000003da0 t ec_pollevent_dev
0000000000007180 B ec_readmem
0000000000003950 t ec_readmem_dev
0000000000003cc0 t ec_readmem_dev_v2
0000000000002380 t ec_readmem_lpc
0000000000007160 D _edata
00000000000071a8 B _end
{{< / highlight >}}

<br/>
## Writing some code
Now that we can build a shared library, it is time to gather all our Java Enterprise Design Pattern knowledge and build the best ObservableDelegateECCommandTestFactoryPoolManager to test this function call :) Well not quite, *ectool.c* already contains a function that makes a basic `ec_command` call: `cmd_hello()`; we can simply rip it out into our own file and see if we can build a standalone app that links into our library. So our new *.c* file looks something like this:  
```c
#include <stdio.h>
#include "comm-host.h"

int main(int argc, char *argv[])
{
	struct ec_params_hello p;
	struct ec_response_hello r;
	int rv;

	p.in_data = 0xa0b0c0d0;

	rv = ec_command(EC_CMD_HELLO, 0, &p, sizeof(p), &r, sizeof(r));
	if (rv < 0)
		return rv;

	if (r.out_data != 0xa1b2c3d4) {
		fprintf(stderr, "Expected response 0x%08x, got 0x%08x\n",
			0xa1b2c3d4, r.out_data);
		return -1;
	}

	printf("EC says hello!\n");
	return 0;
}
```

Clever stuff, though it fails to build. This failure is important and we will need to remember how we solve it when we are setting up a build system for our app (I renamed ctemp.so to libctemp.so):
```
$ gcc -I. -I../include/ -L../build/samus/util -l:ctemp.so -o test test.c
In file included from ../include/common.h:101,
                 from comm-host.h:12,
                 from test.c:2:
../include/config.h:3047:10: fatal error: config_chip.h: No such file or directory
 #include "config_chip.h"
          ^~~~~~~~~~~~~~~
compilation terminated.
```

<br/>
The problem is that *config_chip.h* depends on which hardware you are building for. The correct one is selected by the ec build system but our gcc command does not - in fact it knows nothing of the target platform. I will have to refresh my memory here and discover how this choice is made. Chip is defined by `build.mk` under **boards/samus**:
```make
CHIP:=lm4
```
Since this is a pretty simple var export we can try add **chip/lm4/** to the *gcc* include path, but this directory contains a *build.mk* of its own which defines `CORE` and `CFLAGS_CPU`. It's getting to that point where we will want procedurally pick up *build.mk*'s in our own build system; however we can now build our test file:
```
> x86_64-pc-linux-gnu-gcc -I. -I../include/ -I../chip/lm4/ -I.. -I../board/samus/ -I../test/ -L../build/samus/util -l:ctemp.so  -std=gnu90 \
-march=armv7e-m -mcpu=cortex-m4 -o test test.c  
```

To actually run our binary we need to do some pretty nasty stuff now, unless we want to install the *.so* into */usr/lib/*... Which is exactly what I did, but at the time I was too excited to write down the dirty hacks necessary. I'm not going to go back and figure out what I did because...

<br/>
## Failing
With our code compiled and written, it's execution leads us to a lovely Segfault which we can now enjoy. :) This occurs when we run call `ec_command`, which in turn tries to call `ec_command_proto` - a function pointer addressing 0x0000000000000000. The reason for this is because of a bug in my code above - this is what you get for copy-pasting! I copied the `cmd_hello()` implementation but completely forgot to check how/who calls `comm_init()`, so right now our `ec_command_proto` function pointer doesn't point to any implementation at all. The solution was pretty easy of course; look at `main()` and copy the bit that initialises our relevant communication implementing code
```c
int main(void) {
	char device_name[41] = CROS_EC_DEV_NAME;
	struct ec_params_hello p;
	struct ec_response_hello r;
	int rv;

    if (comm_init(COMM_LPC, device_name)) {
		fprintf(stderr, "Couldn't find EC\n");
        return -1;
	}

    //...
```

I took a little shortcut here, since we already know that - at least on my chromebook we are calling the *comm-lpc.c* implementation; not that it had taken us very far. `ectool` itself is built by calling `cmd_c_to_host` over all the "<host_util>-obj files" defined by `host-utils`; so in effect this make rule will try to build **and then link** all .c files defined in `ectool-obsj` into one executable `ectool`:
```make
$(host-utils): $(out)/%:$(host-srcs)
	$(call quiet,c_to_host,HOSTCC )

# ...

cmd_c_to_host = $(info $(HOSTCC) $(HOST_CFLAGS) $(HOST_LDFLAGS) -MMD -MF $@.d  -o $@ \
	         $(sort $(foreach c,$($(*F)-objs),util/$(c:%.o=%.c)) $(wildcard $*.c)))
```

This is a problem for our library, because *comm-host.c* only has function pointers to the various `comm_init_` functions. The linker makes these actually point to something, but in our static library we are just going to have a bunch of objects rolled into an archive with `ar`. The shared library approach might work a little better since `cmd_link_taskinfo` does link all the prerequisites into one file. However this is all starting to get a little out of hand, and I have been basterdising the *Makefiles* a fair bit now. The simplest approach feels like to go with CMake and have it pick up the *.o* files in *util/* and just link against them directly. This way I get one binary with everything it needs and no libraries to install on the target system.

</br>
#### Side note
For potential future reference, the full command to build *test.c* ended up like this (`$(info ...)` on one of the make recipes):
```
> x86_64-pc-linux-gnu-gcc -DOUTDIR=build/samus/ -DCHIP=lm4 -DBOARD_TASKFILE=ec.tasklist -DBOARD=samus -DCORE=cortex-m -DPROJECT=ec -DCHIP_VARIANT= \
-DCHIP_FAMILY= -DBOARD_SAMUS -DCHIP_LM4 -DCORE_CORTEX_M -DCHIP_VARIANT_ -DCHIP_FAMILY_ -DFINAL_OUTDIR=build/samus  -Iinclude  -Icore/cortex-m/include  -Icore/cortex-m \
-Ichip/lm4  -Iboard/samus  -Iboard/samus  -Icommon  -Ifuzz  -Ipower  -Itest  -Icts/common  -Icts/  -Ibuild/samus/gen  -Iprivate  -Icommon  -Icommon/vboot  -Idriver  \
-Idriver/battery  -Idriver/bc12  -Idriver/charger  -Idriver/led  -Idriver/ppc  -Idriver/tcpm  -Idriver/temp_sensor  -Ibuild/samus  -Ifuzz  -Itest  -I.     -DTEST_ec \
-DTEST_EC      -DSECTION_IS_ -DSECTION=  -g  -Wall  -Wundef -Wno-trigraphs -fno-strict-aliasing -fno-common -Werror-implicit-function-declaration -Wno-format-security \
-fno-strict-overflow -Wstrict-prototypes -Wdeclaration-after-statement -Wno-pointer-sign -DHOST_TOOLS_BUILD -MMD -MF -lm -o build/samus/util/test util/test.c \
-L$(pwd)/build/samus/util/ -lctemp
```

</br>
## Writing more Makefiles!
Seriously.. Still haven't written any of my own code yet! But at this point I have a better idea of how the *ec* build system works and I want to have a running `test` binary that can talk to the EC on my Chromebook before publishing this post. It shouldn't be too hard to do though, at this point we have pretty much everything we need - our simple test file and some Makefile modifications that can give us the *.o* files to link against; we also know enough of the *ec* build system to bend it to do this task for us.

#### 1. The PHONY target
This will build our `test` file and link it against all the `comm-objs`.
```make
.PHONY: ctemp-test
ctemp-test: $(out)/util/test
```

#### 2. The test target
This will build our `test` binary
```make
$(out)/util/test: 
	$(call ctemp_c_to_host,util/test.c,$(ctemp-srcs))
```

#### 3. The make function
Probably this can actually be in the test target recipe
```make
ctemp_c_to_host = $(HOSTCC) $(HOST_CFLAGS) $(HOST_LDFLAGS) -o $@ $(1) $(2)
```

#### 4. Profit
```
> make BOARD=samus ctemp-test
```

And voila! We have a working "hello world" of sorts that can talk to the **EC** on my Chromebook. Next time we write *even MORE* Makefiles, to get the *.o* files out of *util/*; then we set up a basic CMake project to build our test binary linking to "external" *.o* files. Once we can do that, we can start writing some actual code, knowing that we will be able to talk to hardware when we compile.

In the mean time I'm going to investigate some C++ unit testing frameworks.


[Part III >>>](https://lsxnr.com/post/ctemp-cmake/)
