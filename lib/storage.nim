import
  json,
  critbits,
  os,
  strutils

import
  regex,
  config,
  utils


type
  TinPackageData =  object
    latest*: string
    releases: seq[string]
  TinStorage* = object
    config*: TinConfig
    packages*: CritBitTree[TinPackageData]
    folder*: string


const PKGREGEX = "^(.+)-(\\d+\\.\\d+\\.\\d+)\\.tin\\.zip$"
const VREGEX = "^(\\d+)\\.(\\d+)\\.(\\d+)$"

proc `%`(pkg: TinPackageData): JsonNode =
  result = newJObject()
  result["latest"] = %pkg.latest
  result["releases"] = %pkg.releases

proc getLatest(releases: seq[string]): string =
  var v: seq[string]
  var numbers: seq[int]
  var version: int
  for vstring in releases:
    v = vstring.search(VREGEX)
    version = (v[3].parseInt) + (v[2].parseInt * 1000) + (v[1].parseInt * 1000000)
    numbers.add(version)
    if numbers.max == version:
      result = vstring

proc `[]=`(stg: var TinStorage, name, version: string) =
  if not stg.packages.hasKey(name):
    stg.packages[name] = TinPackageData(releases: @[version], latest: version)
    stg.config["storage"][name] = %stg.packages[name]
  else:
    if not stg.packages[name].releases.contains(version):
      stg.packages[name].releases.add(version)
      stg.packages[name].latest = stg.packages[name].releases.getLatest()
      stg.config["storage"][name] = %stg.packages[name]


proc store*(stg: var TinStorage, file: string) =
  let filename = file.extractFilename()
  debug "Storing package '$1'" % filename
  file.copyFile(stg.folder / filename)
  let details = filename.search(PKGREGEX)
  stg[details[1]] = details[2]
  stg.config.save()
  
proc scan*(stg: var TinStorage) =
  var details: seq[string]
  var name: string
  var version: string
  stg.config["storage"] = newJArray()
  # Load packages
  for file in stg.folder.walkDir():
    if not file.path.fileExists:
      continue
    details = file.path.search(PKGREGEX)
    name = details[1]
    version = details[2]
    stg[name] = version
  # Set latest and update config
  for name, pkg in stg.packages.mpairs:
    pkg.latest = pkg.releases.getLatest()
    # Update config
    stg.config["storage"][name] = %pkg
  # Save modified config
  stg.config.save()
    
proc load*(stg: var TinStorage) =
  var packages: CritBitTree[TinPackageData]
  var pkg: TinPackageData
  for name, jpkg in stg.config["storage"].pairs:
    pkg.latest = jpkg["latest"].getStr()
    pkg.releases = newSeq[string](0)
    for r in jpkg["releases"].items:
      pkg.releases.add(r.getStr())
    packages[name] = pkg
  stg.packages = packages

proc init*(stg: var TinStorage) =
  if not stg.folder.existsDir():
    stg.folder.createDir()
  stg.load()
