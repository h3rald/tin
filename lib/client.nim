import
  httpclient,
  os,
  httpcore,
  strutils,
  json

import 
  regex,
  config,
  storage,
  utils


type
  TinClient* = object
    config*: TinConfig
    storage*: TinStorage
    protocol*: string
  TinClientError* = ref object of SystemError

iterator servers(cli: TinClient): string =
  for key, val in cli.config["servers"].pairs:
    yield val["address"].getStr

proc url(cli: TinClient, host, entity: string, args: varargs[string]): string =
  result = cli.protocol & "://" & host / entity
  for arg in args:
    result = result / arg

proc filename(headers: HttpHeaders): string =
  let hd = headers["Content-Disposition"]
  let matches = hd.search("filename=(.+)$")
  return matches[1]

proc getPackage*(cli: var TinClient, host, name, version: string): tuple[name, version: string] =
  info "Contacting: " & host & " ..."
  let url = cli.url(host, "packages", name, version)
  var response: Response
  debug "Request URI: " & url
  response = get(url = url, timeout = 10000)
  if response.status.startsWith("200"):
    let filename = response.headers.filename
    let body = response.body
    debug "Storing package: " & filename
    return cli.storage.store(filename, body)
  raise TinClientError(msg: response.body.parseJson()["error"].getStr)

proc getPackage*(cli: var TinClient, name, version: string): tuple[name, version: string] =
  for host in cli.servers:
    try:
      return cli.getPackage(host, name, version)
    except:
      discard
  raise TinClientError(msg: "Package not found.")
