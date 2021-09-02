import nimgl/opengl

import simpleutils
import stb_image/stbi as stbi
import logsetup as logging

type
  Texture* = ref object
    id: GLuint
    image: STBImage

  Texture2d* = ref object
    id: GLuint
    images: seq[STBImage]

proc `=destroy`*(self: var typeOfDeref(Texture)) =
  glDeleteTextures(1, self.id.addr)

proc `=destroy`*(self: var typeOfDeref(Texture2)) =
  glDeleteTextures(1, self.id.addr)

proc `=destroy`*(self: var typeOfDeref(Texture2d)) =
  glDeleteTextures(1, self.id.addr)

# generic goodness
type
  AllTexture = Texture | Texture2

proc doBind*(self: AllTexture, slot: uint32 = 0) =
  glBindTexture(GL_TEXTURE_2D, self.id)
  glActiveTexture((GL_TEXTURE0.ord + slot).GLenum)

proc unbind*(self: AllTexture) =
  glBindTexture(GL_TEXTURE_2D, 0)


proc doBind*(self: Texture2d, slot: uint32 = 0) =
  glBindTexture(GL_TEXTURE_2D_ARRAY, self.id)
  glActiveTexture((GL_TEXTURE0.ord + slot).GLenum)

proc unbind*(self: Texture2d) =
  glBindTexture(GL_TEXTURE_2D_ARRAY, 0)

proc newTexture*(path: string, flip: bool): Texture =

  #echo repr(image)
  var textureId: GLuint
  glGenTextures(1, addr textureId)
  glBindTexture(GL_TEXTURE_2D, textureId)


  let image = stbi.loadImage(path, 4, flip)
  result = Texture(id: textureId,
                   image: image)
  l_verbose(f"image size {image.width} {image.height}")
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA.GLsizei,
               image.width.GLsizei, image.height.GLsizei,
               0, GL_RGBA, GL_UNSIGNED_BYTE, addr image.data[0])

  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR.GLint)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR.GLint)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT.GLint)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT.GLint)

  glBindTexture(GL_TEXTURE_2D, 0)


# proc newTexture2d*(images: seq[pixie.Image]): Texture2d =

#   #echo repr(image)
#   var textureId: GLuint
#   glGenTextures(1, addr textureId)
#   glBindTexture(GL_TEXTURE_2D_ARRAY, textureId)

#   result = Texture2d(id: textureId)

#   glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_NEAREST.GLint)
#   glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_NEAREST.GLint)
#   #glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_S, GL_REPEAT.GLint)
#   #glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_T, GL_REPEAT.GLint)

#   let width = images[0].width.GLsizei
#   let height = images[0].height.GLsizei
#   # should be length of seq XXX
#   let depth: GLsizei = 32

#   l_verbose(f"creating glTexImage3D {width} {height} {depth}")
#   glTexImage3D(GL_TEXTURE_2D_ARRAY, 0, GL_RGBA.GLsizei,
#                width, height, depth,
#                0, GL_RGBA, GL_UNSIGNED_BYTE, nil)

#   var ii: GLsizei = 0
#   for image in images:
#     let newImage = image.copy()
#     l_verbose(f"creating glTexSubImage3D {newImage.width} {ii}")
#     echo image.width, "x", image.height
#     glTexSubImage3D(GL_TEXTURE_2D_ARRAY, 0, 0, 0, ii,
#                     width, height, 1,
#                     GL_RGBA, GL_UNSIGNED_BYTE,
#                     addr newImage.data[0])

#     result.images.add(newImage)
#     inc(ii)

#   glGenerateMipmap(GL_TEXTURE_2D_ARRAY)
#   glBindTexture(GL_TEXTURE_2D_ARRAY, 0)
