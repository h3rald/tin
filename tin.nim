import
  os,
  json,
  parseopt2,
  critbits,
  strutils

import
  lib/utils,
  lib/config,
  lib/commands,
  lib/storage

when defined(windows):
  const HOMEDIR = "HOMEPATH".getEnv
else:
  const HOMEDIR = "HOME".getEnv

var CONFIG = TinConfig(file: HOMEDIR / ".tinrc")
CONFIG.init
CONFIG.load

var STORAGE = TinStorage(folder: HOMEDIR / ".tin/storage", config: CONFIG)
STORAGE.init
STORAGE.load

var ARGS =  newSeq[string](0) 
var OPTIONS: CritBitTree[string]
let VERSION = "1.0.0"
var USAGE = "  Tin v" & VERSION & " - a tiny general-purpose package manager" & """

  (c) 2016 Fabio Cevasco
  
  Usage:
    tin <command> [arguments] [options]

  Commands:"""
for cmd in COMMANDDOCS.values:
  USAGE &= "\n" & $cmd

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

if COMMANDS.hasKey(ARGS[0]):
  var ctx = TinContext(storage: STORAGE, config: CONFIG, args: ARGS, opts: OPTIONS)
  quit COMMANDS[ARGS[0]](ctx)
else:
  error "Invalid command: $1" % [ARGS[0]] 
  quit(2)
