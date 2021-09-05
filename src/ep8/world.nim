import math
import tables
import hashes
import sequtils

import nimgl/opengl as gl

import thin/[gamemaths, loaded, simpleutils, logsetup]

import block_manager

###############################################################################

proc hash(v: IVec3): Hash =
  ## Computes a Hash from `x`.
  var h: Hash = 0
  # Iterate over parts of `x`.
  for xAtom in [v.x, v.y, v.z]:
    # Mix the atom with the partial hash.
    h = h !& xAtom
  # Finish the hash.
  result = !$h

###############################################################################

const
  CHUNK_WIDTH = 16
  CHUNK_HEIGHT = 16
  CHUNK_LENGTH = 16

type
  World* = ref object
    blockManager: BlockManager
    chunks: Table[IVec3, Chunk]

  Chunk* = ref object
    chunkPosition: IVec3
    position: IVec3

    blocks: seq[seq[seq[int]]]

    hasMesh: bool
    vao: VertexArrayObject

    # XXX below should be own object?
    meshVertexPositions: seq[float32]
    meshTexCords: seq[float32]
    meshShadingValues: seq[float32]

    meshIndexCounter: int
    meshIndices: seq[uint32]



###############################################################################

proc newWorld*(man: BlockManager): World =
  result = World(block_manager: man)

proc newChunk*(pos: IVec3): Chunk =
  result = Chunk(chunkPosition: pos)
  result.position = ivec3(pos.x * CHUNK_WIDTH,
                          pos.y * CHUNK_HEIGHT,
                          pos.z * CHUNK_LENGTH)

  # 3D seq
  result.blocks = newSeqWith(CHUNK_WIDTH, newSeqWith(CHUNK_HEIGHT, newSeq[int](CHUNK_LENGTH)))

###############################################################################

proc draw*(self: World) =
  for c in self.chunks.values():

    if not c.hasMesh:
      continue

    c.vao.doBind()
    c.vao.draw()
    c.vao.unbind()

###############################################################################

template get(self: Chunk, x, y, z: int): int =
  self.blocks[x][y][z]

proc getBlockNumber(self: World, pos: IVec3): int =
  let
    x = pos.x / CHUNK_WIDTH
    y = pos.y / CHUNK_HEIGHT
    z = pos.z / CHUNK_LENGTH
    x2 = pos.x div CHUNK_WIDTH
    y2 = pos.y div CHUNK_HEIGHT
    z2 = pos.z div CHUNK_LENGTH

  let chunkPos = ivec3(math.floor(x).int32,
                       math.floor(y).int32,
                       math.floor(z).int32)
  let chunkPos2 = ivec3(x2, y2, z2)
  echo f"chunkPos= {chunkPos}, chunkPos2= {chunkPos2}"

  if chunkPos notin self.chunks:
    return 0

  let chunk = self.chunks[chunkPos]

  let
    localX = pos.x mod CHUNK_WIDTH
    localY = pos.y mod CHUNK_HEIGHT
    localZ = pos.z mod CHUNK_LENGTH

  return chunk.get(localX, localY, localZ)


iterator localXYZ(): tuple[x, y, z: int] {.inline.} =
  for local_x in 0..<CHUNK_WIDTH:
    for local_y in 0..<CHUNK_HEIGHT:
      for local_z in 0..<CHUNK_LENGTH:
        yield (local_x, local_y, local_z)


proc updateMesh(self: Chunk, blockManager: BlockManager, world: World) =
  l_verbose(f"chunk.updateMesh() at pos {self.position}")

  # clear everything
  self.meshVertexPositions = @[]
  self.meshTexCords = @[]
  self.meshShadingValues = @[]
  self.meshIndices = @[]
  self.meshIndexCounter = 0

  for localX, localY, localZ in localXYZ():
    let blockNumber = self.get(localX, localY, localZ)

    # sky block?
    if blockNumber == 0:
      continue

    let
      blockType = blockManager.get(blockNumber)
      x = self.position.x + localX
      y = self.position.y + localY
      z = self.position.z + localZ

    var vertexPositions = blockType.vertexPositions
    for ii in 0..<24:
      vertexPositions[ii * 3] += x.float32
      vertexPositions[ii * 3 + 1] += y.float32
      vertexPositions[ii * 3 + 2] += z.float32

    # append onto end of mesh
    self.meshVertexPositions &= vertexPositions

    var indices = blockType.indices
    for i in 0..<36:
      indices[i] += self.meshIndexCounter.uint32

    # extend indices
    self.meshIndices &= indices

    # there are 24 unique indices, hence we increment that
    self.meshIndexCounter += 24

    # extend rest
    self.meshTexCords &= blockType.texCords
    self.meshShadingValues &= blockType.shadingValues

  # ok done looping... check we added anything
  self.hasMesh = self.meshIndexCounter > 0

proc updateVAO(self: Chunk) =
  # for now just create a new one
  if self.vao != nil:
    self.vao.unbind()
    self.vao = nil
  self.vao = newVertexArrayObject()

  if self.hasMesh:
    self.vao.addBuffer(newVertexBuffer(self.meshVertexPositions), EGL_FLOAT, 3)
    self.vao.addBuffer(newVertexBuffer(self.meshTexCords), EGL_FLOAT, 3)
    self.vao.addBuffer(newVertexBuffer(self.meshShadingValues), EGL_FLOAT, 1)
    self.vao.attach(newIndexBuffer(self.meshIndices))
    self.vao.unbind()

proc randomWorld*(self: World) =
  let c = newChunk(ivec3(0, 0, 0))

  for x, y, z in localXYZ():
    # fill with cobbestone!
    c.blocks[x][y][z] = 1

  c.updateMesh(self.blockManager, self)
  c.updateVAO()
  self.chunks[c.chunkPosition] = c



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
