include thin/simpleapp

import thin/gamemaths

import tables
import block_type
import texture_manager

type
  MinecraftClone = ref object of App
    shaderMatrixLocation: int
    shaderSamplerLocation: int
    x: float32
    textureManager: TextureManager
    blocks: Table[string, BlockType]

let vertGLSL = """
#version 330

layout(location = 0) in vec3 vertex_position;
layout(location = 1) in vec3 tex_coords; // texture coordinates attribute

out vec3 local_position;
out vec3 interpolated_tex_coords; // interpolated texture coordinates

uniform mat4 matrix;

void main(void) {
	interpolated_tex_coords = tex_coords;
	gl_Position = matrix * vec4(vertex_position, 1.0);
}"""

let fragGLSL = """
#version 330

out vec4 fragment_colour;

uniform sampler2DArray texture_array_sampler; // create our texture array sampler uniform

in vec3 interpolated_tex_coords; // interpolated texture coordinates

void main(void) {
	fragment_colour = texture(texture_array_sampler, interpolated_tex_coords); // sample our texture array with the interpolated texture coordinates
}"""


method update(self: MinecraftClone, deltaTime: float) =
  self.x += deltaTime


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
  const blockNameTest = "grass"

  # enable depth testing so faces are drawn in the right order
  glEnable(GL_DEPTH_TEST)

  # get block we want to renderer
  let testBlock = self.blocks[blockNameTest]

  # create vertex buffer object
  let vao = newVertexArrayObject()
  vao.addBuffer(newVertexBuffer(testBlock.vertexPositions), EGL_FLOAT, 3)
  vao.addBuffer(newVertexBuffer(testBlock.texCords), EGL_FLOAT, 3)
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

  self.shaderMatrixLocation = shader.findUniform("matrix")
  self.shaderSamplerLocation = shader.findUniform("texture_array_sampler")

  # it is zero by default
  # self.program.setUniform(self.shaderSamplerLocation, 0)

  # leave textures bound
  self.textureManager.doBind()


method clear*(self: MinecraftClone) =
  # clear colour / depth
  gl.glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)


method draw(self: MinecraftClone) =
  # create projection matrix
  let pMatrix = gamemaths.perspective(90f,
                                      (self.ctx.width / self.ctx.height).float32,
                                      0.1,
                                      500)

  # create model view matrix
  var mvMatrix = gamemaths.translate(vec3(0, 0, -3))

  # funky rotating, I don't pretend to understand
  proc rotate2D(x, y: float32) =
    mvMatrix = mvMatrix * gamemaths.rotate(x, vec3(0, 1.0, 0))
    mvMatrix = mvMatrix * gamemaths.rotate(-y, vec3(math.cos(x), 0, math.sin(x)))

  rotate2D(self.x, math.sin(self.x / 3 * 2) / 2)

  let mvpMatrix = pMatrix * mvMatrix
  self.program.setUniform(self.shaderMatrixLocation, mvpMatrix)

  glClearColor(0.0, 0.0, 0.0, 1.0)
  self.clear()
  self.vao.draw()


when isMainModule:
  start(MinecraftClone, system.currentSourcePath,
        w=800, h=600, title="Minecraft clone", doResize=true, vsync=false, doFullscreen=false)
