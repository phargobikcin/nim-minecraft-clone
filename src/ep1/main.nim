include thin/simpleapp

type
  MinecraftClone = ref object of App


method draw(self: MinecraftClone) =
  gl.glClearColor(1.0, 0.5, 1.0, 1.0)
  self.clear()


when isMainModule:
  start(MinecraftClone, system.currentSourcePath,
        w=800, h=600, title="Minecraft clone", doResize=true, vsync=false)
