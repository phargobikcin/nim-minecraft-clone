include thin/simpleapp

type
  MinecraftClone = ref object of App

let vertices = [
  -0.5f,  0.5, 1.0,
  -0.5, -0.5, 1.0,
  0.5, -0.5, 1.0,
  0.5,  0.5, 1.0,
]

let indices = [
  # first triangle
  0.uint32, 1, 2,

  # second triangle
  0, 2, 3
]



let vertGLSL = """
#version 330 // specify we are indeed using modern opengl

layout(location = 0) in vec3 vertex_position; // vertex position attribute

out vec3 local_position; // interpolated vertex position

void main(void) {
	local_position = vertex_position;
	gl_Position = vec4(vertex_position, 1.0); // set vertex position
}
"""

let fragGLSL = """
#version 330 // specify we are indeed using modern opengl

out vec4 fragment_colour; // output of our shader

in vec3 local_position;  // interpolated vertex position

void main(void) {
	fragment_colour = vec4(local_position / 2.0 + 0.5, 1.0); // set the output colour based on the vertex position
}"""



method init(self: MinecraftClone) =

  # create buffers
  let vbo = newVertexBuffer(vertices)
  let ibo = newIndexBuffer(indices)

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
  shader.use()

method draw(self: MinecraftClone) =
  glClearColor(0.0, 0.0, 0.0, 1.0)
  self.clear()
  self.vao.draw()


when isMainModule:
  start(MinecraftClone, system.currentSourcePath,
        w=800, h=600, title="Minecraft clone", doResize=true, vsync=false)
