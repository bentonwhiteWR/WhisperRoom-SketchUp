load 'C:/Users/bento/AppData/Local/Temp/claude/C--Users-bento-OneDrive-Documents-Claude-Sketchup/9b940cf8-f4c1-482d-86e5-25eb21d96e0b/scratchpad/cyc/lib.rb'
before = CYC.census
File.write(File.join(CYC::OUT, 'census-before.json'), JSON.pretty_generate(before))
m = CYC.model
booth, note = WR_AutoSet.resolve_booth(m)
raise "resolve_booth: #{note}" if booth.nil?
ok, msg, lines = WR_AutoSet.apply(m, booth, { 'mode' => 'create' })
puts "AUTO-SET ok=#{ok} #{msg}"
(lines || []).each { |l| puts "   #{l}" }
# only the angled render row stays live; every other page is skipped for this experiment
m.pages.each { |p| WR_ProposalPackage.set_mode(p, p.name =~ /01-angled r\z/ ? 'render' : 'skip') }
{ 'before' => before, 'after' => CYC.census }
