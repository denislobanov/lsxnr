---
title: "Urho3d Empty Project"
date: 2018-12-13T12:49:23+06:00
tags: ["Urho3D"]
draft: false
---

There are a few resources online for setting up an empty project in Urho3D - even a github repo by the same name [Urho3D-Empty-Project](https://github.com/ArnisLielturks/Urho3D-Empty-Project), but after having tried myself to create a basic "hello world" from scratch, I found them to either be a misnomer (as in the case of the _"empty project"_ repo) or incomplete. This assumes you are going to use the Urho3D CMake build system as much as possible.

<!--more-->

## Base repository
The [Using Urho3D library](https://urho3d.github.io/documentation/1.7/_using_library.html) official documentation page provides a decent starting point, that I'm essentially going to elaborate on, borrowing a little bit from the [Urho3D-Empty-Project](https://github.com/ArnisLielturks/Urho3D-Empty-Project) (which sadly is far more than an empty project) repo as needed.

1. Clone the Urho3D [source repository](https://github.com/urho3d/Urho3D), we will copy the build system out from here (plus some basic resources).
1. Copy the **CMake** and **scripts** directories from Urho's sources into your project.
1. ```mkdir -p bin/Data```
1. Copy the **CoreData** dir from Urho3D's source **bin** directory.
1. `mkdir Source` - you can tweak **CMakeLists.txt** afterwards to rename this to `src`..

## CMakeLists.txt
Again, the official documentation page gives you a head start on what you need, but you do need to tweak it and maybe borrow some things from the "Empty Project" repo. Consider something like this:
```cmake
# no whitespaces
project (MyProjectName)

cmake_minimum_required (VERSION 3.2.3)
if (COMMAND cmake_policy)
    # Libraries linked via full path no longer produce linker search paths
    cmake_policy (SET CMP0003 NEW)
    # INTERFACE_LINK_LIBRARIES defines the link interface
    cmake_policy (SET CMP0022 NEW)
    # Disallow use of the LOCATION target property - so we set to OLD as we still need it
    cmake_policy (SET CMP0026 OLD)
    # MACOSX_RPATH is enabled by default
    cmake_policy (SET CMP0042 NEW)
    # Honor the visibility properties for SHARED target types only
    cmake_policy (SET CMP0063 OLD)
endif ()

# Set CMake modules search path
set (CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/CMake/Modules)

# Include UrhoCommon.cmake module after setting project name
include (UrhoCommon)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY bin)

file(GLOB_RECURSE SRCS src/*.cpp)
file(GLOB_RECURSE HDRS include/*.h)

# Find Urho3D library
find_package (Urho3D REQUIRED)
include_directories (${URHO3D_INCLUDE_DIRS})

# Define target name
set (TARGET_NAME MyProjectBinaryName)

define_source_files (GLOB_CPP_PATTERNS Source/*.c* GLOB_H_PATTERNS Source/*.h* RECURSE GROUP)

set(INCLUDE_DIRS include)

setup_main_executable ()

ADD_DEFINITIONS(
    -std=c++17 # for example
)
```

## Building
You should probably use one of the scripts inside the **scripts** dir; there provide ways to build for other platforms (for example if you have automated builds for multiple platforms), though you can also just do the manual  
`mkdir build;cd build;cmake ..;make`  

Though **script/cmake_generic.sh** is the equivalent.
