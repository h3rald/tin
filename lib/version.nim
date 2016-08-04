import
  regex,
  strutils,
  json

type
  TinVersion* = object
    major*: int
    minor*: int
    patch*: int


const VREGEX = "^(\\d+)\\.(\\d+)\\.(\\d+)$"

proc newVersion*(version: string): TinVersion =
  var v = version.search(VREGEX)
  return TinVersion(major: v[1].parseInt, minor: v[2].parseInt, patch: v[3].parseInt)

proc `$`*(v: TinVersion): string =
  return "$1.$2.$3" % [$v.major, $v.minor, $v.patch]

proc `%`*(v: TinVersion): JsonNode =
  return %($v)

