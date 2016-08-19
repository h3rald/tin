
proc error*(msg: string) =
  stderr.writeLine("ERROR:   ", msg)

proc success*(msg: string) =
  echo(            "SUCCESS: ", msg)

proc debug*(msg: string) =
  echo(            "DEBUG:   ", msg)

proc info*(msg: string) =
  echo(            "INFO:    ", msg)
