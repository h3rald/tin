import 
  critbits,
  os,
  strutils

import
  utils,
  config,
  package,
  storage

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
      debug e.getStackTrace()
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
    newTinPackage(dir = getCurrentDir(), name = ctx.args[1], version = v)
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
    let pkg = newTinPackage()
    pkg.compress(getCurrentDir())
    success "Tin package ready."

# store <tin>
COMMANDS["store"] = proc(ctx: var TinContext): int =
  if ctx.args.len < 2:
    error "Package file not specified"
    return 40
  if not ctx.args[1].fileExists:
    error "Package file '$1' does not exist" % [ctx.args[1]]
    return 41
  execute(42):
    ctx.storage.store(ctx.args[1])

# inventory
# scrap <tin>
# mart -a:<address> -p:<port>
# buy --from:<mart> <tin>
# sell --to:<mart> <tin>
# suppliers add <mart> <address>
# suppliers remove <mart>
# restock --all --from:<mart>
# label major|minor|patch
# relabel <version>
# inventory --all --from:<mart>
# withdraw <tin> --from:<mart>
