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

method draw(self: MinecraftClone) =
  glClearColor(1.0, 0.5, 1.0, 1.0)
  self.clear()
  self.vao.draw()


when isMainModule:
  start(MinecraftClone, w=800, h=600, title="Minecraft clone", doResize=true, vsync=false)
