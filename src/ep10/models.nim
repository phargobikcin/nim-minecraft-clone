from model/cube as cubeDesc import nil
from model/plant as plantDesc import nil
from model/cactus as cactusDesc import nil

# convert model "module" into Model object
type
  Model* = ref object
    transparent*: bool
    isCube*: bool
    vertexPositions*: seq[seq[float32]]
    texCords*: seq[seq[float32]]
    shadingValues*: seq[seq[float32]]

template toModel(name: untyped): untyped =
  Model(transparent: `name Desc`.transparent,
        isCube: `name Desc`.isCube,
        vertexPositions: `name Desc`.vertexPositions,
        texCords: `name Desc`.texCords,
        shadingValues: `name Desc`.shadingValues)

let cube* = toModel(cube)
let plant* = toModel(plant)
let cactus* = toModel(cactus)
