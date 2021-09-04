import os
import tables

from sdl2_nim/sdl import Event
import nimgl/opengl as gl

import logsetup as logging

import simpleutils
import display, shading, loaded


# the application
type
  App* = ref object of RootObj
    ctx*: DisplayCtx
    eventCB*: proc(evt: sdl.Event)

    # XXX i don't know if I should use a RefTable or a Table :(
    vaoRegistry: Table[string, VertexArrayObject]
    programRegistry: Table[string, shading.ShaderProgram]

    # per-frame time logic
    deltaTime: float
    lastFrameTime: float

###############################################################################
# inherit from these

method init*(self: App) {.base.} =
  discard

method onResized*(self: App, width, height: int) {.base.} =
  discard

method handleEvent*(self: App, e: Event) {.base.} =
  discard

method update*(self: App, deltaTime: float) {.base.} =
  discard

method clear*(self: App) {.base.} =
  # set clear colour
  gl.glClear(GL_COLOR_BUFFER_BIT)

method draw*(self: App) {.base.} =
  self.clear()

###############################################################################
# helpers

proc setBlend*(self: App) =
  gl.glEnable(gl.GL_BLEND)
  gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA)

proc add*(self: App, name: string, vao: VertexArrayObject) =
  doAssert(name notin self.vaoRegistry)
  self.vaoRegistry[name] = vao

proc add*(self: App, name: string, program: shading.ShaderProgram) =
  doAssert(name notin self.programRegistry)
  self.programRegistry[name] = program

proc vao*(self: App, name: string): VertexArrayObject =
  self.vaoRegistry[name]

proc program*(self: App, name: string): shading.ShaderProgram =
  self.programRegistry[name]

proc vao*(self: App): VertexArrayObject =
  # convience - return the first.  XXX how slow is this?
  assert self.vaoRegistry.len() == 1
  for v in self.vaoRegistry.values():
    result = v

proc program*(self: App): shading.ShaderProgram =
  # convience - return the first.  XXX how slow is this?
  assert self.programRegistry.len() == 1
  for p in self.programRegistry.values():
    result = p

###############################################################################

template start*(typ: typed,
                workingDir: string,
                w=800, h=600,
                title="Title",
                vsync=true,
                doFullscreen=false,
                doResize=true) =

  let simpleAppFilePath: string =
    if os.fileExists(workingDir):
      os.splitPath(workingDir).head
    else:
      assert os.dirExists(workingDir)
      workingDir

  proc main() =
    # set the current directory to where main() is defined
    # where this is included from
    os.setCurrentDir(simpleAppFilePath)

    var app: App = typ()
    logging.initLogging(logging.lvlVerbose)

    var ctx = newDisplayCtx(w, h, title)
    ctx.setup(verticalSync=vsync,
              fullscreen=doFullscreen,
              resizable=doResize)

    defer: ctx.cleanup()
    ctx.doCheckBasicEvents = true
    app.ctx = ctx

    app.init()

    var
      # keep track of frameCount
      frameCount: int

      # Frames per second timer
      fpsTimer: Timer = new Timer
      nextReportSeconds: float

    # game loop!
    fpsTimer.start()

    gl.glClearColor(0.25f, 0.25f, 0.25f, 1.0f)

    while not ctx.quitRequested:

      # update the deltaTime for app writers!
      let curTime = simpleutils.getTicks()

      # deltaTime is zero first time around
      app.deltaTime =
        if app.lastFrameTime == 0:
          0.0
        else:
          curTime - app.lastFrameTime

      app.lastFrameTime = curTime

      # process events
      for e in ctx.getEvents():
        app.handleEvent(e)

      if ctx.windowResized:
        app.onResized(ctx.width, ctx.height)
        ctx.windowResized = false

      app.update(app.deltaTime)
      app.draw()

      ctx.update()

      # Calculate and correct fps
      let secondsElapsed: float = fpsTimer.getTicks()
      let avgFPS: float = frameCount.float / secondsElapsed

      if secondsElapsed > nextReportSeconds:
        l_debug("FPS:", avgFPS)
        nextReportSeconds = secondsElapsed.ceil() + 5.0

      frameCount += 1

    # cleanup
    for vao in app.vaoRegistry.values():
      vao.unbind()

    for program in app.programRegistry.values():
      program.stop()

    app.ctx.cleanup()

  # call main()
  main()
