# copy and paste from https://github.com/treeform/vmath/blob/master/src/vmath.nim
# i did this so could fully grok it... and do some things differently.
# I mainly 80% copy and pasted!
# all credit goes to treeform et al, such beautiful code!

import math
from strutils import toLowerAscii

type
  GVec2*[T] = object
    arr: array[2, T]
  GVec3*[T] = object
    arr: array[3, T]
  GVec4*[T] = object
    arr: array[4, T]

  # generics
  GVec34[T] = GVec3[T] | GVec4[T]
  GVec234[T] = GVec2[T] | GVec3[T] | GVec4[T]

template gvec2*[T](x, y: T): GVec2[T] =
  GVec2[T](arr: [T(x), T(y)])

template gvec3*[T](x, y, z: T): GVec3[T] =
  GVec3[T](arr: [T(x), T(y), T(z)])

template gvec4*[T](x, y, z, w: T): GVec4[T] =
  GVec4[T](arr: [T(x), T(y), T(z), T(w)])

# XXX why not GVec234 here (maybe cause need to distinct between var and non var?)
template x*[T](a: var GVec2[T]): var T = a.arr[0]
template x*[T](a: var GVec3[T]): var T = a.arr[0]
template x*[T](a: var GVec4[T]): var T = a.arr[0]

template y*[T](a: var GVec2[T]): var T = a.arr[1]
template y*[T](a: var GVec3[T]): var T = a.arr[1]
template y*[T](a: var GVec4[T]): var T = a.arr[1]

template z*[T](a: var GVec3[T]): var T = a.arr[2]
template z*[T](a: var GVec4[T]): var T = a.arr[2]
template w*[T](a: var GVec4[T]): var T = a.arr[3]

template x*[T](a: GVec2[T]): T = a.arr[0]
template x*[T](a: GVec3[T]): T = a.arr[0]
template x*[T](a: GVec4[T]): T = a.arr[0]

template y*[T](a: GVec2[T]): T = a.arr[1]
template y*[T](a: GVec3[T]): T = a.arr[1]
template y*[T](a: GVec4[T]): T = a.arr[1]

template z*[T](a: GVec3[T]): T = a.arr[2]
template z*[T](a: GVec4[T]): T = a.arr[2]
template w*[T](a: GVec4[T]): T = a.arr[3]

template `x=`*[T](a: var GVec234[T], value: T) =
    a.arr[0] = value

template `y=`*[T](a: var GVec234[T], value: T) =
    a.arr[1] = value

template `z=`*[T](a: var GVec34[T], value: T) =
    a.arr[2] = value

template `w=`*[T](a: var GVec4[T], value: T) =
    a.arr[3] = value

template `[]`*[T](a: GVec234[T], i: int): T = a.arr[i]
template `[]=`*[T](a: var GVec234[T], i: int, v: T) = a.arr[i] = v

type
  BVec2* = GVec2[bool]
  BVec3* = GVec3[bool]
  BVec4* = GVec4[bool]

  IVec2* = GVec2[int32]
  IVec3* = GVec3[int32]
  IVec4* = GVec4[int32]

  UVec2* = GVec2[uint32]
  UVec3* = GVec3[uint32]
  UVec4* = GVec4[uint32]

  Vec2* = GVec2[float32]
  Vec3* = GVec3[float32]
  Vec4* = GVec4[float32]

  DVec2* = GVec2[float64]
  DVec3* = GVec3[float64]
  DVec4* = GVec4[float64]

template lowerType(a: typed): string =
  ($type(a)).toLowerAscii()

template genConstructor(lower, upper, typ: untyped) =

  proc `lower 2`*(): `upper 2` = gvec2[typ](typ(0), typ(0))
  proc `lower 3`*(): `upper 3` = gvec3[typ](typ(0), typ(0), typ(0))
  proc `lower 4`*(): `upper 4` = gvec4[typ](typ(0), typ(0), typ(0), typ(0))

  proc `lower 2`*(x, y: typ): `upper 2` = gvec2[typ](x, y)
  proc `lower 3`*(x, y, z: typ): `upper 3` = gvec3[typ](x, y, z)
  proc `lower 4`*(x, y, z, w: typ): `upper 4` = gvec4[typ](x, y, z, w)

  proc `lower 2`*(x: typ): `upper 2` = gvec2[typ](x, x)
  proc `lower 3`*(x: typ): `upper 3` = gvec3[typ](x, x, x)
  proc `lower 4`*(x: typ): `upper 4` = gvec4[typ](x, x, x, x)

  proc `$`*(a: `upper 2`): string =
    lowerType(a) & "(" & $a.x & ", " & $a.y & ")"
  proc `$`*(a: `upper 3`): string =
    lowerType(a) & "(" & $a.x & ", " & $a.y & ", " & $a.z & ")"
  proc `$`*(a: `upper 4`): string =
    lowerType(a) & "(" & $a.x & ", " & $a.y & ", " & $a.z & ", " & $a.w & ")"

# only have two types here... easy to add more
genConstructor(ivec, IVec, int32)
genConstructor(vec, Vec, float32)



