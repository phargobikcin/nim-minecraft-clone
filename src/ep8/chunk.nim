
import sequtils

import nimgl/opengl as gl

import thin/[gamemaths, loaded, simpleutils]
import thin/logsetup as logging
import block_type, block_manager

const
  CHUNK_WIDTH* = 16
  CHUNK_HEIGHT* = 16
  CHUNK_LENGTH* = 16


type
  Chunk* = ref object
    chunkPosition*: IVec3
    position: IVec3

    blocks*: seq[seq[seq[int]]]

    hasMesh: bool

    meshVertexPositions: seq[float32]
    meshTexCords: seq[float32]
    meshShadingValues: seq[float32]

    meshIndexCounter: int
    meshIndices: seq[uint32]

    vao: VertexArrayObject

proc newChunk*(pos: IVec3): Chunk =
  result = Chunk(chunkPosition: pos)
  result.position = ivec3(pos.x * CHUNK_WIDTH,
                          pos.y * CHUNK_HEIGHT,
                          pos.z * CHUNK_LENGTH)

  # 3D seq
  result.blocks = newSeqWith(CHUNK_WIDTH, newSeqWith(CHUNK_HEIGHT, newSeq[int](CHUNK_LENGTH)))

proc updateMesh*(self: Chunk, blockManager: BlockManager) =
  l_verbose(f"chunk.updateMesh() at pos {self.position}")

  # clear everything
  self.meshVertexPositions = @[]
  self.meshTexCords = @[]
  self.meshShadingValues = @[]
  self.meshIndices = @[]
  self.meshIndexCounter = 0

  for local_x in  0..<CHUNK_WIDTH:
    for local_y in  0..<CHUNK_HEIGHT:
      for local_z in  0..<CHUNK_LENGTH:
        let blockNumber = self.blocks[local_x][local_y][local_z]
        if blockNumber == 0:
          continue

        let blockType = blockManager.blocks[blockNumber]

        let x = self.position.x + local_x
        let y = self.position.y + local_y
        let z = self.position.z + local_z

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
  if self.meshIndexCounter == 0:
    return

  # for now just create a new one
  if self.vao != nil:
    self.vao.unbind()
  self.vao = newVertexArrayObject()

  self.vao.addBuffer(newVertexBuffer(self.meshVertexPositions), EGL_FLOAT, 3)
  self.vao.addBuffer(newVertexBuffer(self.meshTexCords), EGL_FLOAT, 3)
  self.vao.addBuffer(newVertexBuffer(self.meshShadingValues), EGL_FLOAT, 1)
  self.vao.attach(newIndexBuffer(self.meshIndices))
  self.vao.unbind()

  self.hasMesh = true

proc draw*(self: Chunk) =
  if self.hasMesh:
    assert self.meshIndexCounter > 0

  self.vao.doBind()
  self.vao.draw()
  self.vao.unbind()
