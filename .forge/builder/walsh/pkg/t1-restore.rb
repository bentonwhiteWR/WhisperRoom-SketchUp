# Put the package marks back exactly as stored by t1-testrender.rb.
load 'C:/Users/bento/Documents/Claude/Sketchup/.forge/builder/walsh/rm/geom.rb'
require 'json'
m = Sketchup.active_model
raise 'batch still running' if WR_ProposalPackage.instance_variable_get(:@running)
marks = JSON.parse(m.get_attribute('walsh_pkg2', 'marks') || raise('no stored marks'))
m.pages.each { |p| WR_ProposalPackage.set_mode(p, marks.fetch(p.name)) }
m.attribute_dictionary('walsh_pkg2').delete_key('marks')
WalshRM.save(m)
m.pages.each { |p| puts "  #{p.name} -> #{WR_ProposalPackage.mode_of(p)}" }
true
