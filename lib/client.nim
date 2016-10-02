import
  httpclient,
  os,
  httpcore,
  strutils,
  json,
  critbits

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
    client*: HttpClient
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
  debug "Request URI: " & url
  let response = cli.client.get(url)
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

proc getPackages*(cli: TinClient, host:string = nil, all = false): CritBitTree[seq[string]] =
  var res: CritBitTree[seq[string]]
  proc query(host: string) =
    var url = cli.url(host, "packages")
    if all:
      url &= "?full=true"
    let response = cli.client.get(url)
    if response.status.startsWith("200"):
      let json = response.body.parseJson()
      for value in json["values"]:
        let name = value["name"].getStr
        if not res.hasKey(name):
          res[name] = newSeq[string](0)
          #TODO
    raise TinClientError(msg: response.body.parseJson()["error"].getStr)
  if host.isNil:
    for host in cli.servers:
      host.query()


  

