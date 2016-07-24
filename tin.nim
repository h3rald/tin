import
  os,
  json,
  parseopt2,
  critbits,
  strutils

import
  lib/utils,
  lib/config,
  lib/package

when defined(windows):
  const HOMEDIR = "HOMEPATH".getEnv
else:
  const HOMEDIR = "HOME".getEnv

var CONFIG = TinConfig(file: HOMEDIR / ".tinrc")
var ARGS =  newSeq[string](0) 
var OPTIONS: CritBitTree[string]
let VERSION = "1.0.0"
let USAGE = "  Tin v" & VERSION & " - a tiny general-purpose package manager" & """

  (c) 2016 Fabio Cevasco
  
  Usage:
    tin <command> [arguments] [options]

  Commands:
    init <name>       Creates a tin.json file in the current directory for
                      package <name>.  
    fill              Creates a compressed package file.
    open <src> <dst>  Uncompresses the <src> tin package to target directory <dst>.
  Options:
    -v, --version     (init) Specifies a (semantic) version for the package.
"""

CONFIG.init
CONFIG.load


# Process Arguments
for kind, key, val in getopt():
  case kind:
    of cmdArgument:
      ARGS.add key
    of cmdLongOption, cmdShortOption:
      var key = key
      if key == "v":
        key = "version"
      if not OPTIONS.hasKey(key):
        OPTIONS[key] = val
    else:
      discard
        

# Dispatch commands
if ARGS.len == 0:
  echo USAGE
  quit(0)

case ARGS[0]:
  of "init":
    var v = "1.0.0"
    if OPTIONS.hasKey("version"):
      v = OPTIONS["version"] 
    if ARGS.len < 2:
      error "Package name not specified."
      quit(1)
    try:
      newTinPackage(dir = getCurrentDir(), name = ARGS[1], version = v)
      success "Tin package \"$1\" (version: $2) initialized." % [ARGS[1], v] 
    except:
      error getCurrentExceptionMsg()
      quit(11)
  of "fill":
    try:
      let pkg = newTinPackage()
      pkg.compress(getCurrentDir())
    except:
      error getCurrentExceptionMsg()
      quit(21)
  of "open":
    if ARGS.len < 3:
      error "Package file or destination not specified"
      quit(3)
    try:
      ARGS[1].uncompress(ARGS[2])
    except:
      error getCurrentExceptionMsg()
      quit(21)
  else:
    error "Invalid command: $1" % [ARGS[0]] 
    quit(2)
