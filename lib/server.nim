import
  asynchttpserver,
  asyncdispatch,
  strutils,
  json,
  tables,
  critbits

import
  regex,
  utils,
  storage,
  config,
  api,
  api_v1

proc respond(srv: TinServer, req: Request, response: TinResponse, code = Http200): Future[void] =
  var headers: array[0..4, tuple[key:string, val:string]]
  headers[0] = (key:"Access-Control-Allow-Origin", val: "*")
  headers[1] = (key:"Access-Control-Allow-Headers", val: "Content-Type")
  headers[2] = (key:"Server", val: "TinMart/" & srv.config["version"].getStr)
  var content: string
  case response.kind
  of rsJSON:
    content = response.json.pretty
    headers[3] = (key:"Content-Type", val: "application/json")
    headers[4] = (key: "Content-Disposition", val: "Inline")
  of rsZIP:
    content = response.zip
    headers[3] = (key:"Content-Type", val: "application/zip")
    headers[4] = (key: "Content-Disposition", val: "Attachment; filename=" & response.filename)
  return req.respond(code, content, headers.newHttpHeaders)

proc resource(srv: TinServer, req: Request): TinResource =
  var mPath = newSeq[string](3)
  debug "Request: " & req.url.path
  mPath = req.url.path.search("""^\/([^\/])+\/?([^\/]+\/?)*""")
  result.version = 1 # DEFAULT: v1
  result.operation = req.reqMethod.toUpper
  result.entity = mPath[1]
  if result.entity == "":
    result.entity = "mart"
  result.args = mPath[2].split("/")
  for param in req.url.query.split("&"):
    let parts = param.split("=")
    result.params[parts[0]] = parts[1]

proc process(srv: TinServer, req: Request): Future[void] =
  try:
    let contents = srv.api_v1(srv.resource(req)) # DEFAULT: v1
    return srv.respond(req, contents)
  except:
    let e = getCurrentException().TinServerError
    error e.msg
    debug getStackTrace()
    var contents = newJObject()
    contents["error"] = %e.msg
    return srv.respond(req, TinResponse(kind: rsJSON, json: contents), e.code)
  
proc start*(srv: TinServer) =
  proc handleHttpRequest(req: Request): Future[void] {.async.} =
    await srv.process(req)
  var server = newAsyncHttpServer()
  asyncCheck server.serve(port = srv.port.Port, callback = handleHttpRequest, address = srv.address)
  
