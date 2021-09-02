include thin/simpleapp

from ./numbers import nil

type
  MinecraftClone = ref object of App
    shaderMatrixLocation: int
    x: float32


let vertGLSL = """
#version 330

layout(location = 0) in vec3 vertex_position;

out vec3 local_position;
uniform mat4 matrix; // create matrix uniform variable

void main(void) {
	local_position = vertex_position;
        // multiply matrix by vertex_position vector
	gl_Position = matrix * vec4(vertex_position, 1.0);
}"""

let fragGLSL = """
#version 330

out vec4 fragment_colour;

in vec3 local_position;

void main(void) {
	fragment_colour = vec4(local_position / 2.0 + 0.5, 1.0);
}"""


method update(self: MinecraftClone) =
  self.x += self.deltaTime


method init(self: MinecraftClone) =
  # enable depth testing so faces are drawn in the right order
  glEnable(GL_DEPTH_TEST)

  # create buffers
  let vbo = newVertexBuffer(numbers.vertexPositions)
  let ibo = newIndexBuffer(numbers.indices)

  # create vertex buffer object
  let vao = newVertexArrayObject()
  vao.addBuffer(vbo, EGL_FLOAT, 3)
  vao.attach(ibo)

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

method clear*(self: MinecraftClone) =
  # clear colour / depth
  gl.glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)


method draw(self: MinecraftClone) =
  # create projection matrix
  let pMatrix = gamemaths.perspective(90.float32,
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
  start(MinecraftClone, w=800, h=600, title="Minecraft clone", doResize=true, vsync=false)
