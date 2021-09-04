import math
import random
import tables
import hashes
import thin/[gamemaths, simpleutils]
import block_manager, chunk

type
  World* = ref object
    blockManager: BlockManager
    chunks: Table[IVec3, Chunk]

proc newWorld*(man: BlockManager): World =
  result = World(block_manager: man)

proc hash(v: IVec3): Hash =
  ## Computes a Hash from `x`.
  var h: Hash = 0
  # Iterate over parts of `x`.
  for xAtom in [v.x, v.y, v.z]:
    # Mix the atom with the partial hash.
    h = h !& xAtom
  # Finish the hash.
  result = !$h

proc randomWorld*(self: World) =
  let c = newChunk(ivec3(0, 0, 0))
  # XXX hash it
  #self.chunks[c.chunkPosition] = c

  for x in  0..<CHUNK_WIDTH:
    for y in  0..<CHUNK_HEIGHT:
      for z in  0..<CHUNK_LENGTH:
        # fill with cobbestone!
        c.blocks[x][y][z] = 1

  c.updateMesh(self.blockManager)
  self.chunks[c.chunkPosition] = c

proc draw*(self: World) =
  for c in self.chunks.values():
    c.draw()

  #for x in range(8):
  # for z in range(8):
  #     chunk_position = ivec(x - 4, -1, z - 4)
  #     current_chunk = Chunk(result, chunk_position)

  # for x in range(8):
  #   for z in range(8):
  #     chunk_position = ivec(x - 4, -1, z - 4)
  #     current_chunk = Chunk(result, chunk_position)

  #     for i in 0..<CHUNK_WIDTH:
  #       for j in 0..<CHUNK_HEIGHT:
  #         for k in 0..<CHUNK_LENGTH:
  #           if j > 13:
  #             current_chunk.blocks[i][j][k] = random.choice([0, 3])
  #           else:
  #             current_chunk.blocks[i][j][k] = random.choice([0, 0, 1])

  #     self.chunks[chunk_position] = current_chunk

  # # update each chunk's mesh
  # for chunk in self.chunks.values():
  #   chunk.update_mesh()
  # # create chunks with very crude terrain generation
