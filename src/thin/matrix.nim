import vector
from strutils import toLowerAscii

type
  GMat2*[T] = object
    arr: array[4, T]

  GMat3*[T] = object
    arr: array[9, T]

  GMat4*[T] = object
    arr: array[16, T]

  # GMat234[T] = GMat2[T] | GMat3[T] | GMat4[T]

###############################################################################
# generic constructors

proc gmat2*[T](m00, m01,
               m10, m11: T): GMat2[T] =

  GMat2[T](arr: [m00, m01,
                 m10, m11])

proc gmat3*[T](m00, m01, m02,
               m10, m11, m12,
               m20, m21, m22: T): GMat3[T] =

  GMat3[T](arr: [m00, m01, m02,
                 m10, m11, m12,
                 m20, m21, m22])

proc gmat4*[T](m00, m01, m02, m03,
               m10, m11, m12, m13,
               m20, m21, m22, m23,
               m30, m31, m32, m33: T): GMat4[T] =

  GMat4[T](arr: [m00, m01, m02, m03,
                 m10, m11, m12, m13,
                 m20, m21, m22, m23,
                 m30, m31, m32, m33])

###############################################################################
# accessors

template `[]`*[T](a: GMat2[T], i, j: int): T = a.arr[i * 2 + j]
template `[]`*[T](a: GMat3[T], i, j: int): T = a.arr[i * 3 + j]
template `[]`*[T](a: GMat4[T], i, j: int): T = a.arr[i * 4 + j]

template `[]=`*[T](a: var GMat2[T], i, j: int, v: T) = a.arr[i * 2 + j] = v
template `[]=`*[T](a: var GMat3[T], i, j: int, v: T) = a.arr[i * 3 + j] = v
template `[]=`*[T](a: var GMat4[T], i, j: int, v: T) = a.arr[i * 4 + j] = v

template `[]`*[T](a: GMat2[T], i: int): GVec2[T] =
  gvec2[T](a[i, 0],
           a[i, 1])

template `[]`*[T](a: GMat3[T], i: int): GVec3[T] =
  gvec3[T](a[i, 0],
           a[i, 1],
           a[i, 2])

template `[]`*[T](a: GMat4[T], i: int): GVec4[T] =
  gvec4[T](a[i, 0],
           a[i, 1],
           a[i, 2],
           a[i, 3])

###############################################################################
# concrete defintions

type
  Mat2* = GMat2[float32]
  Mat3* = GMat3[float32]
  Mat4* = GMat4[float32]

  DMat2* = GMat2[float64]
  DMat3* = GMat3[float64]
  DMat4* = GMat4[float64]


###############################################################################
# constructors and repr

proc matToString[T](a: T, n: int): string =
  result.add ($type(a)).toLowerAscii() & "(\n"
  for x in 0 ..< n:
    result.add "  "
    for y in 0 ..< n:
      result.add $a[x, y] & ", "

    result.setLen(result.len - 1)
    result.add "\n"

  result.setLen(result.len - 2)
  result.add "\n)"

