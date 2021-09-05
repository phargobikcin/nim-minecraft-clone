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

type Int32P = int | int32
proc ivec3(x,y,z : Int32P): IVec3 =
  ivec3(x.int32, y.int32, z.int32)

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
  result.blocks = newSeqWith(CHUNK_WIDTH,
                             newSeqWith(CHUNK_HEIGHT,
                                        newSeq[int](CHUNK_LENGTH)))

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
  let chunkPos = ivec3(math.floordiv(pos.x, CHUNK_WIDTH),
                       math.floordiv(pos.y, CHUNK_HEIGHT),
                       math.floordiv(pos.z, CHUNK_LENGTH))

  if chunkPos notin self.chunks:
    return 0

  let
    chunk = self.chunks[chunkPos]
    localX = math.floormod(pos.x, CHUNK_WIDTH)
    localY = math.floormod(pos.y, CHUNK_HEIGHT)
    localZ = math.floormod(pos.z, CHUNK_LENGTH)

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
      pos = ivec3(self.position.x + localX.int32,
                  self.position.y + localY.int32,
                  self.position.z + localZ.int32)

    proc addFace(faceIndx: int) =
      var vertexPositions = blockType.vertexPositions[faceIndx]
      for ii in 0..3:
        vertexPositions[ii * 3] += pos.x.float32
        vertexPositions[ii * 3 + 1] += pos.y.float32
        vertexPositions[ii * 3 + 2] += pos.z.float32

      # append onto end of mesh
      self.meshVertexPositions &= vertexPositions

      var indices = @[0.uint32, 1, 2, 0, 2, 3]
      for i in 0..5:
        indices[i] += self.meshIndexCounter.uint32

      # there are 4 unique indices, hence we increment that
      self.meshIndexCounter += 4
      self.meshIndices &= indices

      # extend rest
      self.meshTexCords &= blockType.texCords[faceIndx]
      self.meshShadingValues &= blockType.shadingValues[faceIndx]

    if world.getBlockNumber(pos + ivec3( 1,  0,  0)) == 0: addFace(0)
    if world.getBlockNumber(pos + ivec3(-1,  0,  0)) == 0: addFace(1)
    if world.getBlockNumber(pos + ivec3( 0,  1,  0)) == 0: addFace(2)
    if world.getBlockNumber(pos + ivec3( 0, -1,  0)) == 0: addFace(3)
    if world.getBlockNumber(pos + ivec3( 0,  0,  1)) == 0: addFace(4)
    if world.getBlockNumber(pos + ivec3( 0,  0, -1)) == 0: addFace(5)

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


  # create grass chunk
  for x in -2..2:
    for z in -2..2:
      let c = newChunk(ivec3(x, -1, z))
      for x, y, z in localXYZ():
        # fill with grass
        if y == CHUNK_HEIGHT - 1:
          c.blocks[x][y][z] = 2 #self.blockManager.getByName("grass")
        else:
          c.blocks[x][y][z] = 4 #self.blockManager.getByName("grass")

      self.chunks[c.chunkPosition] = c

  # create a pillar chunk
  for y in 0..5:
    let c = newChunk(ivec3(0, y, 0))

    for x, y, z in localXYZ():
      # fill with cobbestone!
      c.blocks[x][y][z] = 1

    self.chunks[c.chunkPosition] = c

  # create a chunk with some air
  for y in 0..5:
    let c = newChunk(ivec3(1, y, 0))

    for x, y, z in localXYZ():
      # fill with cobbestone!
      c.blocks[x][y][z] = 0

    self.chunks[c.chunkPosition] = c


  for c in self.chunks.values():
    c.updateMesh(self.blockManager, self)
    c.updateVAO()



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
