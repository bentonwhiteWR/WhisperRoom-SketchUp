# Start one V-Ray frame. Everything the frame depends on is set IN THIS JOB,
# immediately before render_production: size/budget, exposure, the scene's
# hidden room pieces and camera (never by selecting the page - see
# WR_ConceptRender.stage_page!), and the sun last.
load 'C:/Users/bento/Documents/Claude/Sketchup/.forge/builder/concept-art/render.rb'
R = WR_ConceptRender
out = {}
out['settings'] = R.settings!($rt_w || 960, $rt_h || 540, $rt_min || 2.5, $rt_thr || 0.03)
out['ev'] = R.ev!($rt_ev || 14.23).round(2)
if $rt_page
  out['stage'] = R.stage_page!($rt_page)
else
  R.show_room!
  out['eye'] = R.aim_cam!($rt_eye, $rt_tgt, $rt_fov)
end
out['sun'] = R.sun!($rt_az || 195.0, $rt_el || 14.0)
out['sun_mult'] = R.sun_intensity!($rt_sun_mult || 1.0)
out['start'] = R.start!
out
