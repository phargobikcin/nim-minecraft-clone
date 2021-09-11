import tables
import thin/[simpleutils, logsetup]

import models, block_type, texture_manager

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
                    newBlockType(textMan, "cobblestone", models.cube,
                                 {"all": "cobblestone"}.toTable),
                    newBlockType(textMan, "grass", models.cube,
                                 {"top": "grass", "bottom": "dirt", "sides": "grass_side"}.toTable),
                    newBlockType(textMan, "grass_block", models.cube,
                                 {"all": "grass"}.toTable),
                    newBlockType(textMan, "dirt", models.cube,
                                 {"all": "dirt"}.toTable),
                    newBlockType(textMan, "stone", models.cube,
                                 {"all": "stone"}.toTable),
                    newBlockType(textMan, "sand", models.cube,
                                 {"all": "sand"}.toTable),
                    newBlockType(textMan, "planks", models.cube,
                                 {"all": "planks"}.toTable),
                    newBlockType(textMan, "log", models.cube,
                                 {"top": "log_top", "bottom": "log_top", "sides": "log_side"}.toTable),
                    newBlockType(textMan, "daisy", models.plant,
                                 {"all": "daisy"}.toTable),
                    newBlockType(textMan, "rose", models.plant,
                                 {"all": "rose"}.toTable),
                    newBlockType(textMan, "cactus", models.cactus,
                                 {"top": "cactus_top", "bottom": "cactus_bottom", "sides": "cactus_side"}.toTable),
                    newBlockType(textMan, "dead_bush", models.plant,
                                 {"all": "dead_bush"}.toTable)]


  for b in result.blocks:
    if b != nil:
      l_info(f"added block {b.name} with index {b.index}")


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


