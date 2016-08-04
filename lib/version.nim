import
  regex,
  strutils,
  json,
  sequtils,
  algorithm

type
  TinVersion* = object
    major*: int
    minor*: int
    patch*: int
  TinVersionSeq = seq[TinVersion]


const VREGEX = "^(\\d+)\\.(\\d+)\\.(\\d+)$"

proc newVersion*(version: string): TinVersion =
  var v = version.search(VREGEX)
  return TinVersion(major: v[1].parseInt, minor: v[2].parseInt, patch: v[3].parseInt)

proc newVersionSeq*(versions: seq[string]): TinVersionSeq =
  return versions.map(proc(v: string): TinVersion = return v.newVersion )

proc validVersion*(version: string): bool =
  return version.match(VREGEX)

proc `$`*(v: TinVersion): string =
  return "$1.$2.$3" % [$v.major, $v.minor, $v.patch]

proc `$`*(vs: TinVersionSeq): seq[string] =
  return vs.map(proc(v: TinVersion): string = return $v)

proc `%`*(v: TinVersion): JsonNode =
  return %($v)

proc `%`*(vs: TinVersionSeq): JsonNode =
  %($vs)

proc parseInt*(v: TinVersion): int =
  return v.patch + (v.minor * 1000) + (v.major * 1000000)

proc parseInt*(vs: TinVersionSeq): seq[int] =
  return vs.map(proc(v: TinVersion): int = return v.parseInt )

proc latest*(vs: TinVersionSeq): TinVersion =
  var numbers = newSeq[int](0)
  var version: int
  for v in vs:
    version = v.parseInt
    numbers.add(version)
    if numbers.max == version:
      result = v

proc `==`*(a, b: TinVersion): bool =
  return a.parseInt == b.parseInt

proc `<`*(a, b: TinVersion): bool =
  return a.parseInt < b.parseInt

proc sort*(vs: TinVersionSeq): TinVersionSeq =
  return sorted[TinVersion](vs, cmp[TinVersion])
