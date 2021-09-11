import simpleutils

import sdl2_nim/sdl as sdl
from nimgl/opengl as gl import nil

import logsetup as logging

type
  DisplayCtx* = ref DisplayCtxObj
  DisplayCtxObj = object
    width*: int
    height*: int
    title: string
    windowResized*: bool
    quitRequested*: bool
    window: sdl.Window
    glContext: sdl.GLContext
    glContextCreated: bool

    # XXX todo
    imguiEnabled: bool

    doCheckBasicEvents*: bool

# XXX inherting from OSError, not sure that is best...
type DisplayException = object of OSError


###############################################################################
# prototypes
###############################################################################

proc handleWindowEvent(self: DisplayCtx, e: sdl.Event)
proc doResize(self: DisplayCtx)

###############################################################################
# implementation
###############################################################################

proc newDisplayCtx*(width, height: int,
                    title: string): DisplayCtx =

  result = DisplayCtx(width: width,
                      height: height,
                      title: title,
                      windowResized: false,
                      quitRequested: false,
                      window: nil,
                      glContext: nil,
                      glContextCreated: false)

template fatalError(s: string) =
  l_critical(s)
  raise newException(DisplayException, s)

template fatalSDLError(s: string) =
  let error = "ERROR: sdl.createWindow(): " & $sdl.getError()
  l_critical(error)
  raise newException(DisplayException, error)

proc debugMessage(source: gl.GLenum,
                  typ: gl.GLenum,
                  id: gl.GLuint,
                  severity: gl.GLenum,
                  length: gl.GLsizei,
                  message: ptr gl.GLchar,
                  userParam: pointer) {.stdcall.} =

  let messageStr = $(cast[cstring](message))
  let severityStr =
    case severity:
      of gl.GL_DEBUG_SEVERITY_LOW:
        "low"
      of gl.GL_DEBUG_SEVERITY_NOTIFICATION:
        "notification"
      of gl.GL_DEBUG_SEVERITY_MEDIUM:
        "medium"
      of gl.GL_DEBUG_SEVERITY_HIGH:
        "high"
      else:
        "unknown"

  let msg = f"From OpenGL({severityStr}): {messageStr}"

  case severity:
    of gl.GL_DEBUG_SEVERITY_LOW, gl.GL_DEBUG_SEVERITY_NOTIFICATION:
      l_info(msg)

    else:
      l_error(msg)
      let trace = getStackTrace()
      l_warning(trace)

