# XXX not sure about this, probably delete it

# borrowed from system/timers

type
  Clockid {.importc: "clockid_t", header: "<time.h>", final.} = object

  Timespec* {.importc: "struct timespec", header: "<time.h>",
              final, pure.} = object ## struct timespec
    tv_sec*: int  ## Seconds.
    tv_nsec*: int ## Nanoseconds.

var
  CLOCK_REALTIME* {.importc: "CLOCK_REALTIME", header: "<time.h>".}: Clockid

proc clock_gettime*(clkId: Clockid, tp: var Timespec) {.
  importc: "clock_gettime", header: "<time.h>".}

proc getTicks(): float =
  var t: Timespec
  clock_gettime(CLOCK_REALTIME, t)
  result = t.tv_sec.float + (t.tv_nsec / 1000000000)

###################################
# timer object


type
  Timer* = ref TimerObj
  TimerObj = object of RootObj

    ## The clock time when the timer started
    startTicks: float

    ## The ticks stored when the timer was paused
    pausedTicks: float

    ## The timer status
    isPaused*: bool
    isStarted*: bool


proc start*(self: Timer) =
  # Start the timer
  self.isStarted = true

  # Unpause the timer
  self.isPaused = false

  # Get the current clock time
  self.startTicks = getTicks()
  self.pausedTicks = 0


proc stop*(self: Timer) =
  # Stop the timer
  self.isStarted = false

  # Unpause the timer
  self.isPaused = false

  # Clear tick variables
  self.startTicks = 0
  self.pausedTicks = 0


proc pause*(self: Timer) =
  # check we are running
  if self.isStarted and not self.isPaused:
    # lazy_foo way:
    self.pausedTicks = getTicks() - self.startTicks
    self.startTicks = 0

  # pause the timer
  self.isPaused = true


proc unpause*(self: Timer) =
  # check we are running
  if self.isStarted and self.isPaused:
    self.startTicks = getTicks() - self.pausedTicks
    self.pausedTicks = 0

  self.isPaused = false


proc getTicks*(self: Timer) : float =
  result = 0

  if self.isStarted:
    if self.isPaused:
      result = self.pausedTicks
    else:
      result = getTicks() - self.startTicks


proc setTicks*(self: Timer, ticks: float) =
  self.startTicks = getTicks() - ticks
