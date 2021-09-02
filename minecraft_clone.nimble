import os
import strformat

version = "0.0.1"
author = "Phargo Bikcin"
description = "Obiwac's Minecraft clone in Nim "
license = "MIT"

srcDir = "src"
backend = "cpp"
binDir = "bin/"

bin = @[]

# episodes
for i in 1..5:
  let binName = "ep" & $i & "/main"
  bin.add binName
  namedBin[binName] = "ep" & $ i & ".bin"

# XXX what is this?
#installExt = @["nim"]

task build_debug, "Build debug version":
  exec "nimble --verbose -d:debug -d:logGC --nimcache: cache/ --hints:on --warnings:on --linedir:on --styleCheck:hint --excessiveStackTrace:on --lineTrace:on --gc=orc build"

task build_release, "Build release version":
  exec "nimble --verbose -d:release --hints:on --warnings:on --styleCheck:hint --gc=orc build"

task clean, "remove binaries":
  for b in namedBin.values():
    var p = os.joinpath(binDir, b)
    p = absolutePath(p)

    if fileExists(p):
      echo fmt"removing {p}"

      # not working on nimscript
      # tryRemoveFile(p)
      exec fmt"rm {p}"


# Dependencies

requires "nim >= 1.4.8"
requires "sdl2_nim >= 2.0.14.1"
requires "nimgl >= 1.3.2"
