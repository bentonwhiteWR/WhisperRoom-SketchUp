# One cycle's rig: verified reset, drop, audit. See d-lib.rb.
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/fixer/rank-loop/d-lib.rb'
DCYC.reset!
DCYC.drop!
a = DCYC.audit!('pre-render')
raise "AUDIT NOT OK — this cycle is VOID and must not be rendered" unless a['ok']
{ 'ok' => a['ok'], 'rig' => a['rig'], 'model' => a['model'],
  'off' => a['off'], 'lights' => DCYC.vray_lights.length,
  'rig_entities' => DCYC.rig_entities }
