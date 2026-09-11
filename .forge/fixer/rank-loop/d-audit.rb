# Re-audit AFTER the render: proof the frame that was written is the rig the
# pre-render audit passed. A post-render audit that differs voids the frame.
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/fixer/rank-loop/d-lib.rb'
a = DCYC.audit!('post-render')
{ 'ok' => a['ok'], 'rig' => a['rig'], 'model' => a['model'], 'off' => a['off'] }