proc `~=`*[T: SomeFloat](a, b: T): bool =
  ## Almost equal.
  const epsilon = 0.000001
  abs(a - b) <= epsilon

proc `==`*[T](a, b: GVec2[T]): bool =
  a.x == b.x and a.y == b.y

proc `==`*[T](a, b: GVec3[T]): bool =
  a.x == b.x and a.y == b.y and a.z == b.z

proc `==`*[T](a, b: GVec4[T]): bool =
  a.x == b.x and a.y == b.y and a.z == b.z and a.w == b.w


proc `!=`*[T](a, b: GVec234[T]): bool =
  # XXX causes bad shortcircuit-ing ?
  not (a == b)


template genOp(op: untyped) =
  proc op*[T](a, b: GVec2[T]): GVec2[T] =
    gvec2[T](
      op(a[0], b[0]),
      op(a[1], b[1])
    )

  proc op*[T](a, b: GVec3[T]): GVec3[T] =
    gvec3[T](
      op(a[0], b[0]),
      op(a[1], b[1]),
      op(a[2], b[2])
    )

  proc op*[T](a, b: GVec4[T]): GVec4[T] =
    gvec4[T](
      op(a[0], b[0]),
      op(a[1], b[1]),
      op(a[2], b[2]),
      op(a[3], b[3])
    )

  proc op*[T](a: GVec2[T], b: T): GVec2[T] =
    gvec2[T](
      op(a[0], b),
      op(a[1], b)
    )

  proc op*[T](a: GVec3[T], b: T): GVec3[T] =
    gvec3[T](
      op(a[0], b),
      op(a[1], b),
      op(a[2], b)
    )

  proc op*[T](a: GVec4[T], b: T): GVec4[T] =
    gvec4[T](
      op(a[0], b),
      op(a[1], b),
      op(a[2], b),
      op(a[3], b)
    )

  proc op*[T](a: T, b: GVec2[T]): GVec2[T] =
    gvec2[T](
      op(a, b[0]),
      op(a, b[1])
    )

  proc op*[T](a: T, b: GVec3[T]): GVec3[T] =
    gvec3[T](
      op(a, b[0]),
      op(a, b[1]),
      op(a, b[2])
    )

  proc op*[T](a: T, b: GVec4[T]): GVec4[T] =
    gvec4[T](
      op(a, b[0]),
      op(a, b[1]),
      op(a, b[2]),
      op(a, b[3])
    )

genOp(`+`)
genOp(`-`)
genOp(`*`)
genOp(`/`)
genOp(`div`)

# XXX
#genOp(`mod`)
#genOp(`zmod`)

template genEqOp(op: untyped) =
  proc op*[T](a: var GVec2[T], b: GVec2[T]) =
    op(a.x, b.x)
    op(a.y, b.y)

  proc op*[T](a: var GVec3[T], b: GVec3[T]) =
    op(a.x, b.x)
    op(a.y, b.y)
    op(a.z, b.z)

  proc op*[T](a: var GVec4[T], b: GVec4[T]) =
    op(a.x, b.x)
    op(a.y, b.y)
    op(a.z, b.z)
    op(a.w, b.w)

  proc op*[T](a: var GVec2[T], b: T) =
    op(a.x, b)
    op(a.y, b)

  proc op*[T](a: var GVec3[T], b: T) =
    op(a.x, b)
    op(a.y, b)
    op(a.z, b)

  proc op*[T](a: var GVec4[T], b: T) =
    op(a.x, b)
    op(a.y, b)
    op(a.z, b)
    op(a.w, b)

genEqOp(`+=`)
genEqOp(`-=`)
genEqOp(`*=`)
genEqOp(`/=`)

template genMathFn(fn: untyped) =
  proc fn*[T](v: GVec2[T]): GVec2[T] =
    gvec2[T](
      fn(v[0]),
      fn(v[1])
    )

  proc fn*[T](v: GVec3[T]): GVec3[T] =
    gvec3[T](
      fn(v[0]),
      fn(v[1]),
      fn(v[2])
    )

  proc fn*[T](v: GVec4[T]): GVec4[T] =
    gvec4[T](
      fn(v[0]),
      fn(v[1]),
      fn(v[2]),
      fn(v[3])
    )

genMathFn(`-`)
genMathFn(sin)
genMathFn(cos)
genMathFn(tan)

# general maths stuff on vectors

proc length*[T](a: GVec2[T]): T =
  sqrt(a.x*a.x + a.y*a.y)

proc length*[T](a: GVec3[T]): T =
  sqrt(a.x*a.x + a.y*a.y + a.z*a.z)

proc length*[T](a: GVec4[T]): T =
  sqrt(a.x*a.x + a.y*a.y + a.z*a.z + a.w*a.w)

proc normalise*[T](a: GVec234[T]): type(a) =
  a / a.length

proc cross*[T](a, b: GVec3[T]): GVec3[T] =
  gvec3(
    a.y * b.z - a.z * b.y,
    a.z * b.x - a.x * b.z,
    a.x * b.y - a.y * b.x
  )
