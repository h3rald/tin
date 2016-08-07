import
  strutils,
  critbits

type
  TinArgumentDocSeq = seq[TinArgumentDoc]
  TinOptionDocTree = CritBitTree[TinOptionDoc]
  TinCommandDocObj = object
    name: string
    description: string
    args*: TinArgumentDocSeq
    opts*: TinOptionDocTree
  TinCommandDoc = ref TinCommandDocObj
  TinArgumentDocObj = object
    name: string
    cmd: TinCommandDoc
    description: string
    default: string
    optional: bool
  TinArgumentDoc = ref TinArgumentDocObj
  TinOptionDocObj = object
    name: string
    cmd: TinCommandDoc
    description: string
    flag: bool
    default: string
  TinOptionDoc = ref TinOptionDocObj

var COMMANDDOCS*: CritBitTree[TinCommandDoc]

proc cmd*(name: string): TinCommandDoc {.discardable.} =
  result = new TinCommandDoc
  result.args = newSeq[TinArgumentDoc](0)
  result.name = name
  COMMANDDOCS[name] = result

proc desc*(cmd: TinCommandDoc, description: string): TinCommandDoc {.discardable.} =
  cmd.description = description
  return cmd

proc arg*(cmd: TinCommandDoc, name: string, mandatory = true): TinArgumentDoc {.discardable.} =
  result = new TinArgumentDoc
  result.name = name
  result.optional = not(mandatory)
  result.cmd = cmd
  cmd.args.add result

proc desc*(arg: TinArgumentDoc, description: string): TinArgumentDoc {.discardable.}=
  arg.description = description
  return arg

proc cmd*(arg: TinArgumentDoc): TinCommandDoc {.discardable.} =
  return arg.cmd

proc opt*(cmd: TinCommandDoc, name: string, flag = false): TinOptionDoc {.discardable.} =
  result = new TinOptionDoc
  result.flag = flag
  result.name = name 
  result.cmd = cmd
  cmd.opts[name] = result

proc desc*(opt: TinOptionDoc, description: string): TinOptionDoc {.discardable.}=
  opt.description = description
  return opt

proc def*(opt: TinOptionDoc, value: string): TinOptionDoc {.discardable.} =
  opt.default = value
  return opt

proc cmd*(opt: TinOptionDoc): TinCommandDoc {.discardable.} =
  return opt.cmd

proc pad(s: string, maxlen: int): string =
  return s & " ".repeat(maxlen - s.len)

proc `$`*(option: TinOptionDoc): string =
  result = "          " & option.name.pad(15) & option.description
  if not option.default.isNil:
    result &= "\n      " & " ".repeat(19) & "(default: " & option.default & ")"

proc `$`*(argument: TinArgumentDoc): string =
  result = "          " & argument.name.pad(15) & argument.description
  if not argument.default.isNil:
    result &= "\n      " & " ".repeat(19) & "(default: " & argument.default

proc `$`*(cmd: TinCommandDoc): string =
  result = "      " & cmd.name
  for argument in cmd.args:
    if argument.optional:
      result &= " [$1]" % argument.name
    else:
      result &= " <$1>" % argument.name
  if cmd.opts.len > 0:
    result &= " ["
  for option in cmd.opts.values:
    result &= "--" & option.name
    if not option.flag:
      result &= ":<$1>" % option.name
  if cmd.opts.len > 0:
    result &= "]"
  result &= "\n        " & cmd.description

