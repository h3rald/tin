import
  json,
  asyncdispatch,
  asynchttpserver,
  critbits,
  os,
  strutils

import
  api,
  config,
  storage,
  utils


proc getMart(srv: TinServer, res: TinResource): TinResponse =
  var contents = newJObject()
  contents["version"] = srv.config["version"]
  return TinResponse(kind: rsJSON, json: contents)

proc getPackages(srv: TinServer, res: TinResource): TinResponse =
  var contents = newJObject()
  var search = ""
  var full = false
  var total = 0
  if res.params.hasKey("search"):
    search = res.params["search"]
    contents["search"] = %search
  if res.params.hasKey("full"):
    full = true
  contents["values"] = newJArray()
  for key, val in srv.config["storage"].pairs:
    if search == "" or key.contains(search):
      total.inc
      var v = newJObject()
      v["name"] = %key
      v["latest"] = val["latest"]
      v["releases"] = val["releases"]
      if full:
        contents["values"].add(v)
      else:
        contents["values"].add(%key)
  contents["total"] = %total
  return TinResponse(kind: rsJSON, json: contents)

proc getPackage(srv: TinServer, res: TinResource): TinResponse =
  if srv.storage.hasPackage(res.args[0]):
    let file = srv.storage.getLatestPackagePath(res.args[0])
    debug file
    if file.fileExists:
      result.kind = rsZip
      result.zip = file.readFile()
      return
  raise TinServerError(code: Http404, msg: "Package '$1' not found" % res.args[0])

proc api_v1*(srv: TinServer, res: TinResource): TinResponse =
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
        args(res, 1):
          return srv.getPackage(res)
        return srv.getPackages(res)
      res.invalidOp()
    res.invalidEntity()
  res.invalidVersion()

  
    
   
