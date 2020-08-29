---
title: "Dell Chromebook fan control - Part III: CMake"
date: 2019-08-22T14:28:00+01:00
tags: ["ctempd", "chromebook", "engineering log"]
draft: false
---

Round Three. Fight!

I feel like I'm finally unblocked on writing **ctempd**. I cant get the ec build
system to give me a nice library to link against, but I can get it to build a
bunch of *.o* files for me and link against them directly. This is the simplest
approach and I think it will do just well for now. I can always make my own
library layer that is linked against these and built into a static library or
something; alternatively I might revisit this problem again in the future and
see what the cleanest approach is. But for now I'm happy to just get to writing
some original code :)

<!--more-->

## お上がりよ!

So first thing's first, we need to set up a basic CMake project and structure
(it is at this point that I tried to evaluate a few build systems for C++, but
maybe I will write about this in a future blog post).

Our initial directory structure will be something like this:  

```sh
.
├── CMakeLists.txt
├── src
└── thirdpart
    ├── ec
    ├── ecConfig.cmake
    └── ec.patch
```  

No separate header "include" directory - as I dont need it yet.  

The `ec` directory can be a submodule or a subtree, containing the ec code. The
difference really comes down to how we want to have our *ec* changes applied; we
can either extract them into a `.patch` and apply them using `CONFIGURE_COMMAND`
in `ecConfig.cmake`, or we can apply them directly to the code, which we will
commit with our repository. On upstream updates we would either pull in the new
submodule and our patch would be applied each time we build from clean, or we
would rebase our subtree. I have purposely kept my changes small in the previous
posts because I intend to use a submodule & patch, however I may consider going
to a subtree if I feel like it would make the workflow cleaner.

Our top level `CMakeLists.txt` only needs to define some project globals and
where cmake should look for the rest of the code

```cmake
find_package(ec PATHS thirdparty thirdparty/ec NO_DEFAULT_PATH)
add_subdirectory(src)
```  

Define an external project in `ecConfig.cmake`; this is where all our hard work
from the past two posts will go:  

```cmake
include(${CMAKE_ROOT}/Modules/ExternalProject.cmake)
ExternalProject_Add(ectool
    SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/ec
    CONFIGURE_COMMAND  patch -p0 < ../ec.patch
    BUILD_COMMAND make BOARD=samus -j9
    INSTALL_COMMAND cmake -E echo "Skipping install step."
    BUILD_IN_SOURCE 1
    PREFIX=${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/ec/
)
```  
You'll notice we're already including out patch file here in the
`CONFIGURE_COMMAND` - _ec.patch_. More on to this later.  

We will need to tell cmake where it can find our built files, so we finish off
`ecConfig.cmake` with the following:

```cmake
ExternalProject_Get_Property(ectool source_dir)

set(EC_INCLUDE_DIRS ${source_dir} ${source_dir}/include ${source_dir}/util
                    ${source_dir}/chip/lm4/ ${source_dir}/board/samus
                    ${source_dir}/test)

file(GLOB ec_objs ${source_dir}/build/samus/RW/util/export_taskinfo.so
    ${source_dir}/build/samus/RW/util/export_taskinfo.rw.o)
add_library(ec SHARED IMPORTED ${ec_objs})

set_target_properties(ec PROPERTIES LINKER_LANGUAGE C 
    IMPORTED_LOCATION ${source_dir}/build/samus/util/export_taskinfo.so
    EXTERNAL_OBJECT true GENERATED true)
```  

## Intermission  

It's been a while since I have returned to this project. In the mean time I
moved my main system to Gentoo and have reinstalled Arch on my chromebook. The
reinstall has caused some issues as the _ectool-samus-git_ aur package no longer
builds, it's easy to get going though. The _PKGBUILD_ still has the `-j5` flag
in it as I have forgotten to submit a PR to fix that xD but now there is more
reason to do so: the arm gcc toolchain install directories have changed on arch
and the _ectool_ build system stil has hardcoded paths; as you can see here:

```sh
% grep "arm-eabi" * -R                                                                                    
board/fluffy/build.mk:	/opt/coreboot-sdk/bin/arm-eabi-)
core/cortex-m/build.mk:	/opt/coreboot-sdk/bin/arm-eabi-)
core/cortex-m0/build.mk:	/opt/coreboot-sdk/bin/arm-eabi-)
Makefile.rules:	@echo "  make BOARD=reef CROSS_COMPILE_arm='arm-eabi-'"
```

The result of this is something like following error when trying to build (I
disable ccache here so we have `/bin/sh` instead):

```
/bin/sh: /opt/coreboot-sdk/bin/arm-eabi-objcopy: No such file or directory
```

*However* `docs/getting_started_quickly.md` does have a nice snippet that
basically solves this problem `HOSTCC=x86_64-linux-gnu-gcc make BOARD=$board` -
so all we need to do is to pass our own `HOSTCC` environment variable to make.
We can test this by simply running (set `-j` flags to your pleasure):  

```sh
HOSTCC=arm-none-eabi-gcc make BOARD=samus
```  

## That's... All?

As I said, I took a while to move my main system off of Arch and onto Gentoo (I
wanted ZFS on root without creating a custom arch install iso) so that has ended
up taking a fair bit of my life; and probably it will take more of my life still
as I moved to testing, the current ZFS kernel module does not support 5.2.x
kernels, and for whatever reason my nvidia module refuses to work (well, we all
know the reason).

Rather than sitting on this post for any longer (Most of the above has been
written on the 5th October!), I decided to publish it as it is and simple have a
part IV later :)

Ciao! Grazie!
