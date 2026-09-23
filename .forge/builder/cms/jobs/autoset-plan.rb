$wr_no_autorun = true
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/proposal-package.rb'
m = Sketchup.active_model
booth, note = WR_AutoSet.resolve_booth(m, 'MDL 96144 E (components)')
puts "resolve note: #{note.inspect}"
raise 'no booth' if booth.nil?
puts "DEFAULT_RENDERS=#{WR_AutoSet::DEFAULT_RENDERS} MAX=#{WR_AutoSet::MAX_RENDERS}"
pl = WR_AutoSet.plan(m, booth, { 'renders' => WR_AutoSet::MAX_RENDERS, 'interior' => true })
puts "token=#{pl['token']} label=#{pl['label']} door=#{pl['door']} vent=#{pl['vent']} walls=#{pl['walls']} size=#{pl['size']}"
pl['rows'].each { |r| puts "   #{r['plate']}  #{r['want']}  mode=#{r['mode']}  (#{r['what']})" }
:plan
