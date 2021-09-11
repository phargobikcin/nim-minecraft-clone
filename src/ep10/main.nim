import tables

from sdl2_nim/sdl import Event, Keysym

import thin/gamemaths
import block_manager, camera, world

include thin/simpleapp


###############################################################################

type
  MinecraftClone = ref object of App
    mouseCaptured: bool
    camera: Camera

    blockManager: BlockManager
    world: World


###############################################################################

let vertGLSL = """
#version 330

layout(location = 0) in vec3 vertex_position;
layout(location = 1) in vec3 tex_coords;
layout(location = 2) in float shading_value;

out vec3 local_position;
out vec3 interpolated_tex_coords;
out float interpolated_shading_value;

uniform mat4 view;
uniform mat4 perspective;

void main(void) {
  interpolated_tex_coords = tex_coords;
  interpolated_shading_value = shading_value;
  gl_Position = perspective * view * vec4(vertex_position, 1.0);
}
"""

let fragGLSL = """
#version 330

out vec4 fragment_colour;

uniform sampler2DArray texture_array_sampler;

in vec3 interpolated_tex_coords;
in float interpolated_shading_value;

void main(void) {
  vec4 texture_colour = texture(texture_array_sampler, interpolated_tex_coords);
  fragment_colour = texture_colour * interpolated_shading_value;
  if (texture_colour.a == 0.0) {
    discard;
  }
}
"""

###############################################################################

method init(self: MinecraftClone) =
  # enable depth testing so faces are drawn in the right order
  glEnable(GL_DEPTH_TEST)
  glEnable(GL_CULL_FACE)
  glEnable(GL_MULTISAMPLE)

  self.blockManager = newBlockManager()
  self.world = newWorld(self.blockManager)
  self.world.fixedWorld()
  #self.world.randomWorld()

  # create shader
  let shader = shading.program(vertGLSL, fragGLSL)
  self.add("shader", shader)
  shader.use()

  # create the camera
  self.camera = newCamera(shader, self.ctx.width, self.ctx.height)


###############################################################################

method onResized(self: MinecraftClone, width, height: int) =
  self.camera.updatePerspective(width, height)

proc onMouseMotion(self: MinecraftClone, x, y: int) =
  if self.mouseCaptured:
    let sensitivity = 0.004f

    self.camera.rotation.x -= x.float32 * sensitivity
    self.camera.rotation.y += y.float32 * sensitivity

    # clamp the camera's up / down rotation so that you can't snap your neck
    self.camera.rotation.y = max(-math.TAU / 4, min(math.TAU / 4, self.camera.rotation.y))

proc onKey(self: MinecraftClone, pressed: bool, keysym: Keysym) =
  if not self.mouseCaptured:
    return

  let rel: int32 = if pressed: 1 else: -1

  case keysym.sym:
    of sdl.K_d:
      self.camera.movementInput.x += rel
    of sdl.K_a:
      self.camera.movementInput.x -= rel
    of sdl.K_w:
      self.camera.movementInput.z += rel
    of sdl.K_s:
      self.camera.movementInput.z -= rel
    of sdl.K_SPACE:
      self.camera.movementInput.y += rel
    of sdl.K_LSHIFT:
      self.camera.movementInput.y -= rel
    else:
      discard

method handleEvent(self: MinecraftClone, event: Event) =
  if event.kind == sdl.MOUSEBUTTONDOWN and event.button.button == sdl.BUTTON_LEFT:
    self.mouseCaptured = not self.mouseCaptured
    discard sdl.setRelativeMouseMode(self.mouseCaptured)

  elif event.kind == sdl.MOUSEMOTION:
    self.onMouseMotion(event.motion.xrel, event.motion.yrel)

  elif event.kind == sdl.KEYDOWN and event.key.repeat == 0:
    self.onKey(true, event.key.keysym)

  elif event.kind == sdl.KEYUP and event.key.repeat == 0:
    self.onKey(false, event.key.keysym)


###############################################################################

method update(self: MinecraftClone, deltaTime: float) =
  if not self.mouseCaptured:
    self.camera.movementInput = ivec3()

  self.camera.updatePosition(deltaTime)


###############################################################################

method clear(self: MinecraftClone) =
  gl.glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)


method draw(self: MinecraftClone) =
  glClearColor(0.0, 0.0, 0.0, 1.0)
  self.clear()

  self.camera.updateView()

  self.world.draw()

###############################################################################

when isMainModule:
  start(MinecraftClone, system.currentSourcePath,
        w=1024, h=768, title="Minecraft clone", doResize=true, vsync=false, doFullscreen=false)

