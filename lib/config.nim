import
  os,
  json

import 
  utils

type
  TinConfig* = object
    data: JsonNode
    file*: string

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
