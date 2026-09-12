load 'C:/Users/bento/AppData/Local/Temp/claude/C--Users-bento-OneDrive-Documents-Claude-Sketchup/9b940cf8-f4c1-482d-86e5-25eb21d96e0b/scratchpad/t3/t3-lib.rb'
a = DCYC.audit!('post-render')
{ 'ok' => a['ok'], 'rig' => a['rig'], 'model' => a['model'], 'off' => a['off'],
  'dead' => a['dead'], 'wrong' => a['wrong'], 'ghosts' => a['ghosts'] }
