import tables

from sdl2_nim/sdl import Event, Keysym

import thin/gamemaths
include thin/simpleapp

import block_type, texture_manager, camera

type
  MinecraftClone = ref object of App
    shaderSamplerLocation: int
    textureManager: TextureManager
    blocks: Table[string, BlockType]
    mouseCaptured: bool
    camera: Camera

let vertGLSL = """
#version 330

layout(location = 0) in vec3 vertex_position;
layout(location = 1) in vec3 tex_coords;
layout(location = 2) in float shading_value;

out vec3 local_position;
out vec3 interpolated_tex_coords;
out float interpolated_shading_value;

uniform mat4 matrix;

void main(void) {
       interpolated_tex_coords = tex_coords;
       interpolated_shading_value = shading_value;
       gl_Position = matrix * vec4(vertex_position, 1.0);
}"""

let fragGLSL = """
#version 330

out vec4 fragment_colour;

uniform sampler2DArray texture_array_sampler;

in vec3 interpolated_tex_coords;
in float interpolated_shading_value;

void main(void) {
      fragment_colour = texture(texture_array_sampler, interpolated_tex_coords) * interpolated_shading_value;
}"""


###############################################################################

proc createBlocks(self: MinecraftClone) =
  # create our texture manager (256 textures that are 16 x 16 pixels each)
  self.textureManager = newTextureManager(16, 16, 256)

  # create each one of our blocks with the texture manager and a list of textures per face
  let blocks = @[newBlockType(self.textureManager, "cobblestone", {"all": "cobblestone"}.toTable),
                 newBlockType(self.textureManager, "grass", {"top": "grass", "bottom": "dirt", "sides": "grass_side"}.toTable),
                 newBlockType(self.textureManager, "dirt", {"all": "dirt"}.toTable),
                 newBlockType(self.textureManager, "stone", {"all": "sand"}.toTable),
                 newBlockType(self.textureManager, "planks", {"all": "planks"}.toTable),
                 newBlockType(self.textureManager, "log", {"top": "log_top", "bottom": "log_top", "sides": "log_side"}.toTable)]

  # generate mipmaps for our texture manager's texture
  self.textureManager.generateMipmaps()

  # store in table for future use
  for b in blocks:
    self.blocks[b.name] = b


method init(self: MinecraftClone) =
  self.createBlocks()

  # this is block to test
  const blockNameTest = "cobblestone"

  # enable depth testing so faces are drawn in the right order
  glEnable(GL_DEPTH_TEST)

  # get block we want to renderer
  let testBlock = self.blocks[blockNameTest]

  # create vertex buffer object
  let vao = newVertexArrayObject()
  vao.addBuffer(newVertexBuffer(testBlock.vertexPositions), EGL_FLOAT, 3)
  vao.addBuffer(newVertexBuffer(testBlock.texCords), EGL_FLOAT, 3)
  vao.addBuffer(newVertexBuffer(testBlock.shadingValues), EGL_FLOAT, 1)
  vao.attach(newIndexBuffer(testBlock.indices))

  # store vao in application (so can have more than one vao)
  self.add("quad", vao)
  vao.unbind()

  # leave vao bound... not best practice
  vao.doBind()

  # create shader
  let shader = shading.program(vertGLSL, fragGLSL)
  self.add("shader", shader)
  shader.use()

  self.shaderSamplerLocation = shader.findUniform("texture_array_sampler")

  # it is zero by default
  # self.program.setUniform(self.shaderSamplerLocation, 0)

  # leave textures bound
  self.textureManager.doBind()

  # create the camera
  self.camera = newCamera(shader, self.ctx.width, self.ctx.height)

###############################################################################

method onResized(self: MinecraftClone, width, height: int) =
  self.camera.updatePMatrix(width, height)

proc onMouseMotion(self: MinecraftClone, x, y: int) =
  if self.mouseCaptured:
    let sensitivity = 0.004f

    # this needs to be negative since turning to the left decreases delta_x while increasing the x
    # rotation angle
    self.camera.rotation.x -= x.float32 * sensitivity
    self.camera.rotation.y += y.float32 * sensitivity

    # clamp the camera's up / down rotation so that you can't snap your neck
    self.camera.rotation.y = max(-math.TAU / 4, min(math.TAU / 4, self.camera.rotation.y))
    echo self.camera.rotation

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
  # clear colour / depth
  gl.glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)

method draw(self: MinecraftClone) =
  self.camera.updateMatrices()

  glClearColor(0.0, 0.0, 0.0, 1.0)
  self.clear()
  self.vao.draw()


###############################################################################

when isMainModule:
  start(MinecraftClone, system.currentSourcePath,
        w=800, h=600, title="Minecraft clone", doResize=true, vsync=true, doFullscreen=false)
