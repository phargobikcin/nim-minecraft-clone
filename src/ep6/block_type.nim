import tables
import ./numbers
import texture_manager

type
  BlockType* = ref object
    name*: string
    # XXX should these be public?
    vertexPositions*: seq[float32]
    texCords*: seq[float32]
    indices*: seq[uint32]


proc newBlockType*(manager: TextureManager,
                   name = "unknown",
                   blockFaceTextures = {"all": "cobblestone"}.toTable): BlockType =

  # set our block type's vertex positions, texture coordinates, and indices to the default values
  # in our numbers.nim file
  var blockType = BlockType(name: name,
                            vertexPositions: numbers.vertexPositions,
                            texCords: numbers.texCords,
                            indices: numbers.indices)

  # note, these are copies.  This is handy for texCords, since we need to modify our texture
  # coordinates in a different way for each block type (to have different textures per block)

  proc setBlockFace(facePos: int, texturePos: int) =
    # set a specific face of the block to a certain texture
    for vertex in 0..3:
      blockType.texCords[facePos * 12 + vertex * 3 + 2] = texturePos.float32

  # go through all the block faces we specified a texture for
  for face, textureName in blockFaceTextures.pairs():

    # add that texture to our texture manager.
    # the texture manager will make sure it hasn't already been added itself.
    # returns texture's Z component in our texture array, so can modify texture texture
    # coordinates of each face
    let cordZIndex = manager.addTexture(textureName)

    if face == "all":
      # set the texture for all faces
      for i in 0..5:
        setBlockFace(i, cordZIndex)

    elif face == "sides":
      # set the texture for only the sides
      for i in [0, 1, 4, 5]:
        setBlockFace(i, cordZIndex)

    else:
      # set the texture for only one of the sides if one of the sides is specified
      let faceIndx = ["right", "left", "top", "bottom", "front", "back"].find(face)
      assert faceIndx >= 0
      setBlockFace(faceIndx, cordZIndex)

  return blockType
