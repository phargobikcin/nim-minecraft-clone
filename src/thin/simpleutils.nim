import std/strformat
import std/times

template typeOfDeref*(T: typedesc): typedesc =
  ## Return the base object type behind a ptr type
  typeof(default(T)[])

###############################################################################

proc getTicks*(): float64 =
  let curTime = times.getTime()
  result = curTime.toUnix().float64 + curTime.nanosecond() / 1000000000


###############################################################################

when defined(windows):
  proc alloca(size: int): pointer {.header: "<malloc.h>".}
else:
  proc alloca(size: int): pointer {.header: "<alloca.h>".}


template alloca*(T: typedesc, len: Natural): ptr UncheckedArray[T] =
  cast[ptr UncheckedArray[T]](alloca(sizeof(T) * len))

###############################################################################
# use f instead of fmt, like python

template f*(pattern: static[string]): untyped =
  ## An alias for ``fmt``. Mimics Python F-String.
  bind `fmt`
  fmt(pattern)

type StringLike* = string | char

template `*`*(a: StringLike, b: int): string = a.repeat(b)
