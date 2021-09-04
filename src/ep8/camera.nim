import math

import thin/[gamemaths, shading, simpleutils]
import thin/logsetup as logging

type
  Camera* = ref object
    width: int
    height: int

    program: ShaderProgram
    pMatrix: Mat4

    shaderMatrixLocation: int
    movementInput*: IVec3

    position: Vec3
    rotation*: Vec2

###############################################################################
# fwd
proc updatePMatrix*(self: Camera, width, height: int)

###############################################################################

proc newCamera*(p: ShaderProgram, w, h: int): Camera =
  result = Camera(program: p, width: w, height: h)

  result.shaderMatrixLocation = p.findUniform("matrix")

  # our starting x rotation needs to be tau / 4 since our 0 angle is on the positive x axis while
  # what we consider "forwards" is the negative z axis
  result.position.x = math.TAU / 4

  result.position = vec3(0, 0, -3)
  result.rotation = vec2(math.TAU / 4.0, 0)
  result.updatePMatrix(w, h)

###############################################################################

proc updatePMatrix*(self: Camera, width, height: int) =
  self.width = width
  self.height = height
  let aspectRatio = (width / height).float32
  self.pMatrix = gamemaths.perspective(90f, aspectRatio, 0.1, 500)
  l_verbose(f"updated pMatrix with {width} x {height}")


proc updatePosition*(self: Camera, deltaTime: float) =
  let speed = 3f
  let multiplier: float32 = speed * deltaTime.float32

  self.position.y += self.movementInput.y.float32 * multiplier

  # important to check this because atan2(0, 0) is undefined
  if self.movementInput.x == 0 and self.movementInput.z == 0:
    return

  # we need to subtract tau / 4 to move in the positive z direction instead of the positive x direction
  let angle = self.rotation.x + math.arctan2(self.movementInput.z.float32,
                                             self.movementInput.x.float32) - math.TAU / 4

  self.position.x += math.cos(angle) * multiplier
  self.position.z += math.sin(angle) * multiplier
  # echo self.position

proc updateMatrices*(self: Camera) =
  # create model view matrix
  let p = self.position

  # identity
  var vMatrix = mat4()

  # funky rotating, I don't pretend to understand
  proc rotate2D(x, y: float32) =
    # this rotates around y axis
    vMatrix = vMatrix * gamemaths.rotate(x, vec3(0, 1.0, 0))

    # this rotates around an axis based of x
    let axis = vec3(math.cos(x), 0, math.sin(x))
    # echo f"axis {axis}"
    vMatrix = vMatrix * gamemaths.rotate(-y, axis)

  # this needs to come first for a first person view and we need to play around with the x rotation
  # angle a bit since our 0 angle is on the positive x axis while the matrix library's 0 angle is
  # on the negative z axis (because of normalized device coordinates)
  rotate2D(-(self.rotation[0] - math.TAU / 4), self.rotation.y)

  # this needs to be negative, since in reality we are moving the world - not the camera
  vMatrix = vMatrix * gamemaths.translate(vec3(-p.x, -p.y, p.z))

  # no model transformations
  let mvpMatrix = self.pMatrix * vMatrix
  self.program.setUniform(self.shaderMatrixLocation, mvpMatrix)

