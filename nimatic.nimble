# package

version = "0.2.0"
author = "Kermit Alexander II"
description = "A static site generator written in Nim"
license = "2-clause BSD"
srcDir = "src"
bin = @["nimatic"]
skipExt = @["nim"]

# dependencies

requires "nim >= 1.0.4"
requires "markdown >= 0.8.0"
