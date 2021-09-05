from model/cube as cubeDesc import nil
from model/cactus as cactusDesc import nil
from model/plant as plantDesc import nil

type
  Model* = ref object
    transparent*: bool
    isCube*: bool
    vertexPositions*: seq[seq[float32]]
    texCords*: seq[seq[float32]]
    shadingValues*: seq[seq[float32]]

let cube* = Model(transparent: cubeDesc.transparent,
                  isCube: cubeDesc.isCube,
                  vertexPositions: cubeDesc.vertexPositions,
                  texCords: cubeDesc.texCords,
                  shadingValues: cubeDesc.shadingValues)

let plant* = Model(transparent: plantDesc.transparent,
                   isCube: plantDesc.isCube,
                   vertexPositions: plantDesc.vertexPositions,
                   texCords: plantDesc.texCords,
                   shadingValues: plantDesc.shadingValues)

let cactus* = Model(transparent: cactusDesc.transparent,
                    isCube: cactusDesc.isCube,
                    vertexPositions: cactusDesc.vertexPositions,
                    texCords: cactusDesc.texCords,
                    shadingValues: cactusDesc.shadingValues)
