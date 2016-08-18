import
  json,
  asyncdispatch,
  critbits,
  strutils

import
  api,
  config


proc getMart(srv: TinServer, res: TinResource): JsonNode =
  result = newJObject()
  result["version"] = srv.config["version"]

proc getPackages(srv: TinServer, res: TinResource): JsonNode =
  result = newJObject()
  var search = ""
  var short = false
  if res.params.hasKey("search"):
    search = res.params["search"]
    result["search"] = %search
  if res.params.hasKey("short"):
    short = true
    result["short"] = %true
  result["values"] = newJArray()
  for key, val in srv.config["storage"].pairs:
    if search == "" or key.contains(search):
      if short:
        result["values"].add(%key)
      else:
        result["values"].add(val)
  return

proc getPackageNames(srv: TinServer, res: TinResource): JsonNode =
  result = newJObject()
  result["values"] = newJArray()
  for key, val in srv.config["storage"].pairs:
    result["values"].add(%key)

proc api_v1*(srv: TinServer, res: TinResource): JsonNode =
  let v1 = 1
  let mart = "mart"
  let packages = "packages"
  version(res, v1):
    entity(res, mart):
      get(res):
        return srv.getMart(res)
      res.invalidOp()
    entity(res, packages):
      get(res):
        return srv.getPackages(res)
      res.invalidOp()
    res.invalidEntity()
  res.invalidVersion()

  
    
   
