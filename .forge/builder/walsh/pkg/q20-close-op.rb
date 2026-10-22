# Close the operation s6 left open when it raised (commit, never a blind abort), report state.
m = Sketchup.active_model
r = (m.commit_operation rescue "commit raised #{$!.message}")
puts "commit -> #{r.inspect}"
puts "layers: WR-Ceiling=#{m.layers['WR-Ceiling'].visible?} WR Lights=#{m.layers['WR Lights'].visible?} page=#{m.pages.selected_page&.name}"
puts "PAGE_USE_LAYER_VISIBILITY=#{defined?(PAGE_USE_LAYER_VISIBILITY) ? PAGE_USE_LAYER_VISIBILITY : 'undef'}"
true
