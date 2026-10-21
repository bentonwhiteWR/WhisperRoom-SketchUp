# Walsh v3 step 8b: after the image export finishes, put the render plates back to Render, then save.
load File.join(File.dirname(__FILE__), 'geom.rb')
m = Sketchup.active_model
raise 'batch still running' if WR_ProposalPackage.instance_variable_get(:@running)
held = m.get_attribute('WalshRM', 'render_held') || []
held.each { |n| (p = m.pages[n]) && WR_ProposalPackage.set_mode(p, 'render') }
m.delete_attribute('WalshRM', 'render_held')
m.pages.each { |p| puts "  #{p.name}: #{WR_ProposalPackage.mode_of(p)}" if p.get_attribute('WR_AutoSet', 'token') }
puts "selected page now #{m.pages.selected_page && m.pages.selected_page.name}"
WalshRM.save(m)
puts "saved #{m.path}"
