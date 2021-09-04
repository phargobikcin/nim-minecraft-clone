# TODO ibo -> ebo
import nimgl/opengl as gl

import simpleutils
import logsetup as logging


type

  Buffer* = ref object
    id: GLuint

  IndexBuffer* = ref object
    id: GLuint
    count: int

  VertexBufferElement* = object
    glType: GLenum
    count: int
    normalized: bool

  VertexBufferLayout* = ref object
    elements: seq[VertexBufferElement]
    stride: int

  VertexArrayObject* = ref object
    id: GLuint
    attributes: seq[GLuint]
    ibo: IndexBuffer
    vbos: seq[Buffer]

proc `=destroy`*(vbo: var typeOfDeref(Buffer)) =
  l_warning("destroying VBO: " & $vbo.id)
  glDeleteBuffers(1, addr vbo.id)

proc `=destroy`*(ibo: var typeOfDeref(IndexBuffer)) =
  l_warning("destroying IBO: " & $ibo.id)
  glDeleteBuffers(1, addr ibo.id)

proc `=destroy`*(vao: var typeOfDeref(VertexArrayObject)) =
  l_warning("destroying VAO: " & $vao.id)
  glDeleteVertexArrays(1, addr vao.id)

  # XXX is this what I am suppose to do?
  if vao.ibo != nil:
    `=destroy`(vao.ibo)
  `=destroy`(vao.vbos)

# binds
proc doBind*(vbo: Buffer) =
  glBindBuffer(GL_ARRAY_BUFFER, vbo.id)

proc doBind*(ibo: IndexBuffer) =
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo.id)

proc doBind*(vao: VertexArrayObject) =
  glBindVertexArray(vao.id)
  for attr in vao.attributes:
    glEnableVertexAttribArray(attr)

proc unbind*(vbo: Buffer) =
  glBindBuffer(GL_ARRAY_BUFFER, 0)

proc uinbind*(ibo: IndexBuffer) =
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0)

proc unbind*(vao: VertexArrayObject) =
  for attr in vao.attributes:
    glDisableVertexAttribArray(attr)
  glBindVertexArray(0)

# forward
proc sizeOfElement*(element: VertexBufferElement): int

proc addBuffer*(vao: VertexArrayObject, vbo: Buffer, layout: VertexBufferLayout) =
  #vao.doBind()
  # XXX assert is bound
  vbo.doBind()

  var offset: ByteAddress

  # XXX index should be incremented manually, so we can all addBuffer() many times
  # I guess with different vbo (probably not enforced though - we should test this)
  for i, element in layout.elements:
    let index = len(vao.attributes)
    glVertexAttribPointer(index=index.GLuint,
                          element.count.GLint,
                          element.glType,
                          element.normalized,
                          layout.stride.GLsizei,
                          cast[pointer](offset))
    # XXX is this necessary at this point?, bind() will enable for use later.
    glEnableVertexAttribArray(index.GLuint)
    vao.attributes.add(index.GLuint)

    let ptrIncr = element.count * element.sizeOfElement()
    offset += ptrIncr

  # so memory is deleted when VAO goes away
  vao.vbos.add(vbo)

  # note that this is allowed, the call to glVertexAttribPointer registered VBO as the vertex
  # attribute's bound vertex buffer object so afterwards we can safely unbind
  vbo.unbind()

proc attach*(vao: VertexArrayObject, ibo: IndexBuffer) =
  # The last element buffer object that gets bound while a VAO is bound, is stored as the VAO's
  # element buffer object.  Binding to a VAO then also automatically binds that EBO.
  ibo.doBind()

  # we store it so we can unbind and
  vao.ibo = ibo

proc newVertexArrayObject*(): VertexArrayObject =
  result = VertexArrayObject()
  glGenVertexArrays(1, addr result.id)
  result.doBind()

proc newVertexBuffer*(data: openArray[float32]): Buffer =
  result = Buffer()
  glGenBuffers(1, addr result.id)
  result.doBind()
  let size: GLsizei = (sizeof(float32) * len(data)).GLsizei
  glBufferData(GL_ARRAY_BUFFER, size, unsafe_addr data, GL_STATIC_DRAW)
  # returns bound

proc newIndexBuffer*(data: openArray[uint32]): IndexBuffer =
  result = IndexBuffer(count: len(data))
  glGenBuffers(1, addr result.id)
  result.doBind()
  let size: GLsizei = (sizeof(uint32) * len(data)).GLsizei
  glBufferData(GL_ELEMENT_ARRAY_BUFFER, size, unsafe_addr data, GL_STATIC_DRAW)
  # returns bound

proc draw*(vao:VertexArrayObject, primitives=GL_TRIANGLES) =
  glDrawElements(primitives, vao.ibo.count.GLsizei, GL_UNSIGNED_INT, nil)

proc drawArrays*(vao:VertexArrayObject, count: int, primitives=GL_TRIANGLES) =
  glDrawArrays(primitives, 0, count.GLsizei)

proc sizeOfElement*(element: VertexBufferElement): int =
  case element.glType:
    of EGL_FLOAT: sizeof(float32)
    of GL_UNSIGNED_INT: sizeof(uint32)
    of GL_UNSIGNED_BYTE: sizeof(uint8)
    else: raise newException(Defect, "Unsupported type: " & $element.glType.uint32)

proc add*(layout: VertexBufferLayout, glType: GLenum, count: int) =
  let element = case glType:
     of EGL_FLOAT: VertexBufferElement(glType: glType, count: count, normalized: true)
     of GL_UNSIGNED_INT: VertexBufferElement(glType: glType, count: count, normalized: true)
     of GL_UNSIGNED_BYTE: VertexBufferElement(glType: glType, count: count, normalized: false)
     else: raise newException(Defect, "Unsupported type: " & $glType.uint32)

  layout.elements.add(element)
  layout.stride += count * element.sizeOfElement()

proc addBuffer*(vao: VertexArrayObject, vbo: Buffer, glType: GLenum, count: int) =
  # simple helper
  let layout = VertexBufferLayout()
  layout.add(glType, count)
  addBuffer(vao, vbo, layout)

