import os
import ../simpleutils

# Include the header
{.compile: "read.c".}

proc stbi_load(filename: cstring; x, y, channels_in_file: ptr cint; desired_channels: cint): ptr cuchar
  {.importc: "stbi_load"}

proc stbi_image_free(retval_from_stbi_load: pointer)
    {.importc: "stbi_image_free"}

proc stbi_set_flip_vertically_on_load(flag_true_if_should_flip: cint)
    {.importc: "stbi_set_flip_vertically_on_load"}


type
  STBImage* = ref object of RootObj
    width*: int
    height*: int
    channels*: int
    data*: seq[uint8]


proc `$`*(self: STBImage): string =
  result = f"STBImage(width={self.width}, height={self.height}, channels={self.channels})"


proc loadImage*(path: string, desiredChannels: int, flip=false): STBImage =
  var
    width: cint
    height: cint
    channels: cint

  if not os.fileExists(path):
    raise newException(IOError, "file doesnt exist")

  if flip:
    stbi_set_flip_vertically_on_load(flip.ord.cint)

  # Read
  let data = stbi_load(path.cstring, addr width, addr height, addr channels,
                       desiredChannels.cint)

  result = STBImage(width: width.int,
                    height: height.int,
                    channels: channels.int)

  # ok this is cool, but there has to be a better way!
  let sz = result.width * result.height * channels
  for i in 0..<sz:
    let ptrdata = cast[ByteAddress](data) +% i
    let c = cast[ptr uint8](ptrdata)[]
    result.data.add(c)

  stbi_image_free(data)
