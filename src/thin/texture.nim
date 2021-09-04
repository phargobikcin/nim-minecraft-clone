import nimgl/opengl

import simpleutils
import stb_image/stbi as stbi
import logsetup as logging

type
  Texture* = ref object
    id: GLuint
    image: STBImage

proc `=destroy`*(self: var typeOfDeref(Texture)) =
  glDeleteTextures(1, self.id.addr)

proc doBind*(self: Texture, slot: uint32 = 0) =
  glBindTexture(GL_TEXTURE_2D, self.id)
  glActiveTexture((GL_TEXTURE0.ord + slot).GLenum)

proc unbind*(self: Texture) =
  glBindTexture(GL_TEXTURE_2D, 0)

proc newTexture*(path: string, flip: bool): Texture =

  var textureId: GLuint
  glGenTextures(1, addr textureId)
  glBindTexture(GL_TEXTURE_2D, textureId)


  let image = stbi.loadImage(path, 4, flip)
  result = Texture(id: textureId, image: image)
  l_verbose(f"image size {image.width} {image.height}")
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA.GLsizei,
               image.width.GLsizei, image.height.GLsizei,
               0, GL_RGBA, GL_UNSIGNED_BYTE, addr image.data[0])

  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR.GLint)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR.GLint)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT.GLint)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT.GLint)

  glBindTexture(GL_TEXTURE_2D, 0)

