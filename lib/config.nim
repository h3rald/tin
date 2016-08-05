import
  os,
  json,
  strutils,
  sequtils

import 
  utils

type
  TinConfig* = object
    data: JsonNode
    file*: string
  TinPackageNotFoundError* = ref object of ValueError

proc exists(cfg: TinConfig): bool =
  return cfg.file.fileExists

proc save*(cfg: TinConfig) =
  debug "Saving configuration"
  cfg.file.writeFile(cfg.data.pretty)

proc validate(cfg: var TinConfig) =
  if not cfg.data.hasKey("storage"):
    cfg.data["storage"] = newJObject();
  cfg.save()

proc load*(cfg: var TinConfig) =
  cfg.data = cfg.file.parseFile
  cfg.validate()

proc init*(cfg: TinConfig) =
  if not cfg.exists:
    var o = newJObject()
    o["storage"] = newJObject()
    cfg.file.writeFile(o.pretty)

proc `[]`*(cfg: TinConfig, key: string): JsonNode = 
  return cfg.data[key]

proc `[]=`*(cfg: TinConfig, key: string, value: JsonNode) =
  cfg.data[key] = value

proc deletePackage*(cfg: TinConfig, name: string, version = "*") =
  if not cfg["storage"].hasKey(name):
    raise TinPackageNotFoundError(msg: "Package '$1' not found in configuration." % name)
  if version != "*" and not cfg.data{"storage", name, "releases"}.elems.contains(%version):
    raise TinPackageNotFoundError(msg: "Version '$2' of package '$2' not found in configuration." % [name, version])
  if version == "*":
    cfg["storage"].delete(name)
  else:
    let releases = cfg.data{"storage", name, "releases"}.elems
    cfg.data{"storage", name, "releases"} = %releases.filter(proc(x: JsonNode): bool = return x != %version)