template genMatConstructor(lower, upper, T: untyped) =
  # default is identity matrix:
  proc `lower 2`*(): `upper 2` =
    gmat2[T](1.T, 0.T,
             0.T, 1.T)

  proc `lower 3`*(): `upper 3` =
    gmat3[T](1.T, 0.T, 0.T,
             0.T, 1.T, 0.T,
             0.T, 0.T, 1.T)

  proc `lower 4`*(): `upper 4` =
    gmat4[T](1.T, 0.T, 0.T, 0.T,
             0.T, 1.T, 0.T, 0.T,
             0.T, 0.T, 1.T, 0.T,
             0.T, 0.T, 0.T, 1.T)

  # by values:
  proc `lower 2`*(m00, m01,
                  m10, m11: T): `upper 2` =
    result[0, 0] = m00; result[0, 1] = m01
    result[1, 0] = m10; result[1, 1] = m11

  proc `lower 3`*(m00, m01, m02,
                  m10, m11, m12,
                  m20, m21, m22: T): `upper 3` =
    result[0, 0] = m00; result[0, 1] = m01; result[0, 2] = m02
    result[1, 0] = m10; result[1, 1] = m11; result[1, 2] = m12
    result[2, 0] = m20; result[2, 1] = m21; result[2, 2] = m22

  proc `lower 4`*(m00, m01, m02, m03,
                  m10, m11, m12, m13,
                  m20, m21, m22, m23,
                  m30, m31, m32, m33: T): `upper 4` =
    result[0, 0] = m00; result[0, 1] = m01
    result[0, 2] = m02; result[0, 3] = m03

    result[1, 0] = m10; result[1, 1] = m11
    result[1, 2] = m12; result[1, 3] = m13

    result[2, 0] = m20; result[2, 1] = m21
    result[2, 2] = m22; result[2, 3] = m23

    result[3, 0] = m30; result[3, 1] = m31
    result[3, 2] = m32; result[3, 3] = m33

  # by vectors:
  proc `lower 2`*(a, b: GVec2[T]): `upper 2` =
    gmat2[T](a.x, a.y,
             b.x, b.y)

  proc `lower 3`*(a, b, c: GVec3[T]): `upper 3` =
    gmat3[T](a.x, a.y, a.z,
             b.x, b.y, b.z,
             c.x, c.y, c.z,)

  proc `lower 4`*(a, b, c, d: GVec4[T]): `upper 4` =
    gmat4[T](a.x, a.y, a.z, a.w,
             b.x, b.y, b.z, b.w,
             c.x, c.y, c.z, c.w,
             d.x, d.y, d.z, d.w)

  proc `$`*(a: `upper 2`): string = matToString(a, 2)
  proc `$`*(a: `upper 3`): string = matToString(a, 3)
  proc `$`*(a: `upper 4`): string = matToString(a, 4)

genMatConstructor(mat, Mat, float32)
genMatConstructor(dmat, DMat, float64)

###############################################################################
# matrix / matrix multiplication

proc `*`*[T](a, b: GMat3[T]): GMat3[T] =
  result[0, 0] = b[0, 0] * a[0, 0] + b[0, 1] * a[1, 0] + b[0, 2] * a[2, 0]
  result[0, 1] = b[0, 0] * a[0, 1] + b[0, 1] * a[1, 1] + b[0, 2] * a[2, 1]
  result[0, 2] = b[0, 0] * a[0, 2] + b[0, 1] * a[1, 2] + b[0, 2] * a[2, 2]

  result[1, 0] = b[1, 0] * a[0, 0] + b[1, 1] * a[1, 0] + b[1, 2] * a[2, 0]
  result[1, 1] = b[1, 0] * a[0, 1] + b[1, 1] * a[1, 1] + b[1, 2] * a[2, 1]
  result[1, 2] = b[1, 0] * a[0, 2] + b[1, 1] * a[1, 2] + b[1, 2] * a[2, 2]

  result[2, 0] = b[2, 0] * a[0, 0] + b[2, 1] * a[1, 0] + b[2, 2] * a[2, 0]
  result[2, 1] = b[2, 0] * a[0, 1] + b[2, 1] * a[1, 1] + b[2, 2] * a[2, 1]
  result[2, 2] = b[2, 0] * a[0, 2] + b[2, 1] * a[1, 2] + b[2, 2] * a[2, 2]

