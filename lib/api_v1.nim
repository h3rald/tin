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
      if full:
        var v = newJObject()
        v["name"] = %key
        v["latest"] = val["latest"]
        v["releases"] = val["releases"]
        contents["values"].add(v)
      else:
        var v = newJObject()
        v["name"] = %key
        v["version"] = val["latest"]
        contents["values"].add(v)
  contents["total"] = %total
  return TinResponse(kind: rsJSON, json: contents)

proc getPackage(srv: TinServer, res: TinResource): TinResponse =
  if srv.storage.hasPackage(res.args[0]):
    var file: string
    if res.args.len > 1 and res.args[1] != "": 
      if srv.storage.hasPackageVersion(res.args[0], res.args[1]):
        file = srv.storage.getPackagePath(res.args[0], res.args[1])
      else:
        raise TinServerError(code: Http404, msg: "Version '$2' of package '$1' not found" % [res.args[0], res.args[1]])
    else:
      file = srv.storage.getLatestPackagePath(res.args[0])
    debug file
    if file.fileExists:
      result.kind = rsZip
      result.zip = file.readFile()
      result.filename = file.extractFileName
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

  
    
   
