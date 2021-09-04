import os
import times
from strutils import nil

type
  Level* = enum
    lvlNone,
    lvlCritical,
    lvlError,
    lvlWarning,
    lvlInfo,
    lvlDebug,
    lvlVerbose

const
  LevelNames*: array[Level, string] = [
    "[NONE    ] ",
    "[CRITICAL] ",
    "[ERROR   ] ",
    "[WARNING ] ",
    "[INFO    ] ",
    "[DEBUG   ] ",
    "[VERBOSE ] "
  ]

type
  Logger* = ref object of RootObj
    levelThreshold*: Level

  ConsoleLogger* = ref object of Logger
    useStderr: bool
    coloured: bool

  FileLogger* = ref object of Logger
    file: File
    coloured: bool

var
  ## thread local log filter (set to verbose by default)
  level {.threadvar.}: Level

  ## thread local handlers
  handlers {.threadvar.}: seq[Logger]

  ## optimization to prevent regenerating timestamp
  lastSeconds {.threadvar.}: int64
  lastTimestamp {.threadvar.}: string

proc newConsoleLogger*(levelThreshold = lvlVerbose,
                       useStderr = false,
                       coloured = false): ConsoleLogger =
  new result
  result.levelThreshold = levelThreshold
  result.useStderr = useStderr
  result.coloured = coloured

proc defaultFilename*(): string =
  ## Returns the filename that is used by default when naming log files.
  var (path, name, _) = os.splitFile(getAppFilename())
  result = changeFileExt(path / name, "log")

proc newFileLogger*(filename = defaultFilename(),
                    levelThreshold = lvlVerbose,
                    coloured = false): FileLogger =
  let mode: FileMode = fmAppend
  let file = open(filename, mode)

  new(result)
  result.file = file
  result.levelThreshold = levelThreshold
  result.coloured = coloured


################################################################################

proc clearHandlers*() =
  handlers = @[]

proc addHandler*(handler: Logger) =
  handlers.add(handler)

proc getHandlers*(): seq[Logger] =
  return handlers

proc setLogFilter*(lvl: Level) =
  level = lvl

proc getLogFilter*(): Level =
  ## Gets the global log filter.
  return level

################################################################################

proc colorOn(lvl: Level): string =
  case lvl:
    of lvlCritical:
      # magenta
      result = "\x1b[1;35m";
    of lvlError:
      # red
      result = "\x1b[1;31m";
    of lvlWarning:
      # yellow
      result = "\x1b[1;33m";
    of lvlInfo:
      # green
      result = "\x1b[1;32m";
    of lvlDebug:
      # bold
      result = "\x1b[1;1m";
    of lvlVerbose:
      # cyan
      result = "\x1b[1;36m";
    else:
      discard

proc colorOff(): string =
  result = "\x1b[0m"

proc formatMsg(level: Level, msg: string): string =
  # this is just as fast than the above in release, but slower in debug
  let curTime = times.getTime()

  let nanos = curTime.nanosecond()
  let microsStr: string = strutils.intToStr(nanos div 1000, 6)
  let secs = curTime.toUnix()
  if lastSeconds != secs:
    lastTimestamp = times.format(curTime.local, "YYYY-MM-dd HH:mm:ss,")
    lastSeconds = secs

  result = lastTimestamp & microsStr & " " & LevelNames[level] & msg

################################################################################

method log*(self: Logger, level: Level, msg: string) {.
            gcsafe, tags: [RootEffect], base.} =
  ## Override this method in custom loggers. The default implementation does
  ## nothing.
  discard


method log*(self: ConsoleLogger, level: Level, msg: string) =
  var handle = stdout
  if self.useStderr:
    handle = stderr

  var writeMsg: string
  if self.coloured:
    writeMsg = colorOn(level) & msg & colorOff()
  else:
    writeMsg = msg

  try:
    writeLine(handle, writeMsg)

  except IOError:
    discard

method log*(self: FileLogger, level: Level, msg: string) =
  var writeMsg: string
  if self.coloured:
    writeMsg = colorOn(level) & msg & colorOff() & "\n"
  else:
    writeMsg = msg & "\n"

  write(self.file, writeMsg)
  if level in {lvlError, lvlCritical}:
    flushFile(self.file)


################################################################################

proc doLog*(level: Level, msg: string) {.inline.} =
  let msg: string = formatMsg(level, msg)
  for logger in items(handlers):
    if level <= logger.levelThreshold:
      log(logger, level, msg)

template log*(level: Level, args: varargs[string, `$`]) =
  bind doLog
  bind logsetup.level

  if level <= logsetup.level:
    let logMsg = strutils.join(args, " ")
    doLog(level, logMsg)

template l_verbose*(args: varargs[string, `$`]) =
  log(lvlVerbose, args)

template l_debug*(args: varargs[string, `$`]) =
  log(lvlDebug, args)

template l_info*(args: varargs[string, `$`]) =
  log(lvlInfo, args)

template l_warning*(args: varargs[string, `$`]) =
  log(lvlWarning, args)

template l_error*(args: varargs[string, `$`]) =
  log(lvlError, args)

template l_critical*(args: varargs[string, `$`]) =
  log(lvlCritical, args)

################################################################################

proc initLogging*(consoleLevel: Level = lvlDebug) =
  level = lvlVerbose
  let consolelogger = newConsoleLogger(consoleLevel, true, true)
  let fileLogger = newFileLogger(levelThreshold=lvlVerbose, coloured=true)
  clearHandlers()
  addHandler(consolelogger)
  addHandler(fileLogger)
