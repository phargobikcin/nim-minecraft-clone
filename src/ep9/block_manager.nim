import tables
import thin/simpleutils
import block_type, texture_manager

type
  BlockManager* = ref object
    textureManager: TextureManager
    blocks: seq[BlockType]
    blockByName: Table[string, BlockType]

proc newBlockManager*(): BlockManager =
  result = BlockManager()

  # create our texture manager (256 textures that are 16 x 16 pixels each)
  let textMan = newTextureManager(16, 16, 256)
  result.textureManager = textMan

  # create each one of our blocks with the texture manager and a list of textures per face
  result.blocks = @[nil, # air (XXX really ?)
                    newBlockType(textMan, "cobblestone", {"all": "cobblestone"}.toTable),
                    newBlockType(textMan, "grass", {"top": "grass",
                                                     "bottom": "dirt",
                                                     "sides": "grass_side"}.toTable),
                    newBlockType(textMan, "grass_block", {"all": "grass"}.toTable),
                    newBlockType(textMan, "dirt", {"all": "dirt"}.toTable),
                    newBlockType(textMan, "stone", {"all": "sand"}.toTable),
                    newBlockType(textMan, "planks", {"all": "planks"}.toTable),
                    newBlockType(textMan, "log", {"top": "log_top",
                                                   "bottom": "log_top",
                                                   "sides": "log_side"}.toTable)]

  # generate mipmaps for our texture manager's texture
  result.textureManager.generateMipmaps()

  # store in table for easy of use later.. XXX maybe?
  for b in result.blocks:
    if b != nil:
      result.blockByName[b.name] = b

  result.blockByName["air"] = nil


  # leave textures bound
  result.textureManager.doBind()

template get*(self: BlockManager, i: int): BlockType =
  self.blocks[i]

proc getByName*(self: BlockManager, s: string): BlockType =
  if s in self.blockByName:
    return self.blockByName[s]

  raise newException(KeyError, f"{s} not in BlockManager")


