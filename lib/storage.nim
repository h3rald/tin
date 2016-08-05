import
  json,
  critbits,
  os,
  strutils,
  sequtils

import
  regex,
  config,
  utils,
  version


type
  TinPackageData =  object
    latest*: string
    releases*: seq[string]
  TinStorage* = object
    config*: TinConfig
    data: CritBitTree[TinPackageData]
    folder*: string


const PKGREGEX = "^(.+)-(\\d+\\.\\d+\\.\\d+)\\.tin\\.zip$"

proc `%`(pkg: TinPackageData): JsonNode =
  result = newJObject()
  result["latest"] = %pkg.latest
  result["releases"] = %pkg.releases

proc `[]`(stg: TinStorage, name: string): TinPackageData =
  return stg.data[name]

proc `[]=`(stg: var TinStorage, name, version: string) =
  if not stg.data.hasKey(name):
    stg.data[name] = TinPackageData(releases: @[version], latest: version)
    stg.config["storage"][name] = %stg.data[name]
  else:
    if not stg.data[name].releases.contains(version):
      stg.data[name].releases.add(version)
      stg.data[name].releases = $stg.data[name].releases.newVersionSeq.sort
      stg.data[name].latest = $stg.data[name].releases.newVersionSeq.latest
      stg.config["storage"][name] = %stg.data[name]

iterator packages*(stg: TinStorage): tuple[name: string, package: TinPackageData] =
  for name, pkg in stg.data.pairs:
    let t = (name: name, package: pkg)
    yield t

proc hasPackage*(stg: TinStorage, name: string): bool =
  return stg.data.hasKey(name)

proc store*(stg: var TinStorage, file: string): tuple[name, version: string] =
  let filename = file.extractFilename()
  file.copyFile(stg.folder / filename)
  let details = filename.search(PKGREGEX)
  result = (name: details[1], version: details[2])
  stg[result.name] = result.version
  stg.config.save()

proc delete*(stg: var TinStorage, name: string, version = "*") =
  if not stg.hasPackage(name):
    raise TinPackageNotFoundError(msg: "Package '$1' not found in storage." % name)
  if version != "*" and not stg[name].releases.contains(version):
    raise TinPackageNotFoundError(msg: "Version '$2' of package '$1' not found in storage." % [name, version])
  if version == "*":
    for file in (stg.folder / name & "-*.zip").walkFiles:
      file.removeFile
    stg.config.deletePackage(name)
    stg.data.excl(name)
  else:
    (stg.folder / name & "-" & version & ".tin.zip").removeFile
    stg.config.deletePackage(name, version)
    stg.data[name].releases = stg.data[name].releases.filter(proc (x: string): bool = return x != version)
  stg.config.save()
  
proc scan*(stg: var TinStorage) =
  var details: seq[string]
  var name: string
  var version: string
  stg.config["storage"] = newJObject()
  # Load data
  for file in stg.folder.walkDir():
    if not file.path.fileExists:
      continue
    details = file.path.extractFileName.search(PKGREGEX)
    name = details[1]
    version = details[2]
    stg[name] = version
  # Set latest and update config
  for name, pkg in stg.data.mpairs:
    pkg.latest = $pkg.releases.newVersionSeq.latest
    # Update config
    stg.config["storage"][name] = %pkg
  # Save modified config
  stg.config.save()

proc load*(stg: var TinStorage) =
  var data: CritBitTree[TinPackageData]
  var pkg: TinPackageData
  for name, jpkg in stg.config["storage"].pairs:
    pkg.latest = jpkg["latest"].getStr()
    pkg.releases = newSeq[string](0)
    for r in jpkg["releases"].items:
      pkg.releases.add(r.getStr())
    data[name] = pkg
  stg.data = data

proc init*(stg: var TinStorage) =
  if not stg.folder.existsDir():
    stg.folder.createDir()
  stg.load()
