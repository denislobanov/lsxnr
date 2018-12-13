---
title: "Dell Chromebook fan control - Part III: CMake"
date: 2018-10-05T08:12:49+01:00
tags: ["ctempd", "chromebook", "engineering log"]
draft: true
---

Round Three. Fight!

<br/>
I feel like I'm finally unblocked on writing **ctempd**. I cant get the ec build system to give me a nice library to link against, but I can get it to build a bunch of *.o* files for me and link against them directly. This is the simplest approach and I think it will do just well for now. I can always make my own library layer that is linked against these and built into a static library or something; alternatively I might revisit this problem again in the future and see what the cleanest approach is. But for now I'm happy to just get to writing some original code :)

## お上がりよ!

So first thing's first, we need to set up a basic CMake project and structure (it is at this point that I tried to evaluate a few build systems for C++, but maybe I will write about this in a future blog post).

Our initial directory structure will be something like this:  
```
.
├── CMakeLists.txt
├── src
└── thirdpart
    ├── ec
    ├── ecConfig.cmake
    └── ec.patch
```  
No separate header "include" directory - as I dont need it yet.  

The `ec` directory can be a submodule or a subtree, containing the ec code. The difference really comes down to how we want to have our *ec* changes applied; we can either extract them into a `.patch` and apply them using `CONFIGURE_COMMAND` in `ecConfig.cmake`, or we can apply them directly to the code, which we will commit with out repository. On upstream updates we would either pull in the new submodule and our patch would be applied each time we build from clean, or we would rebase our subtree. I have purposely kept my changes small in the previous posts because I intend to use a submodule & patch, however I may consider going to a subtree if I feel like it would make the workflow cleaner.

Top level `CMakeLists.txt` only needs to define some project globals and where cmake should look for the rest of the code
```cmake
find_package(ec PATHS thirdparty thirdparty/ec NO_DEFAULT_PATH)
add_subdirectory(src)
```  

Define an external project in `ecConfig.cmake`:  
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



```
ExternalProject_Get_Property(ectool source_dir)

set(EC_INCLUDE_DIRS ${source_dir} ${source_dir}/include ${source_dir}/util
                    ${source_dir}/chip/lm4/ ${source_dir}/board/samus
                    ${source_dir}/test)
#
#file(GLOB ec_objs ${source_dir}/build/samus/RW/chim/lm4/*.o 
#    ${source_dir}/build/samus/RW/common/*.o
#    ${source_dir}/build/samus/RW/core/cortex-m/*.o
#    ${source_dir}/build/samus/RW/driver/*.o
#    ${source_dir}/build/samus/RW/power/*.o) 
#

file(GLOB ec_objs ${source_dir}/build/samus/RW/util/export_taskinfo.so
    ${source_dir}/build/samus/RW/util/export_taskinfo.rw.o)
add_library(ec SHARED IMPORTED ${ec_objs})

#target_include_directories(ec PRIVATE ${EC_INCLUDE_DIRS})
set_target_properties(ec PROPERTIES LINKER_LANGUAGE C 
    IMPORTED_LOCATION ${source_dir}/build/samus/util/export_taskinfo.so
    EXTERNAL_OBJECT true GENERATED true)
```
