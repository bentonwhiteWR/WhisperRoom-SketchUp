$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/.forge/builder/concept-art/scene-build.rb'
m = Sketchup.active_model
pg = m.pages['MDL 96120 E (components) 01-angled r']
m.options['PageOptions']['TransitionTime'] = 0.0
m.pages.selected_page = pg if pg      # restores this scene's own hidden state (nothing hidden)
WR_Concept.view_hero!
:hero
