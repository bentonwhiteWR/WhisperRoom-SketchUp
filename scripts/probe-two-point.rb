# @title Probe two-point perspective...
# @shelf dev
# @cat Proposal package
# @rank 8
#
# Which call in the proposal package's export path drops a scene's
# two-point perspective? Run this ON A TWO-POINT SCENE and it tells you.
#
#   1. Click a scene tab whose camera is two-point (Camera > Two-Point
#      Perspective was on when the scene was created/updated).
#   2. Extensions > Developer > Ruby Console, then:
#        load "C:/Users/bento/Documents/Claude/Sketchup/scripts/probe-two-point.rb"
#   3. Read the table it prints. Then OPEN the two PNGs it names and look at
#      the verticals: parallel = two-point survived the write, converging =
#      write_image flattened it. THAT is the load-bearing check for the image
#      lane -- a flag reading after the write cannot see inside the file.
#
# Benton, 10 Sep 2026: "when we're exporting scenes, it's not saving the
# two-point perspective. It's only going like the flat perspective."
#
# REPORTED (ruby.sketchup.com Sketchup::Camera; api-issue-tracker #88, open):
# Camera#is_2d? READS two-point; nothing in the API WRITES it. So this probe
# can only find the call that loses it, so proposal-package.rb can stop
# making that call. It cannot fix a lost one, and it does not try.
#
# What it does to the model: switches the selected scene (with transitions
# off, put back after), assigns the view camera, writes two PNGs into the
# Windows temp folder, and ends by re-selecting the scene it started on. It
# saves nothing and edits no entity. If the scene it started on is not
# two-point on return, that in itself is a finding, and the console says so.
#
# UNRUN here -- no ruby.exe outside SketchUp. Syntax checked with rbparse.py.
module WR_ProbeTwoPoint

  def self.flag(cam)
    return 'unreadable' if cam.nil? || !cam.respond_to?(:is_2d?)
    cam.is_2d? ? 'two-point' : 'ordinary'
  rescue Exception => e
    "unreadable (#{e.class})"
  end

  def self.line(c = '-')
    puts(c * 74)
  end

  def self.run
    model = Sketchup.active_model
    view  = model.active_view
    pages = model.pages
    page  = pages.selected_page
    rows  = []
    note  = lambda { |step, reading, what| rows << [step, reading, what]; puts format('  %-42s %-12s %s', step, reading, what) }

    line('=')
    puts 'TWO-POINT PERSPECTIVE PROBE'
    line('=')
    if page.nil?
      puts 'No scene is selected. Click a two-point scene tab first.'
      return
    end
    saved = (page.use_camera? rescue false)
    puts "scene: #{page.name}   saves camera: #{saved}   " \
         "saved projection: #{saved ? flag(page.camera) : 'n/a'}   " \
         "viewport now: #{flag(view.camera)}"
    unless saved && flag(page.camera) == 'two-point'
      puts 'This scene does not save a two-point camera. Camera > Two-Point ' \
           'Perspective, right-click the scene tab > Update, then run again.'
      return
    end

    opts    = model.options['PageOptions']
    prev_tt = opts['TransitionTime']
    opts['TransitionTime'] = 0
    tmp = (ENV['TEMP'] || ENV['TMP'] || Dir.tmpdir rescue '.')
    f_vp = File.join(tmp, 'wr-two-point-probe-viewport-size.png')
    f_16 = File.join(tmp, 'wr-two-point-probe-1600x900.png')
    begin
      line
      puts format('  %-42s %-12s %s', 'STEP', 'VIEWPORT', 'MEANS')
      line
      # 1. scene switch from Ruby, transitions off -- what every lane does
      pages.selected_page = page
      view.refresh
      r = flag(view.camera)
      note.call('1 pages.selected_page = (transitions 0)', r,
                r == 'two-point' ? 'the switch restores two-point' :
                                   'THE SWITCH ITSELF LOSES IT - scenes do not round-trip it')
      # 2. the render lane's settling assignment
      view.camera = page.camera
      view.refresh
      r = flag(view.camera)
      note.call('2 view.camera = page.camera', r,
                r == 'two-point' ? 'assigning a Camera object keeps it' :
                                   'ASSIGNING A CAMERA OBJECT FLATTENS IT (render lane + finish)')
      pages.selected_page = page
      view.refresh
      note.call('   re-select the scene', flag(view.camera), 'back to where step 1 left it')
      # 3. write_image at the viewport's own size
      ok = view.write_image(:filename => f_vp, :width => view.vpwidth,
                            :height => view.vpheight, :antialias => true)
      r = flag(view.camera)
      note.call("3 write_image #{view.vpwidth}x#{view.vpheight} (#{ok ? 'written' : 'FAILED'})", r,
                'flag after the write; the FILE decides - open it')
      pages.selected_page = page
      view.refresh
      # 4. write_image at the package size, 1600x900 -- the image lane
      ok = view.write_image(:filename => f_16, :width => 1600, :height => 900,
                            :antialias => true)
      r = flag(view.camera)
      note.call("4 write_image 1600x900 (#{ok ? 'written' : 'FAILED'})", r,
                'flag after the write; the FILE decides - open it')
      # 5. is there an undocumented action that re-enters two-point?
      pages.selected_page = page
      view.camera = page.camera   # deliberately flatten (if step 2 does)
      view.refresh
      before = flag(view.camera)
      %w[view2PointPerspective: viewTwoPointPerspective:].each do |a|
        sent = (Sketchup.send_action(a) rescue false)
        view.refresh
        note.call("5 send_action(#{a})", flag(view.camera),
                  "returned #{sent.inspect}, was #{before} before")
      end
    ensure
      pages.selected_page = page
      view.refresh
      opts['TransitionTime'] = prev_tt
    end
    line
    puts "ended on scene '#{page.name}', viewport: #{flag(view.camera)}"
    puts 'NOW OPEN THESE AND LOOK AT THE VERTICALS (parallel = two-point):'
    puts "  #{f_vp}"
    puts "  #{f_16}"
    puts 'If the 1600x900 file converges and the viewport-size one does not, the'
    puts 'image lane loses two-point to the size change in write_image; if both'
    puts 'converge but step 1 read two-point, write_image loses it regardless of'
    puts 'size; if neither converges, the image lane is not the culprit.'
    line('=')
    rows
  rescue Exception => e
    puts "probe failed: #{e.class}: #{e.message}"
    puts e.backtrace.first(5).join("\n")
  end
end

WR_ProbeTwoPoint.run
