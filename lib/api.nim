import
  json,
  strutils,
  asynchttpserver,
  asyncdispatch,
  critbits

import
  storage,
  config,
  utils

type
  TinServer* = object 
    port*: int
    address*: string
    storage*: TinStorage
    config*: TinConfig
  TinResource* = object 
    version*: int
    entity*: string
    operation*: string
    args*: seq[string]
    params*: CritBitTree[string]
  TinServerError* = ref object of SystemError
    code*: HttpCode

proc invalidOp*(res: TinResource) = 
  raise TinServerError(code: Http405, msg: "Method Not Allowed - Invalid $1 operation on entity '$2'" % [res.operation, res.entity])

proc invalidVersion*(res: TinResource) = 
  raise TinServerError(code: Http400, msg: "Bad Request - Invalid version: $1" % $res.version)

proc invalidEntity*(res: TinResource) =
  raise TinServerError(code: Http400, msg: "Bad Request - Invalid entity: $1" % [res.entity])

template version*(res: TinResource, v: int, body: untyped): untyped =
  if res.version == v:
    body

template entity*(res: TinResource, e: string, body: untyped): untyped =
  if res.entity == e:
    body

template operation(res: TinResource, op: string, body: untyped): untyped =
  if res.operation == op:
    body

template get*(res: TinResource, body: untyped): untyped =
  operation(res, "GET"):
    body

template args*(res: TinResource, n: int, body: untyped): untyped =
  if res.args.len >= n:
    body

template param*(res: TinResource, p: string, body: untyped): untyped =
  if res.params.hasKey(p):
    body



