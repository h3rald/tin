import
  os,
  json,
  strutils

type 
  TinPackage* = object
    name: string
    version: string
    data: JsonNode
  TinPackageExistsError* = ref object of SystemError


proc init(pkg: var TinPackage, dir: string) =
  let file = dir / "tin.json"
  if file.fileExists:
    raise TinPackageExistsError(msg: "tin.json file already exists in directory '$1'." % [dir])
  var data = newJObject()
  data["name"] = %pkg.name
  data["version"] = %pkg.version
  data["deps"] = newJArray()
  pkg.data = data
  file.writeFile(data.pretty)

proc newPackage*(dir, name: string, version="1.0.0"): TinPackage {.discardable.}=
  result = TinPackage(name: name, version: version)
  result.init(dir)
  
