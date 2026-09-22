# The proposal scene set, from the house tool: WR_AutoSet (AUTO-SET), headless.
$wr_as_mode = "update"
$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/proposal-package.rb'
m = Sketchup.active_model
booth, note = WR_AutoSet.resolve_booth(m, 'MDL 96120 E (components)')
raise(note || 'no booth') if booth.nil?
ok, msg, lines = WR_AutoSet.apply(m, booth, { 'mode' => ($wr_as_mode || 'create'), 'renders' => WR_AutoSet::MAX_RENDERS,
                                              'interior' => true, 'reaim' => true })
puts "ok=#{ok} msg=#{msg}"
(lines || []).each { |l| puts "  #{l}" }
puts "PAGES: " + m.pages.map(&:name).inspect
:applied
