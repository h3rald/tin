import
  os,
  json

type
  TinConfig* = object
    data: JsonNode
    file*: string

proc exists(cfg: TinConfig): bool =
  return cfg.file.fileExists

proc load*(cfg: var TinConfig) =
  cfg.data = cfg.file.parseFile

proc save*(cfg: TinConfig) =
  cfg.file.writeFile(cfg.data.pretty)

proc init*(cfg: TinConfig) =
  if not cfg.exists:
    var o = newJObject()
    o["stored"] = newJObject()
    o["open"]   = newJObject()
    cfg.file.writeFile(o.pretty)
