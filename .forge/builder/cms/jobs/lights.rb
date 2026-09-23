$wr_no_autorun = true
D = 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/'
load D + 'scripts/wr-drop-lights.rb'
load D + '.forge/builder/cms/room.rb'
load D + '.forge/builder/cms/lights.rb'
r = WR_CMS_Lights.place!
a = []; VRay::Context.active.scene.each { |p| a << p.name if p.category.to_s =~ /light/i }
r.merge('vray_lights' => a.size, 'audit_missing' => WR_CMS_Lights.audit.reject { |x| x[2] }.size,
        'audit' => WR_CMS_Lights.audit.map { |x| [x[0], x[3], x[4], x[5]] })
