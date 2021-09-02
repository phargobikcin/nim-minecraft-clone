import os
import nimgl/opengl

import thin/simpleutils
import thin/logsetup as logging

import thin/stb_image/stbi as stbi

type
  TextureManager* = ref object
    width: int
    height: int
    maxTextures: int

    # an array to keep track of the textures we've already added
    textureNames: seq[string]

    # openGL texture id
    textureId: GLuint

proc `=destroy`*(self: var typeOfDeref(TextureManager)) =
  glDeleteTextures(1, addr self.textureId)
  l_warning(f"Destroying TextureManager")

proc newTextureManager*(width, height, maxTextures: int): TextureManager =
  result = TextureManager(width:width, height:height, maxTextures:maxTextures)

  glGenTextures(1, addr result.textureId)
  glBindTexture(GL_TEXTURE_2D_ARRAY, result.textureId)

  # disable texture filtering for magnification (return the texel that's nearest to the fragment's
  # texture coordinate)
  glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_NEAREST.GLint)
  glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_NEAREST.GLint)

  glTexImage3D(GL_TEXTURE_2D_ARRAY, 0, GL_RGBA.GLsizei,
               result.width.GLsizei, result.height.GLsizei, result.maxTextures.GLsizei,
               0, GL_RGBA, GL_UNSIGNED_BYTE, nil)

proc doBind*(self: TextureManager, slot: uint32 = 0) =
  glBindTexture(GL_TEXTURE_2D_ARRAY, self.textureId)
  glActiveTexture((GL_TEXTURE0.ord + slot).GLenum)

proc unbind*(self: TextureManager) =
  glBindTexture(GL_TEXTURE_2D_ARRAY, 0)

proc generateMipmaps*(self: TextureManager) =
  ## generate mipmaps for our texture
  self.doBind()
  glGenerateMipmap(GL_TEXTURE_2D_ARRAY)
  self.unbind()

proc addTexture*(self: TextureManager, name: string): int =

  # check to see if our texture has not yet been added
  if name in self.textureNames:
    return self.textureNames.find(name)

  # add it to our textures list if not
  self.textureNames.add(name)

  # load and get the image data of the texture we want
  let path = os.joinPath(os.splitPath(system.currentSourcePath).head, "textures", f"{name}.png")
  let image = stbi.loadImage(path, 4, flip=true)

  # make sure our texture array is bound
  self.doBind()

  # paste our texture's image data in the appropriate spot in our texture array
  let zPos = self.textureNames.find(name)
  l_info(f"""adding texture "{name}" to textureManager, at position {zPos}""")
  l_verbose(f"the image: {image}")
  glTexSubImage3D(GL_TEXTURE_2D_ARRAY,
                  0, 0, 0, zPos.GLsizei,
                  self.width.GLsizei, self.height.GLsizei, 1,
                  GL_RGBA, GL_UNSIGNED_BYTE,
                  addr image.data[0])

  return zPos
