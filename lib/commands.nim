import 
  critbits,
  os,
  strutils

import
  utils,
  config,
  package,
  storage,
  version

type
  TinArgs* = seq[string]
  TinOpts* = CritBitTree[string]
  TinContext* = object
    config*: TinConfig
    storage*: TinStorage
    args*: TinArgs
    opts*: TinOpts
  TinCommand = proc(ctx: var TinContext): int

var COMMANDS*: CritBitTree[TinCommand]

template execute(code: int, body: stmt) =
  try:
    body 
    return 0
  except:
    let e = getCurrentException()
    error e.msg
    if not defined(release):
      debug "\n" & e.getStackTrace()
    return code

# prepare
COMMANDS["prepare"] = proc(ctx: var TinContext): int =
  var v = "1.0.0"
  if ctx.opts.hasKey("version"):
    v = ctx.opts["version"] 
  if ctx.args.len < 2:
    error "Package name not specified."
    return 10
  execute(11):
    newPackage(dir = getCurrentDir(), name = ctx.args[1], version = v)
    success "Tin package \"$1\" (version: $2) initialized." % [ctx.args[1], v] 

# open <tin> <folder>
COMMANDS["open"] = proc(ctx: var TinContext): int =
  if ctx.args.len < 3:
    error "Package file or destination not specified"
    return 20
  execute(21):
    ctx.args[1].uncompress(ctx.args[2])
    success "Tin package '$1' opened successfully in '$1'." % [ctx.args[1], ctx.args[2]]

# fill
COMMANDS["fill"] = proc(ctx: var TinContext): int =
  execute(30):
    let pkg = loadPackage()
    pkg.compress(getCurrentDir())
    success "Package $1 v$2 ready." % [pkg.name, pkg.version]

# store <tin>
COMMANDS["store"] = proc(ctx: var TinContext): int =
  if ctx.args.len < 2:
    error "Package file not specified"
    return 40
  if not ctx.args[1].fileExists:
    error "Package file '$1' does not exist" % [ctx.args[1]]
    return 41
  execute(42):
    let pkgdata = ctx.storage.store(ctx.args[1])
    success "Package $1 v$2 stored." % [pkgdata.name, pkgdata.version]

COMMANDS["label"] = proc(ctx: var TinContext): int =
  if ctx.args.len < 2:
    error "Label not specified"
    return 50
  let label = ctx.args[1]
  if not ["major", "minor", "patch"].contains(label):
    error "Invalid label: $1" % label
    return 51
  execute(52):
    var pkg = loadPackage()
    var version = pkg.version.newVersion()
    case label:
      of "major":
        version.major.inc
      of "minor":
        version.minor.inc
      of "patch":
        version.patch.inc
    pkg.setVersion(version)
    success "Package version set to $1." % $version

COMMANDS["relabel"] = proc(ctx: var TinContext): int =
  if ctx.args.len < 2:
    error "Label not specified"
    return 60
  let label = ctx.args[1]
  if not label.validVersion:
    error "Invalid label: $1" % label
    return 61
  execute(53):
    var pkg = loadPackage()
    pkg.setVersion(label.newVersion())
    success "Package version set to $1." % $label

# inventory
# scrap <tin> <version> [--all]
# mart -a:<address> -p:<port>
# buy --from:<mart> <tin>
# sell --to:<mart> <tin>
# suppliers add <mart> <address>
# suppliers remove <mart>
# restock --all --from:<mart>
# inventory --all --from:<mart>
# withdraw <tin> --from:<mart>
