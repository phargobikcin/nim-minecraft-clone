import tables
import models
import texture_manager

type
  BlockType* = ref object
    index*: int
    name*: string
    model*: Model
    numberFaces*: int

    # XXX should these be public?
    vertexPositions*: seq[seq[float32]]
    texCords*: seq[seq[float32]]
    shadingValues*: seq[seq[float32]]

var localCount = 1

proc newBlockType*(manager: TextureManager,
                   name: string,
                   model = models.cube,
                   blockFaceTextures = {"all": "cobblestone"}.toTable): BlockType =

  # set our block type's vertex positions, texture coordinates, and indices to the default values
  # in our numbers.nim file
  var blockType = BlockType(index: localCount,
                            name: name,
                            model: model,
                            vertexPositions: model.vertexPositions,
                            texCords: model.texCords,
                            shadingValues: model.shadingValues,
                            numberFaces: len(model.texCords))

  # XXX increment local count... bit hacky since block manager should probably set it
  inc(localCount)


  # note, these are copies.  This is handy for texCords, since we need to modify our texture
  # coordinates in a different way for each block type (to have different textures per block)

  proc setBlockFace(faceIndx: int, texturePos: int) =
    # XXX bit hacky, feels like we should be doing things differently for cubes...

    # make sure we don't add inexistent faces
    if faceIndx < blockType.numberFaces:
      # set a specific face of the block to a certain texture
      for vertex in 0..3:
        blockType.texCords[faceIndx][vertex * 3 + 2] = texturePos.float32

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
