import math
import tables
import hashes
import random
import sequtils

import nimgl/opengl as gl

import thin/[gamemaths, loaded, simpleutils, logsetup]

import block_manager

###############################################################################
# XXX move these

proc hash(v: IVec3): Hash =
  ## Computes a Hash from `x`.
  var h: Hash = 0
  # Iterate over parts of `x`.
  for xAtom in [v.x, v.y, v.z]:
    # Mix the atom with the partial hash.
    h = h !& xAtom
  # Finish the hash.
  result = !$h

template ivec3(x, y, z: int | int32): IVec3 =
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

  let chunkPos = ivec3(math.floorDiv(pos.x, CHUNK_WIDTH),
                       math.floorDiv(pos.y, CHUNK_HEIGHT),
                       math.floorDiv(pos.z, CHUNK_LENGTH))

  if chunkPos notin self.chunks:
    return 0

  let
    chunk = self.chunks[chunkPos]
    localX = math.floorMod(pos.x, CHUNK_WIDTH)
    localY = math.floorMod(pos.y, CHUNK_HEIGHT)
    localZ = math.floorMod(pos.z, CHUNK_LENGTH)

  result = chunk.get(localX, localY, localZ)

  # XXX hack alert!
  # XXX this'll be fixed in a future episode
  # get block type and check if it's transparent or not
  # if it is, return 0 - else leave result unmodified
  let blockType = self.blockManager.get(result)
  if blockType == nil or blockType.model.transparent:
    result = 0


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
      pos = ivec3(self.position.x + localX,
                  self.position.y + localY,
                  self.position.z + localZ)

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

    # if block is cube, we want it to check neighbouring blocks so that we don't uselessly render
    # faces.
    # if block isn't a cube, we just want to render all faces, regardless of neighbouring
    # blocks since the vast majority of blocks are probably anyway going to be cubes, this won't
    # impact performance all that much; the amount of useless faces drawn is going to be minimal

    if blockType.model.isCube:
      if world.getBlockNumber(pos + ivec3( 1,  0,  0)) == 0: addFace(0)
      if world.getBlockNumber(pos + ivec3(-1,  0,  0)) == 0: addFace(1)
      if world.getBlockNumber(pos + ivec3( 0,  1,  0)) == 0: addFace(2)
      if world.getBlockNumber(pos + ivec3( 0, -1,  0)) == 0: addFace(3)
      if world.getBlockNumber(pos + ivec3( 0,  0,  1)) == 0: addFace(4)
      if world.getBlockNumber(pos + ivec3( 0,  0, -1)) == 0: addFace(5)
    else:
      for i in 0..<blockType.numberFaces:
        addFace(i)

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

proc fixedWorld*(self: World) =

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

  # update mesh etc
  for c in self.chunks.values():
    c.updateMesh(self.blockManager, self)
    c.updateVAO()


proc randomWorld*(self: World) =
  for x in -1..1:
    for z in -1..1:
      let chunkPosition = ivec3(x, -1, z)

      let c = newChunk(chunkPosition)
      for i, j, k in localXYZ():
        c.blocks[i][j][k] =
          if j == 15:
            random.sample([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9, 9, 10, 10, 12, 12, 11])
          elif j > 12:
            random.sample([0, 2, 6])
          else:
            random.sample([0, 0, 1, 4, 5])

      self.chunks[c.chunkPosition] = c

  # update mesh etc
  for c in self.chunks.values():
    c.updateMesh(self.blockManager, self)
    c.updateVAO()
