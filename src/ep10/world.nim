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
# create functions to make things a bit easier


template get(self: Chunk, pos: IVec3): int =
  self.blocks[pos.x][pos.y][pos.z]


template set(self: Chunk, pos: IVec3, blockNumber: int) =
  self.blocks[pos.x][pos.y][pos.z] = blockNumber


template getChunkPosition(self: World, pos: IVec3): IVec3 =
  ivec3(math.floorDiv(pos.x, CHUNK_WIDTH),
        math.floorDiv(pos.y, CHUNK_HEIGHT),
        math.floorDiv(pos.z, CHUNK_LENGTH))

template getLocalPosition(self: World, pos: IVec3): IVec3 =
  ivec3(math.floorMod(pos.x, CHUNK_WIDTH),
        math.floorMod(pos.y, CHUNK_HEIGHT),
        math.floorMod(pos.z, CHUNK_LENGTH))

proc getBlockNumber(self: World, pos: IVec3): int =
  let chunkPos = self.getChunkPosition(pos)

  if chunkPos notin self.chunks:
    return 0

  let
    chunk = self.chunks[chunkPos]
    local = self.getLocalPosition(pos)

  return chunk.get(local)

proc isOpaqueBlock(self: World, pos: IVec3): bool =
  # get block type and check if it's opaque or not
  # air counts as a transparent block, so test for that too

  let blockNumber = self.getBlockNumber(pos)
  let blockType = self.blockManager.get(blockNumber)
  if blockType == nil:
    return false

  return not blockType.model.transparent


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
    let localPos = ivec3(localX, localY, localZ)
    let blockNumber = self.get(localPos)

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
      for ii in 0..5:
        indices[ii] += self.meshIndexCounter.uint32

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

    # XXX this is slow...
    if blockType.model.isCube:
      for ii, incr in [ivec3( 1,  0,  0), ivec3(-1,  0,  0), ivec3( 0,  1,  0),
                      ivec3( 0, -1,  0), ivec3( 0,  0,  1), ivec3( 0,  0, -1)]:

        if not world.isOpaqueBlock(pos + incr):
          addFace(ii)
    else:
      for ii in 0..<blockType.numberFaces:
        addFace(ii)

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


proc setBlock*(self: World, pos: IVec3, blockNum: int) =
  let s0 = getTicks()

  let chunkPosition = self.getChunkPosition(pos)

  let found = chunkPosition in self.chunks

  # no point in creating a whole new chunk if we're not gonna be adding anything
  if not found and blockNum == 0:
    return

  let chunk =
    if found:
      self.chunks[chunkPosition]
    else:
      # if no chunks exist at this position, create a new one
      let c = newChunk(chunkPosition)
      self.chunks[c.chunkPosition] = c
      c

  let local = self.getLocalPosition(pos)
  let oldBlockNum = chunk.get(local)

  # no point updating mesh if the block is the same
  if blockNum == oldBlockNum:
    return

  # can set now
  chunk.set(local, blockNum)

  chunk.updateMesh(self.blockManager, self)
  chunk.updateVAO()

  proc tryUpdateChunkAtPosition(relative: IVec3) =
    let newChunkPos = chunkPosition + relative

    if newChunkPos in self.chunks:
      let cc = self.chunks[newChunkPos]

      cc.updateMesh(self.blockManager, self)
      cc.updateVAO()

  if local.x == CHUNK_WIDTH - 1:
    tryUpdateChunkAtPosition(ivec3(1, 0, 0))

  elif local.x == 0:
    tryUpdateChunkAtPosition(ivec3(-1, 0, 0))

  if local.y == CHUNK_HEIGHT - 1:
    tryUpdateChunkAtPosition(ivec3(0, 1, 0))
  elif local.y == 0:
    tryUpdateChunkAtPosition(ivec3(0, -1, 0))

  if local.z == CHUNK_LENGTH - 1:
    tryUpdateChunkAtPosition(ivec3(0, 0, 1))

  elif local.z == 0:
    tryUpdateChunkAtPosition(ivec3(0, 0, -1))

  let s1 = getTicks()
  l_critical(f"time taken to update chunk {s1-s0}")

proc fixedWorld*(self: World) =

  # create grass chunk
  for x in -3..3:
    for z in -3..3:
      let c = newChunk(ivec3(x, -1, z))
      for i, j, k in localXYZ():

        c.blocks[i][j][k] =
          if j == CHUNK_HEIGHT - 1:
            if x == 0 and z == 0:
              self.blockManager.getByName("cobblestone").index
            else:
              random.sample([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9, 9, 10, 10, 12, 12, 11])
          elif j == CHUNK_HEIGHT - 2:
            self.blockManager.getByName("grass").index
          else:
            self.blockManager.getByName("dirt").index

      self.chunks[c.chunkPosition] = c

  # create a pillar chunk
  for y in 0..5:
    let c = newChunk(ivec3(0, y, 0))

    for x, y, z in localXYZ():
      # fill with cobbestone!
      c.blocks[x][y][z] = random.sample([1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
                                         5, 5, 5, 5,
                                         0, 0])


    self.chunks[c.chunkPosition] = c

  # update mesh etc
  for c in self.chunks.values():
    c.updateMesh(self.blockManager, self)
    c.updateVAO()


proc randomWorld*(self: World) =
  let s0 = getTicks()
  for x in -1..<1:
    for z in -1..<1:
      let chunkPosition = ivec3(x, -1, z)

      let c = newChunk(chunkPosition)
      for i, j, k in localXYZ():
        c.blocks[i][j][k] =


          if j == 15:
            let cdf = [20.0, 2.0, 1.0].cumsummed
            random.sample([0, 10, 11], cdf)
          elif j == 14:
            2 # grass
          elif j > 10:
            4 # dirt
          else:
            5 # stone

      self.chunks[c.chunkPosition] = c

  let s1 = getTicks()

  # update mesh etc
  for c in self.chunks.values():
    c.updateMesh(self.blockManager, self)
    c.updateVAO()

  let s2 = getTicks()
  let x = (s2 - s1) / len(self.chunks).float
  l_critical(f"time taken to create chunk {s2-s1} {s1-s0}")
  l_critical(f"time taken to create chunk {x} {len(self.chunks)} ")


  # timings per chunk before ep10 chunk changes

  # python: ~50 msecs

  # nim debug_slow: ~18 msecs
  # nim debug: ~6.6 msecs

  # nim release w/o lto: ~3.5 msecs
  # nim release: ~3.0 msecs
  # nim danger: ~2.7 msecs
