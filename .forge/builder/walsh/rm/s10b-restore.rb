load File.join(File.dirname(__FILE__), 'geom.rb')
$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/proposal-package.rb' unless defined?(WR_ProposalPackage)
m = Sketchup.active_model
raise 'batch still running' if WR_ProposalPackage.instance_variable_get(:@running)
h = Hash[*m.get_attribute('WalshRM', 's10_held', [])]
pre = 'Booth - MDL 96168 S RM (21 Oct link) '
# old v1/v2 render pages stay Skip so a later V-Ray run never renders a retired scene
h.each { |n, md| WR_ProposalPackage.set_mode(m.pages[n], n.start_with?(pre) ? md : 'skip') }
m.delete_attribute('WalshRM', 's10_held')
m.pages.selected_page = m.pages['Booth - MDL 96168 S RM (21 Oct link) 01-angled']
WalshRM.save(m)
m.pages.each { |q| puts "  #{q.name}: #{WR_ProposalPackage.mode_of(q)}" }
true
