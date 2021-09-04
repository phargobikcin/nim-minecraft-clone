import strutils
import strformat

import nimgl/opengl as gl

import logsetup as logging
import simpleutils

# so doesn't clash with other packages
import ./vector, ./matrix

type
  Shader* = ref object
    shaderId: GLuint
    shaderType: GLenum

type
  ShaderProgram* = ref object
    programId: GLuint

###############################################################################
# prototypes

proc dumpInfo*(self: ShaderProgram)

###############################################################################

proc check(id: GLuint, what: GLenum, msg: string,
           statusFn: typeof(glGetProgramiv),
           logFn: typeof(glGetProgramInfoLog)) =

  var status: GLint
  statusFn(id, what, addr status)

  l_verbose(msg & " checking status: " & $status)
  if status == 0:
    var length: GLint
    statusFn(id, GL_INFO_LOG_LENGTH, addr length)

    if length > 0:
      var buf = cast[cstring](alloca(uint8, length + 1))

      # this is fine, since speed not too important
      #XXXvar buf = newSeq[char](sz + 1)

      logFn(id, length, nil, addr buf[0])
      let error = msg & " ERROR: " & $buf
      l_error(error)

      # XXX custom exception
      raise newException(Exception, error)


proc checkCompile(self: Shader, msg: string) =
  check(self.shaderId, GL_COMPILE_STATUS, msg, glGetShaderiv, glGetShaderInfoLog)


proc check(self: ShaderProgram, what: GLenum, msg: string) =
  check(self.programId, what, msg, glGetProgramiv, glGetProgramInfoLog)


proc shaderStringType(shaderType: GLenum): string =
  case shaderType:
    of GL_VERTEX_SHADER: "vertex shader"
    of GL_GEOMETRY_SHADER: "geometry shader"
    of GL_FRAGMENT_SHADER: "fragment shader"
    else: "unknown"


# note destroy must be declared before compile()
proc `=destroy`*(self: var typeOfDeref(ShaderProgram)) =
  l_warning("***DELETING** program")
  glDeleteProgram(self.programId)

proc compile*(code: string, shaderType: GLenum): Shader =
  var id = glCreateShader(shaderType)
  var compatString = code.cstring
  glShaderSource(id, 1, addr compatString, nil)
  glCompileShader(id)
  result = Shader(shaderId: id, shaderType: shaderType)
  checkCompile(result, "Compiling - " & shaderStringType(shaderType))


proc link*(shaders: openArray[Shader]): ShaderProgram =
  var program = ShaderProgram(programId: glCreateProgram())
  for s in shaders:
    l_verbose("attaching shader", s.shaderId, "to program", program.programId)
    glAttachShader(program.programId, s.shaderId)

  glLinkProgram(program.programId)
  program.check(GL_LINK_STATUS, "link status")

  glValidateProgram(program.programId)
  program.check(GL_VALIDATE_STATUS, "validate status")

  for s in shaders:
    glDetachShader(program.programId, s.shaderId)
    glDeleteShader(s.shaderId)

  program.dumpInfo()
  return program


proc active*(self: ShaderProgram): bool =
  var cur: GLint
  glGetIntegerv(GL_CURRENT_PROGRAM, addr cur)
  return cur == GLint(self.programId)


proc use*(self: ShaderProgram) =
  glUseProgram(self.programId)


proc stop*(self: ShaderProgram) =
  if self.active():
    glUseProgram(0)

proc varTypeToString(varType: GLenum): string =
  case varType:
    of GL_BOOL: "bool"
    of EGL_INT: "int"
    of EGL_FLOAT: "float"
    of GL_FLOAT_VEC2: "vec2"
    of GL_FLOAT_VEC3: "vec3"
    of GL_FLOAT_VEC4: "vec4"
    of GL_FLOAT_MAT2: "mat2"
    of GL_FLOAT_MAT3: "mat3"
    of GL_FLOAT_MAT4: "mat4"
    of GL_SAMPLER_2D: "sampler2D"
    of GL_SAMPLER_3D: "sampler3D"
    of GL_SAMPLER_CUBE: "samplerCube"
    of GL_SAMPLER_2D_SHADOW: "sampler2DShadow"
    else: "other"

proc dumpInfo*(self: ShaderProgram) =
  # size of the variable
  var size: GLint

  # type of the variable (float, vec3 or mat4, etc)
  var varType: GLenum

  # maximum name length
  const sz: GLsizei = 64

  # name length
  var length: GLsizei

  # Attributes
  var count: GLint
  glGetProgramiv(self.programId, GL_ACTIVE_ATTRIBUTES, addr count)

  l_info(fmt"Active Attributes: {count}")

  for i in 0..<count:
    var buf = newSeq[char](sz + 1)
    glGetActiveAttrib(self.programId, GLuint i, sz, addr length, addr size, addr varType, addr buf[0])
    let varStr: string = varTypeToString(varType)
    l_info(fmt"Attribute #{i} Type: {varStr} Name: {buf.join()}")

  # Uniforms
  glGetProgramiv(self.programId, GL_ACTIVE_UNIFORMS, addr count)
  l_info(fmt"Active Uniforms: {count}")
  for i in 0..<count:
    var buf = newSeq[char](sz + 1)
    glGetActiveUniform(self.programId, GLuint i, sz, addr length, addr size, addr varType, addr buf[0])
    let varStr: string = varTypeToString(varType)
    l_info(fmt"Uniform #{i} Type: {varStr} Name: {buf.join()}")


proc findUniform*(self: ShaderProgram, name: string): int =
  return glGetUniformLocation(self.programId, name.cstring)


proc setUniform*(self: ShaderProgram, location: int, v: bool) =
  glUniform1i(location.cint, ord(v).cint)

proc setUniform*(self: ShaderProgram, location: int, i: int) =
  glUniform1i(location.cint, i.cint)

proc setUniform*(self: ShaderProgram, location: int, m: float) =
  glUniform1f(location.cint, m.GLfloat)


proc setUniform*(self: ShaderProgram, location: int, v: Vec3) =
  glUniform3fv(location.cint, count=1, cast[ptr GLfloat](unsafeAddr v))

proc setUniform*(self: ShaderProgram, location: int, v: Vec4) =
  glUniform4fv(location.cint, count=1, cast[ptr GLfloat](unsafeAddr v))

proc setUniform*(self: ShaderProgram, location: int, m: Mat4) =
  glUniformMatrix4fv(location.cint, count=1,
                     transpose=false, cast[ptr GLfloat](unsafeAddr m))

const defaultVertexShader = """
#version 330 core

layout(location=0) in vec3 pos;

void main(void) {
    gl_Position = vec4(pos, 1.0);
}
"""

const defaultFragmentShader = """
#version 330 core

out vec4 colour;

uniform vec3 objectColor = vec3(0.5, 0.5, 1.0);

void main(void) {
    colour = vec4(objectColor, 1.0f);
}
"""

proc program*(vertexShader=defaultVertexShader,
              fragmentShader=defaultFragmentShader): ShaderProgram =
  let v = compile(vertexShader, gl.GL_VERTEX_SHADER)
  let f = compile(fragmentShader, gl.GL_FRAGMENT_SHADER)
  result = link(@[v, f])