proc `*`*[T](a, b: GMat4[T]): GMat4[T] =
  let
    a00 = a[0, 0]
    a01 = a[0, 1]
    a02 = a[0, 2]
    a03 = a[0, 3]
    a10 = a[1, 0]
    a11 = a[1, 1]
    a12 = a[1, 2]
    a13 = a[1, 3]
    a20 = a[2, 0]
    a21 = a[2, 1]
    a22 = a[2, 2]
    a23 = a[2, 3]
    a30 = a[3, 0]
    a31 = a[3, 1]
    a32 = a[3, 2]
    a33 = a[3, 3]

  let
    b00 = b[0, 0]
    b01 = b[0, 1]
    b02 = b[0, 2]
    b03 = b[0, 3]
    b10 = b[1, 0]
    b11 = b[1, 1]
    b12 = b[1, 2]
    b13 = b[1, 3]
    b20 = b[2, 0]
    b21 = b[2, 1]
    b22 = b[2, 2]
    b23 = b[2, 3]
    b30 = b[3, 0]
    b31 = b[3, 1]
    b32 = b[3, 2]
    b33 = b[3, 3]

  result[0, 0] = b00 * a00 + b01 * a10 + b02 * a20 + b03 * a30
  result[0, 1] = b00 * a01 + b01 * a11 + b02 * a21 + b03 * a31
  result[0, 2] = b00 * a02 + b01 * a12 + b02 * a22 + b03 * a32
  result[0, 3] = b00 * a03 + b01 * a13 + b02 * a23 + b03 * a33

  result[1, 0] = b10 * a00 + b11 * a10 + b12 * a20 + b13 * a30
  result[1, 1] = b10 * a01 + b11 * a11 + b12 * a21 + b13 * a31
  result[1, 2] = b10 * a02 + b11 * a12 + b12 * a22 + b13 * a32
  result[1, 3] = b10 * a03 + b11 * a13 + b12 * a23 + b13 * a33

  result[2, 0] = b20 * a00 + b21 * a10 + b22 * a20 + b23 * a30
  result[2, 1] = b20 * a01 + b21 * a11 + b22 * a21 + b23 * a31
  result[2, 2] = b20 * a02 + b21 * a12 + b22 * a22 + b23 * a32
  result[2, 3] = b20 * a03 + b21 * a13 + b22 * a23 + b23 * a33

  result[3, 0] = b30 * a00 + b31 * a10 + b32 * a20 + b33 * a30
  result[3, 1] = b30 * a01 + b31 * a11 + b32 * a21 + b33 * a31
  result[3, 2] = b30 * a02 + b31 * a12 + b32 * a22 + b33 * a32
  result[3, 3] = b30 * a03 + b31 * a13 + b32 * a23 + b33 * a33

###############################################################################
# matrix / vector multiplication

proc `*`*[T](a: GMat3[T], b: GVec3[T]): GVec3[T] =
  gvec3[T](a[0, 0] * b.x + a[1, 0] * b.y + a[2, 0] * b.z,
           a[0, 1] * b.x + a[1, 1] * b.y + a[2, 1] * b.z,
           a[0, 2] * b.x + a[1, 2] * b.y + a[2, 2] * b.z)

proc `*`*[T](a: GMat4[T], b: GVec4[T]): GVec4[T] =
  gvec4[T](a[0, 0] * b.x + a[1, 0] * b.y + a[2, 0] * b.z + a[3, 0] * b.w,
           a[0, 1] * b.x + a[1, 1] * b.y + a[2, 1] * b.z + a[3, 1] * b.w,
           a[0, 2] * b.x + a[1, 2] * b.y + a[2, 2] * b.z + a[3, 2] * b.w,
           a[0, 3] * b.x + a[1, 3] * b.y + a[2, 3] * b.z + a[3, 3] * b.w)

###############################################################################
# transpose

proc transpose*[T](a: GMat3[T]): GMat3[T] =
  ## Return an transpose of the matrix.
  gmat3[T](a[0, 0], a[1, 0], a[2, 0],
           a[0, 1], a[1, 1], a[2, 1],
           a[0, 2], a[1, 2], a[2, 2])

proc transpose*[T](a: GMat4[T]): GMat4[T] =
  ## Return an transpose of the matrix.
  gmat4[T](a[0, 0], a[1, 0], a[2, 0], a[3, 0],
           a[0, 1], a[1, 1], a[2, 1], a[3, 1],
           a[0, 2], a[1, 2], a[2, 2], a[3, 2],
           a[0, 3], a[1, 3], a[2, 3], a[3, 3])

