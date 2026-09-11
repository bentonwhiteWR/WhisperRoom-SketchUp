load 'C:/Users/bento/AppData/Local/Temp/claude/C--Users-bento-OneDrive-Documents-Claude-Sketchup/9b940cf8-f4c1-482d-86e5-25eb21d96e0b/scratchpad/cyc/lib.rb'
st = WR_DropLights.default_settings
st['mult'] = ($cyc_mult || 1.0)
CYC.drop(st)
CYC.census
