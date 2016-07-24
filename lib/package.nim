import
  os,
  json,
  strutils,
  sequtils


import
  ../vendor/miniz,
  utils

type 
  TinPackage* = object
    name: string
    version: string
    file: string
    data: JsonNode
  TinPackageExistsError* = ref object of SystemError


proc init(pkg: var TinPackage, dir: string) =
  pkg.file = dir / "tin.json"
  if pkg.file.fileExists:
    raise TinPackageExistsError(msg: "tin.json file already exists in directory '$1'." % [dir])
  var data = newJObject()
  data["name"] = %pkg.name
  data["version"] = %pkg.version
  data["deps"] = newJArray()
  data["include"] = newJArray()
  data["exclude"] = newJArray()
  pkg.data = data
  pkg.file.writeFile(data.pretty)

proc load(pkg: var TinPackage, file: string) = 
  pkg.data = file.parseFile
  pkg.name = pkg.data["name"].getStr
  pkg.version = pkg.data["version"].getStr
  pkg.file = file

proc save(pkg: TinPackage) =
  pkg.file.writeFile(pkg.data.pretty)

proc newTinPackage*(dir, name: string, version="1.0.0"): TinPackage {.discardable.}=
  result = TinPackage(name: name, version: version)
  result.init(dir)

proc newTinPackage*(): TinPackage =
  result.load(getCurrentDir() / "tin.json")

proc files(pkg: TinPackage): seq[string] =
  var includes = newSeq[string](0)
  var excludes = newSeq[string](0)
  # Process include glob expressions
  for i in pkg.data["include"].items:
    for ifile in walkFiles(i.getStr):
      includes.add ifile
  includes = includes.deduplicate
  # Process exclude glob expressions
  for e in pkg.data["exclude"].items:
    for efile in walkFiles(e.getStr):
      excludes.add efile
  excludes = excludes.deduplicate
  result = includes
  result.keepif do (f: string) -> bool:
    return not excludes.contains(f)

proc compress*(pkg: TinPackage, dir: string) =
  var pZip: ptr mz_zip_archive = cast[ptr mz_zip_archive](new mz_zip_archive)
  let filename = "$1-$2.tin.zip" % [pkg.name, pkg.version]
  let filepath = dir / filename
  let files = pkg.files
  discard pZip.mz_zip_writer_init_file(filename.cstring, cast[mz_uint64](0))
  var comment: pointer 
  for f in files:
    debug "Compressing: $1" % [f]
    discard pZip.mz_zip_writer_add_file(f.cstring, f.cstring, comment, 0, cast[mz_uint](MZ_DEFAULT_COMPRESSION))
  discard pZip.mz_zip_writer_finalize_archive()
  discard pZip.mz_zip_writer_end()

proc uncompress*(src, dst: string) = 
  var pZip: ptr mz_zip_archive = cast[ptr mz_zip_archive](new mz_zip_archive)
  discard pZip.mz_zip_reader_init_file(src.cstring, 0)
  let total = pZip.mz_zip_reader_get_num_files()
  debug "Total entries: " & $total
  if total == 0:
    return
  for i in 0.countup(total-1):
    let isDir = pZip.mz_zip_reader_is_file_a_directory(i)
    if isDir == 0:
      # Extract file
      let size = pZip.mz_zip_reader_get_filename(i, nil, 0)
      var filename: cstring = cast[cstring](alloc(size))
      discard pZip.mz_zip_reader_get_filename(i, filename, size)
      debug "Uncompressing: $1" % [$filename]
      let dest = dst / $filename
      echo pZip.mz_zip_reader_extract_to_file(i, dest, 0)
  discard pZip.mz_zip_reader_end()


