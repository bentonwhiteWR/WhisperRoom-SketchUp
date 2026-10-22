$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/proposal-package.rb' unless defined?(WR_ProposalPackage)
m = Sketchup.active_model
SCR = 'C:/Users/bento/AppData/Local/Temp/claude/C--Users-bento-Documents-Claude-Sketchup/35e4c934-e1df-44e1-b92c-2f0ecd7fe560/scratchpad'
start = m.pages.selected_page
pg = m.pages['Booth - MDL 96168 S RM (21 Oct link) 03-high']
prev = m.options['PageOptions']['ShowTransition']
m.options['PageOptions']['ShowTransition'] = false
m.pages.selected_page = pg
v = m.active_view
r1 = v.write_image(:filename => "#{SCR}/r1-plain.png", :width => 1920, :height => 1080, :antialias => true, :transparent => false)
r2 = v.write_image(:filename => "#{SCR}/r2-trans.png", :width => 1920, :height => 1080, :antialias => true, :transparent => true)
m.pages.selected_page = start
m.options['PageOptions']['ShowTransition'] = prev
[r1, r2]
