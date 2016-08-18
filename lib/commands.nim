import 
  critbits,
  os,
  strutils,
  asyncdispatch

import
  utils,
  config,
  package,
  storage,
  version,
  docs,
  api,
  server

type
  TinArgs* = seq[string]
  TinOpts* = CritBitTree[string]
  TinContext* = object
    config*: TinConfig
    storage*: TinStorage
    server*: TinServer
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
  .desc("Stores the specified .tin.zip package into the local storage directory.")
  .arg("tin").desc("A valid tin package file.")
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

cmd("mart")
  .desc("Starts the tin package server.")
  .opt("address").desc("The server IP address or hostname.").def("0.0.0.0").cmd
  .opt("port").desc("The server port.").def($7700)
COMMANDS["mart"] = proc(ctx: var TinContext): int =
  var address = "0.0.0.0"
  var port = 7700
  if ctx.opts.hasKey("address"):
    address = ctx.opts["address"]
  if ctx.opts.hasKey("port"):
    port = ctx.opts["port"].parseInt
  execute(90):
    success "Tin Mart opening on $1:$2..." % [address, $port]
    ctx.server.address = address
    ctx.server.port = port
    ctx.server.start()
    runForever()

cmd("help")
  .desc("Displays information about a tin command.")
  .arg("command").desc("A valid tin command.")
COMMANDS["help"] = proc(ctx: var TinContext): int =
  if ctx.args.len < 2:
    error "Command not specified."
    return 100
  if not COMMANDDOCS.hasKey ctx.args[1]:
    error "Invalid command: " & ctx.args[1]
    return 101
  let cmd = COMMANDDOCS[ctx.args[1]]
  echo $cmd
  if cmd.args.len > 0:
    echo "        Arguments:"
    for arg in cmd.args:
      echo $arg
  if cmd.opts.len > 0:
    echo "        Options:"
    for opt in cmd.opts.values:
      echo $opt
      
# sell --to:<mart> <tin>
# buy --from:<mart> <tin>
# suppliers add <mart> <address>
# suppliers remove <mart>
# restock --all --from:<mart>
# list --all --from:<mart>
# search --from:<mart>
# withdraw <tin> --from:<mart>
