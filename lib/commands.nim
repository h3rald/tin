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
  TinArgumentDocObj = object
    name: string
    cmd: TinCommandDoc
    description: string
    default: string
    optional: bool
  TinArgumentDoc = ref TinArgumentDocObj
  TinOptionDocObj = object
    cmd: TinCommandDoc
    description: string
    name: string
    flag: bool
    default: string
  TinOptionDoc = ref TinOptionDocObj
  TinArgumentDocTree = CritBitTree[TinArgumentDoc]
  TinOptionDocTree = CritBitTree[TinOptionDoc]
  TinCommandDocObj = object
    name: string
    description: string
    args: TinArgumentDocTree
    opts: TinOptionDocTree
  TinCommandDoc = ref TinCommandDocObj
  TinCommand = proc(ctx: var TinContext): int

var COMMANDS*: CritBitTree[TinCommand]
var COMMANDDOCS*: CritBitTree[TinCommandDoc]


### Documentation

proc cmd(name: string): TinCommandDoc {.discardable.} =
  result = new TinCommandDoc
  result.name = name
  COMMANDDOCS[name] = result

proc desc(cmd: TinCommandDoc, description: string): TinCommandDoc {.discardable.} =
  cmd.description = description
  return cmd

proc arg(cmd: TinCommandDoc, name: string, mandatory = true): TinArgumentDoc {.discardable.} =
  result = new TinArgumentDoc
  result.name = name
  result.optional = not(mandatory)
  result.cmd = cmd
  cmd.args[name] = result

proc desc(arg: TinArgumentDoc, description: string): TinArgumentDoc {.discardable.}=
  arg.description = description
  return arg

proc cmd(arg: TinArgumentDoc): TinCommandDoc {.discardable.} =
  return arg.cmd

proc opt(cmd: TinCommandDoc, name: string, flag = false): TinOptionDoc {.discardable.} =
  result = new TinOptionDoc
  result.flag = flag
  result.name = name 
  result.cmd = cmd
  cmd.opts[name] = result

proc desc(opt: TinOptionDoc, description: string): TinOptionDoc {.discardable.}=
  opt.description = description
  return opt

proc def(opt: TinOptionDoc, value: string): TinOptionDoc {.discardable.} =
  opt.default = value
  return opt

proc cmd(opt: TinOptionDoc): TinCommandDoc {.discardable.} =
  return opt.cmd

### Commands

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

cmd("prepare")
  .desc("Creates a tin.json package definition file in the current directory.")
  .arg("name").desc("The name of the package.").cmd
  .opt("version").desc("The initial version of the package.").def("1.0.0")
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

cmd("open")
  .desc("Uncompresses a tin package into a specific folder.")
  .arg("tin").desc("The tin package file to open.").cmd
  .arg("folder").desc("The folder where the package contents will be placed.")
COMMANDS["open"] = proc(ctx: var TinContext): int =
  if ctx.args.len < 3:
    error "Package file or destination not specified"
    return 20
  execute(21):
    ctx.args[1].uncompress(ctx.args[2])
    success "Tin package '$1' opened successfully in '$1'." % [ctx.args[1], ctx.args[2]]

cmd("fill")
  .desc("Creates a .tin.zip package file in the current directory containing a valid tin.json file.")
COMMANDS["fill"] = proc(ctx: var TinContext): int =
  execute(30):
    let pkg = loadPackage()
    pkg.compress(getCurrentDir())
    success "Package $1 v$2 ready." % [pkg.name, pkg.version]

cmd("store")
  .arg("tin").desc("Stores the specified .tin.zip package into the local storage directory.")
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

cmd("label")
  .desc("Increments the major, minor, or patch version of the current package.")
  .arg("label").desc("The version digit to incremenr (major|minor|patch).")
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

cmd("relabel")
  .desc("Resets the version of the current package.")
  .arg("version").desc("A valid (semantic) version number (e.g. 1.2.0).")
COMMANDS["relabel"] = proc(ctx: var TinContext): int =
  if ctx.args.len < 2:
    error "Label not specified"
    return 60
  let label = ctx.args[1]
  if not label.validVersion:
    error "Invalid label: $1" % label
    return 61
  execute(62):
    var pkg = loadPackage()
    pkg.setVersion(label.newVersion())
    success "Package version set to $1." % $label

cmd("inventory")
  .desc("Scans the local storage folder and re-builds the package list saved in the .tinrc file.")
COMMANDS["inventory"] = proc(ctx: var TinContext): int =
  execute(70):
    ctx.storage.scan()
    success "Package data reloaded:"
    for name, pkg in ctx.storage.packages:
      echo " $1 ($2)" % [name, pkg.latest]
      for r in pkg.releases:
        echo "   - $1" % r

cmd("scrap")
  .desc("Deletes all the releases of the specified package.")
  .opt("version").desc("If specified, deletes only the specific version of the package.")
COMMANDS["scrap"] = proc(ctx: var TinContext): int =
  if ctx.args.len < 2:
    error "Package not specified"
    return 80
  let name = ctx.args[1]
  if not ctx.opts.hasKey("version"):
    # Delete al releases of package
    execute(81):
      if not ctx.storage.hasPackage(name):
        raise TinPackageNotFoundError(msg: "Package '$1' not found in storage" % name)
      ctx.storage.delete(name)
      success "Package '$1' deleted." % name
  else:
    # Delete a specific version of package
    let version = ctx.opts["version"]
    if not version.validVersion:
      error "Invalid version: $1" % version
      return 82
    execute(83):
      ctx.storage.delete(name, version)
      success "Version v$2 of package '$1' deleted." % [name, version]

# mart -a:<address> -p:<port>
# buy --from:<mart> <tin>
# sell --to:<mart> <tin>
# suppliers add <mart> <address>
# suppliers remove <mart>
# restock --all --from:<mart>
# list --all --from:<mart>
# search --from:<mart>
# withdraw <tin> --from:<mart>
