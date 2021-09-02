import math

import ./vector, ./matrix

proc scale*[T](v: GVec3[T]): GMat4[T] =
  ## Create scale matrix.
  gmat4[T](
    v.x, 0, 0, 0,
    0, v.y, 0, 0,
    0, 0, v.z, 0,
    0, 0, 0, 1
  )

proc translate*[T](v: GVec3[T]): GMat4[T] =
  ## Create translation matrix.
  gmat4[T](
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    v.x, v.y, v.z, 1
  )

proc rotate*[T](angle: T, axis: GVec3[T]): GMat4[T] =
  # rotate around an arbirtray axis
  let
    normV = normalise(axis)

    x = -normV.x
    y = -normV.y
    z = -normV.z

    sinAngle = sin(angle)
    cosAngle = cos(angle)
    oneMinusCos = 1 - cosAngle

    xx = x * x
    yy = y * y
    zz = z * z

    xy = x * y
    yz = y * z
    zx = z * x

    xs = x * sinAngle
    ys = y * sinAngle
    zs = z * sinAngle

  result[0, 0] = (oneMinusCos * xx) + cosAngle
  result[0, 1] = (oneMinusCos * xy) - zs
  result[0, 2] = (oneMinusCos * zx) + ys

  result[1, 0] = (oneMinusCos * xy) + zs
  result[1, 1] = (oneMinusCos * yy) + cosAngle
  result[1, 2] = (oneMinusCos * yz) - xs

  result[2, 0] = (oneMinusCos * zx) - ys
  result[2, 1] = (oneMinusCos * yz) + xs
  result[2, 2] = (oneMinusCos * zz) + cosAngle

  result[3, 3] = 1.0

# XXX
# proc rotate2D[T](ang, y: T): GMat4[T] =
#   let tmp0 = rotate[float32](ang, vec3(0, 1.0, 0))
#   let tmp1 = rotate[float32](-y, vec3(math.cos(ang), 0, math.sin(ang)))
#   return tmp0 * tmp1

proc hrp*[T](m: GMat4[T]): GVec3[T] =
  ## Return heading, rotation and pivot of a matrix.
  var heading, pitch, roll: float32
  if m[1] > 0.998: # singularity at north pole
    heading = arctan2(m[2], m[10])
    pitch = PI / 2
    roll = 0
  elif m[1] < -0.998: # singularity at south pole
    heading = arctan2(m[2], m[10])
    pitch = -PI / 2
    roll = 0
  else:
    heading = arctan2(-m[8], m[0])
    pitch = arctan2(-m[6], m[5])
    roll = arcsin(m[4])
  gvec3[T](heading, pitch, roll)

proc frustum*[T](left, right, bottom, top, near, far: T): GMat4[T] =
  ## Create a frustum matrix.
  let
    rl = (right - left)
    tb = (top - bottom)
    fn = (far - near)

  result[0, 0] = (near * 2) / rl
  result[0, 1] = 0
  result[0, 2] = 0
  result[0, 3] = 0

  result[1, 0] = 0
  result[1, 1] = (near * 2) / tb
  result[1, 2] = 0
  result[1, 3] = 0

  result[2, 0] = (right + left) / rl
  result[2, 1] = (top + bottom) / tb
  result[2, 2] = -(far + near) / fn
  result[2, 3] = -1

  result[3, 0] = 0
  result[3, 1] = 0
  result[3, 2] = -(far * near * 2) / fn
  result[3, 3] = 0

proc perspective*[T](fovy, aspect, near, far: T): GMat4[T] =
  ## Create a perspective matrix.
  let
    top: T = near * tan(fovy * PI.float32 / 360.0)
    right: T = top * aspect
  frustum(-right, right, -top, top, near, far)

proc ortho*[T](left, right, bottom, top, near, far: T): GMat4[T] =
  ## Create an orthographic matrix.
  let
    rl: T = (right - left)
    tb: T = (top - bottom)
    fn: T = (far - near)

  result[0, 0] = T(2 / rl)
  result[0, 1] = 0
  result[0, 2] = 0
  result[0, 3] = 0

  result[1, 0] = 0
  result[1, 1] = T(2 / tb)
  result[1, 2] = 0
  result[1, 3] = 0

  result[2, 0] = 0
  result[2, 1] = 0
  result[2, 2] = T(-2 / fn)
  result[2, 3] = 0

  result[3, 0] = T(-(left + right) / rl)
  result[3, 1] = T(-(top + bottom) / tb)
  result[3, 2] = T(-(far + near) / fn)
  result[3, 3] = 1


proc lookAt*[T](eye, center, up: GVec3[T]): GMat4[T] =
  ## Create a matrix that would convert eye pos to looking at center.
  let
    eyex = eye[0]
    eyey = eye[1]
    eyez = eye[2]
    upx = up[0]
    upy = up[1]
    upz = up[2]
    centerx = center[0]
    centery = center[1]
    centerz = center[2]

  if eyex == centerx and eyey == centery and eyez == centerz:
    return mat4[T]()

  var
    # vec3.direction(eye, center, z)
    z0 = eyex - center[0]
    z1 = eyey - center[1]
    z2 = eyez - center[2]

  # normalize (no check needed for 0 because of early return)
  var len = 1 / sqrt(z0 * z0 + z1 * z1 + z2 * z2)
  z0 *= len
  z1 *= len
  z2 *= len

  var
    # vec3.normalize(vec3.cross(up, z, x))
    x0 = upy * z2 - upz * z1
    x1 = upz * z0 - upx * z2
    x2 = upx * z1 - upy * z0
  len = sqrt(x0 * x0 + x1 * x1 + x2 * x2)
  if len == 0:
    x0 = 0
    x1 = 0
    x2 = 0
  else:
    len = 1 / len
    x0 *= len
    x1 *= len
    x2 *= len

  var
    # vec3.normalize(vec3.cross(z, x, y))
    y0 = z1 * x2 - z2 * x1
    y1 = z2 * x0 - z0 * x2
    y2 = z0 * x1 - z1 * x0

  len = sqrt(y0 * y0 + y1 * y1 + y2 * y2)
  if len == 0:
    y0 = 0
    y1 = 0
    y2 = 0
  else:
    len = 1/len
    y0 *= len
    y1 *= len
    y2 *= len

  result[0, 0] = x0
  result[0, 1] = y0
  result[0, 2] = z0
  result[0, 3] = 0

  result[1, 0] = x1
  result[1, 1] = y1
  result[1, 2] = z1
  result[1, 3] = 0

  result[2, 0] = x2
  result[2, 1] = y2
  result[2, 2] = z2
  result[2, 3] = 0

  result[3, 0] = -(x0 * eyex + x1 * eyey + x2 * eyez)
  result[3, 1] = -(y0 * eyex + y1 * eyey + y2 * eyez)
  result[3, 2] = -(z0 * eyex + z1 * eyey + z2 * eyez)
  result[3, 3] = 1

proc lookAt*[T](eye, center: GVec3[T]): GMat4[T] =
  ## Look center from eye with default UP vector.
  lookAt(eye, center, gvec3(T(0), 0, 1))

proc angle*[T](a: GVec2[T]): T =
  ## Angle of a Vec2.
  arctan2(a.y, a.x)