proc setup*(self: DisplayCtx,
            fullscreen = false,
            resizable = true,
            verticalSync = true) =

  # initialise SDL
  if sdl.init(sdl.INIT_VIDEO) != 0:
    fatalSDLError("Could not initialize SDL: ")

  discard glSetAttribute(GLattr.GL_CONTEXT_PROFILE_MASK, GL_CONTEXT_PROFILE_CORE)

  discard glSetAttribute(GLattr.GL_CONTEXT_FLAGS,
                         GL_CONTEXT_DEBUG_FLAG or GL_CONTEXT_FORWARD_COMPATIBLE_FLAG)

  # 4.3 for debug to work?
  discard glSetAttribute(GLattr.GL_CONTEXT_MAJOR_VERSION, 4)
  discard glSetAttribute(GLattr.GL_CONTEXT_MINOR_VERSION, 3)
  discard glSetAttribute(GLattr.GL_DOUBLEBUFFER, 1)
  discard glSetAttribute(GLattr.GL_MULTISAMPLEBUFFERS, 1)
  discard glSetAttribute(GLattr.GL_MULTISAMPLESAMPLES, 16)

  # create window
  let createFlags: uint32 =
    if resizable:
      sdl.WINDOW_OPENGL or sdl.WINDOW_SHOWN or sdl.WINDOW_RESIZABLE
    else:
      sdl.WINDOW_OPENGL or sdl.WINDOW_SHOWN

  self.window = sdl.createWindow(
    self.title,
    sdl.WINDOWPOS_CENTERED,
    sdl.WINDOWPOS_CENTERED,
    self.width,
    self.height,
    createFlags)

  if self.window == nil:
    fatalSDLError("error in sdl.createWindow(): ")

  if fullscreen:
    if sdl.setWindowFullscreen(self.window, sdl.WINDOW_FULLSCREEN_DESKTOP) != 0:
      fatalSDLError("error in sdl.setWindowFullscreen: ")

  self.glContext = sdl.glCreateContext(self.window)
  if self.glContext == nil:
    fatalSDLError("Can't create OpenGL context: ")

  # why this?
  discard sdl.glMakeCurrent(self.window, self.glContext)
  self.glContextCreated = true

  if not gl.glInit():
    fatalError("OpenGL not loaded correctly.")

  # syncs with monitor's vertical refresh
  if sdl.glSetSwapInterval(ord(verticalSync)) < 0:
    l_warning("Warning: Unable to set Vsync: " & $sdl.getError())

  proc getGLString(name: gl.GLenum): string =
    var tmp: cstring = cast[cstring](gl.glGetString(name))
    return $tmp

  l_debug("Context created with OpenGL: ", getGLString(gl.GL_VERSION))
  l_debug("Vendor: ", getGLString(gl.GL_VENDOR))
  l_debug("Renderer: ", getGLString(gl.GL_RENDERER))
  l_debug("Shading language version: ", getGLString(gl.GL_SHADING_LANGUAGE_VERSION))

  var numAttributes: int32
  gl.glGetIntegerv(gl.GL_MAX_VERTEX_ATTRIBS, addr numAttributes)
  l_debug("Maximum # of vertex attributes supported: ", numAttributes)
  l_debug("Extensions: ", getGLString(gl.GL_EXTENSIONS))

  # openGL debug messages
  gl.glEnable(gl.GL_DEBUG_OUTPUT)
  gl.glEnable(gl.GL_DEBUG_OUTPUT_SYNCHRONOUS)
  gl.glDebugMessageCallback(debugMessage, nil)

  self.doResize()

proc cleanup*(self: DisplayCtx) =
  if self.glContextCreated:
    sdl.glDeleteContext(self.glContext)

  if self.window != nil:
    sdl.destroyWindow(self.window)

  sdl.quit()


# XXX
# proc toggleImGui(self: DisplayCtx) =
#   if not self.imgui_enabled:
#     let context = igCreateContext()
#     doAssert igGlfwInitForOpenGL(w, true)
#     doAssert igOpenGL3Init()
#     igStyleColorsDark()
#     #igStyleColorsCherry()

proc doResize(self: DisplayCtx) =
  self.windowResized = true
  var w, h : cint
  sdl.glGetDrawableSize(self.window, addr w, addr h)
  self.width = w
  self.height = h
  gl.glViewport(0, 0, self.width, self.height)


proc checkBasicEvents(self: DisplayCtx, e: sdl.Event): bool =
  if e.kind == sdl.QUIT:
    self.quitRequested = true
    return true

  elif e.kind == sdl.WINDOWEVENT:
    self.handleWindowEvent(e)
    return true

  elif e.kind == sdl.KEYDOWN:
    case e.key.keysym.sym:
      of sdl.K_ESCAPE:
        self.quitRequested = true
        return true
      else:
        discard
  else:
    discard

  return false


proc handleWindowEvent(self: DisplayCtx, e: sdl.Event) =
  # Show what key was pressed
  assert e.kind == sdl.WINDOWEVENT

  var resized = false

  case e.window.event:
    of sdl.WINDOWEVENT_RESIZED:
      resized = true
    of sdl.WINDOWEVENT_SIZE_CHANGED:
      resized = true
    else:
      discard

  if resized:
    self.doResize()

iterator getEvents*(self: DisplayCtx): sdl.Event =
  var e: sdl.Event
  while sdl.pollEvent(addr e) != 0:
    if self.doCheckBasicEvents and self.checkBasicEvents(e):
      continue
    yield e


proc update*(self: DisplayCtx) =
  sdl.glSwapWindow(self.window)


