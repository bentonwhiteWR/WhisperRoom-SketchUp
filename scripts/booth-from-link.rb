# @title Build the customer's booth (share link)...
# @cat Build the booth
# @rank 1
#
# Paste a booth-builder share link, get that exact booth built from the real
# components. The customer's own arrangement — model, door hand, windows,
# vents, VSS/EFS, height extension — not a guess at it.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/booth-from-link.rb"
#
# Accepts both link forms the portal produces:
#
#   https://sales.whisperroom.com/booth-builder?d=e0d972ac9fec
#     A short id. The design lives server-side; this fetches
#     GET /api/booth-design/<id> (public, no auth) and reads the payload.
#
#   .../booth-builder#d=<long base64>
#     The legacy self-contained hash. Decoded locally, no network.
#
# The payload contract (from booth-builder.html's designPayload()):
#   m  'MDL 7272'   v 'S'|'E'    hx/vs/ef/cs/rp  0|1   a { slotId => pack }
#   packs: 'STDWL46' | 'STDWL46 VNT' | 'STDWL46 DRFRM R' | 'STDWL46 WDO3236'
#          | 'WA STDDRFRM L' | 'STDWL40 NV'
#
# Beyond the walls, the OPTION PARTS now come through too: desk (dk/dl/ds/dox),
# MJP jack panel (jp/ms), and the elevated floor (ep, or the ad ADA bundle's
# floor) ride into the builder's overlay pass (wr-overlays.rb), which also
# places the foam sheets and duct covers every booth ships with. Foam colour
# (f) is read and REPORTED — Foam.skp has no colour variants to apply.
#
# What still does NOT build, each named LOUDLY below rather than dropped:
# the caster PLATE half of cs (only the vent-art suffix is applied), step (sp,
# pairs with that plate), bass traps (bt) and the Audimute package (ac) — no
# .skp exists for either — the studio light (sl, no fixture .skp), and the
# roof-mounted vent (rv, out of scope per GOAL).
#
# STANDARD: anything unrecognised is reported and falls back to the slot's
# default part rather than silently vanishing.
#
# ENHANCED (payload v == 'E') IS TWO SHELLS. The Standard shell is built
# exactly as it always was, and a second IEP shell goes inside it: every slot is
# translated twice, once to its Standard part for the outer slot and once to its
# ENH part for the inner slot the layout calls '<slot>i'. An Enhanced booth is
# not a Standard booth with different walls - base-bom.json ships both sets.
#
# On that path the unassigned-slot fallback is WORSE than vanishing, because the
# default is composed by build-booth-components' guess_component; hand an inner
# slot a Standard name and the booth builds, renders, and is the wrong product.
# So every ENH part is checked against the real folder BEFORE anything is built,
# every missing file is named, and the build refuses (see ENH_MISSING_ABORTS).

require 'sketchup.rb'
require 'json'

# The folder field is a dropdown of folders used before, plus a Browse entry.
load File.join(File.dirname(__FILE__), 'wr-folder.rb')

module WR_BoothLink
  PREF = 'WR_BoothLink'.freeze
  BUILDER = File.join(File.dirname(__FILE__), 'build-booth-components.rb')

  # What to do when an ENHANCED booth needs a part the library does not have.
  #
  # true  — refuse the build and name every missing file. Chosen because the
  #         failure this tool exists to remove is a wrong booth that LOOKS
  #         right. Leaving a slot unassigned is not neutral: downstream,
  #         build-booth-components fills an unassigned slot with
  #         guess_component, which composes STANDARD names — so "leave it out"
  #         on the Enhanced path becomes "put a Standard part there" one
  #         function later. Refusing is also the precedent the chain already
  #         sets for "we cannot build this": build_booth itself messageboxes
  #         and returns on a layout key it does not have.
  # false — build anyway, still naming every missing file, and still never
  #         emitting a Standard name in place of an Enhanced one. Flip this if
  #         a partial Enhanced booth is wanted to look at.
  ENH_MISSING_ABORTS = true

  # ------------------------------------------------------------------- input --

  def self.read_pref(k, fallback = '')
    v = Sketchup.read_default(PREF, k, fallback).to_s
    v.empty? ? fallback : v
  rescue Exception
    fallback
  end

  def self.write_pref(k, v)
    Sketchup.write_default(PREF, k, v.to_s.delete('"'))
  rescue Exception
    nil
  end

  def self.ask
    # 'parts' is shared with build-booth-components.rb and probe-components.rb —
    # they all read the same component library, so a folder found once in any of
    # them is offered by all three.
    dir, list = WR_Folder.field('parts', 'P:/Sketchup/NewMasterComponentList')

    # THE THREE ARRAYS ARE POSITIONAL AND MUST STAY THE SAME LENGTH. UI.inputbox
    # matches them up by index and gives no warning when they disagree — it
    # silently reads the wrong field. The 'Floor and ceiling' row was removed
    # from all three together; res is now 0 link, 1 folder, 2 dry run.
    res = UI.inputbox(['Booth-builder link', 'Component folder',
                       'Dry run — report only'],
                      [read_pref('link'), dir, 'No'],
                      ['', list, 'Yes|No'],
                      'Build Booth from Link')
    return nil unless res
    link = res[0].to_s.strip
    if link.empty?
      UI.messagebox("Paste the link from the booth builder's " \
                    "\"Copy a link to this design\" button.")
      return nil
    end
    dir = WR_Folder.resolve(res[1], 'parts', 'Folder of component .skp files', false)
    return nil if dir.nil?
    write_pref('link', link)
    # The stored 'deck' preference is left in the registry unread and unwritten.
    # Nothing consults it now that the deck is unconditional, and migration code
    # for a preference nobody will see again is more risk than tidiness.
    { 'link' => link, 'dir' => dir, 'dry' => res[2] == 'Yes' }
  end

  # ------------------------------------------------------------------ decode --

  # Short link: ?d=<id>, resolved against the SAME host the link came from, so a
  # link from the test portal fetches from the test portal.
  def self.short_id(link)
    m = link.match(%r{\A(https?://[^/\s]+)[^#]*\?d=([A-Za-z0-9_-]+)}i)
    m ? [m[1], m[2]] : nil
  end

  # Legacy hash: #d=<base64url JSON>, self-contained.
  def self.hash_payload(link)
    m = link.match(/#d=([A-Za-z0-9_-]+)/)
    return nil unless m
    h = m[1].tr('-_', '+/')
    h += '=' * ((4 - h.length % 4) % 4)
    JSON.parse(h.unpack1('m'))
  rescue StandardError
    nil
  end

  # ----------------------------------------------------------- translation --
  #
  # Portal pack string -> component file base name. The option flags fold in
  # here: VSS/EFS/casters extend a vent's name, the height extension is applied
  # by the builder itself (it appends _HX to every wall part).
  #
  # ENHANCED. The portal emits STDWL<n> packs whatever the variant - the
  # variant travels only in payload['v'] - so Enhanced is a mapping problem
  # inside this one function, not a portal change. Every Enhanced wall part is
  # its Standard twin's width MINUS 4.5 in, and carries an 'ENH ' prefix WITH
  # THE SPACE (observed 2026-08-24, by listing the component folder).
  ENH_WIDTH = { '7' => '2.5', '16' => '11.5', '19' => '14.5', '22' => '17.5',
                '28' => '23.5', '31' => '26.5', '40' => '35.5', '43' => '38.5',
                '46' => '41.5' }.freeze

  # Widths whose plain wall part is 'Panel' rather than 'PanelSolid'. Keyed on
  # the STANDARD width and used for both variants, because the split survives
  # the -4.5 shift intact: ENH 14.5/23.5/26.5/38.5 are Panel and
  # ENH 11.5/17.5/35.5/41.5 are PanelSolid. Checked against the real filenames
  # rather than trusting the arithmetic.
  PANEL_WIDTHS = %w[7 19 28 31 43].freeze

  def self.enh_width(w)
    ENH_WIDTH[w.to_s]
  end

  def self.component_for(pack, o, enh = false)
    s = pack.to_s.strip
    p = enh ? 'ENH ' : ''
    case s
    when /\AWA\s+STDDRFRM\s+([RL])\b/i
      hand = Regexp.last_match(1).upcase == 'L' ? 'Left' : 'Right'
      # THE RAMP IS STANDARD-ONLY - Benton, 2026-08-24: "All of the ENH with WA
      # door with ramp can be ignored. Ramp only attached to standard. There's
      # not a separate one that uses it for enhanced." So ENH ...WADoorWithRamp
      # is not a missing file; it is a part that will never exist. The Enhanced
      # path ignores o[:ramp] and emits the plain ENH door. The ramp still
      # reaches the model on the Standard OUTER shell, which is where it belongs.
      o[:ramp] && !enh ? "#{hand}WADoorWithRamp" : "#{p}#{hand}WADoor"
    when /\ASTDWL(\d+)\s+DRFRM\s+([RL])\b/i
      hand = Regexp.last_match(2).upcase == 'L' ? 'Left' : 'Right'
      w = enh ? enh_width(Regexp.last_match(1)) : Regexp.last_match(1)
      w && "#{p}#{hand}#{w}Door"
    when /\ASTDWL(\d+)\s+WDO(\d{4})\b/i
      # The window opening code does NOT take the -4.5; only the panel width
      # does. ENH 26.5Panel1648WDO, ENH 35.5Panel2648WDO (observed).
      w = enh ? enh_width(Regexp.last_match(1)) : Regexp.last_match(1)
      w && "#{p}#{w}Panel#{Regexp.last_match(2)}WDO"
    when /\ASTDWL(\d+)\s+VNT\b/i
      w = enh ? enh_width(Regexp.last_match(1)) : Regexp.last_match(1)
      return nil if w.nil?
      n = "#{p}#{w}VNT"
      # ENHANCED TAKES NO VENT OPTION VARIANTS - Benton, 2026-08-24: "the 35.5
      # VNT wall fits them all for the inner walls." _VSS / _EFS / _CP are
      # strictly Standard. Appending them here would compose a filename that
      # will never exist, whatever gets authored later. The caller notices the
      # dropped flags and prints them, so this is stated, not silent.
      return n if enh
      n += '_VSS' if o[:vss]
      n += '_EFS' if o[:efs]
      n += '_CP'  if o[:casters]
      n
    when /\ASTDWL(\d+)\s+NV\b/i
      w = enh ? enh_width(Regexp.last_match(1)) : Regexp.last_match(1)
      w && "#{p}#{w}NV"
    when /\ASTDWL(\d+)\z/i
      std = Regexp.last_match(1)
      w = enh ? enh_width(std) : std
      w && "#{p}#{w}#{PANEL_WIDTHS.include?(std) ? 'Panel' : 'PanelSolid'}"
    end
  end

  # ------------------------------------------------------------ resolution --
  #
  # The library's real filenames are inconsistent about BOTH case and separator
  # inside a single family: 40VNT_VSS, 40Vnt_CP, 46vnt_VSS_CP and 46VntCP all
  # name the same kind of thing (observed, by listing the folder).
  # build-booth-components' load_def already forgives the case; it does not
  # forgive the missing underscore, so a 46 in vent with the caster package and
  # nothing else composes 46VNT_CP and finds nothing. That is a LIVE Standard
  # defect reachable from the portal today, not a theoretical one.
  #
  # Comparing names with case and separators removed covers every form in the
  # folder without hand-listing the exceptions. It is safe to do that here:
  # across all 353 .skp files the normalisation produces 353 distinct keys, so
  # no two different parts collapse onto each other (checked 2026-08-24).
  def self.norm_name(n)
    n.to_s.downcase.delete('_ ')
  end

  def self.library_index(dir)
    @lib ||= {}
    @lib[dir] ||= begin
      h = {}
      Dir.glob(File.join(dir.to_s, '*.skp')).each do |f|
        b = File.basename(f, '.skp')
        h[norm_name(b)] = b
      end
      h
    rescue StandardError
      {}
    end
  end

  # Returns [name to hand the builder, missing filename or nil].
  #
  # The _HX suffix is applied HERE rather than left to the builder, so what gets
  # checked against the disk is the exact file the builder will open. A resolved
  # name that already ends in _HX makes the builder's own append a no-op, so
  # this does not double up.
  def self.resolve_part(dir, base, hx)
    want = hx ? "#{base}_HX" : base
    idx = library_index(dir)
    return [want, nil] if idx.empty?   # unreadable folder: behave exactly as before
    hit = idx[norm_name(want)]
    hit ? [hit, nil] : [nil, "#{want}.skp"]
  end

  # ---------------------------------------------------------- cross-check --
  #
  # The portal's own words for each wall, from booth-layouts.json — identical on
  # all 25 catalogue layouts (checked, not assumed). Printing the build in the
  # SAME vocabulary the booth builder's "YOUR BOOTH" panel uses turns a
  # what-did-it-do question into a two-line text comparison, instead of two
  # people squinting at renders from different camera angles and disagreeing
  # about which wall is on the right.
  WALL_WORD = { 'N' => 'Back', 'S' => 'Front', 'E' => 'Right', 'W' => 'Left' }.freeze

  def self.summarise_placement(assign)
    kinds = { 'Door' => [], 'Window' => [], 'Ventilation' => [] }
    assign.sort.each do |slot, name|
      next if slot.end_with?('i')     # the inner shell mirrors the outer one
      k = if name =~ /Door/i then 'Door'
          elsif name =~ /WDO/i then 'Window'
          elsif name =~ /VNT/i then 'Ventilation'
          end
      next if k.nil?
      kinds[k] << "#{WALL_WORD[slot[0, 1]] || slot[0, 1]} (#{slot})"
    end
    puts ''
    puts "  COMPARE THESE AGAINST THE BUILDER'S \"YOUR BOOTH\" PANEL:"
    kinds.each do |k, v|
      puts format('    %-12s %s', k, v.empty? ? '(none)' : v.join(', '))
    end
  end

  def self.build_from_payload(payload, cfg)
    unless payload.is_a?(Hash) && payload['m'].is_a?(String)
      UI.messagebox("That link does not carry a booth design.\n\n" \
                    'It may be a website-form intent rather than a saved builder design.')
      return
    end

    variant = (payload['v'] || 'S').to_s.strip
    key  = "#{payload['m']} #{variant}"
    # THE VARIANT NOW REACHES THE PART NAMES. It used to reach only the layout
    # key on the line above; component_for never saw it, so every branch emitted
    # a Standard name and the RAW PACK printout below reported Standard parts
    # for an Enhanced design without a word of complaint. Nothing errored. That
    # silence was the defect.
    #
    # THAT BLOCKER IS GONE. wr-booth-data.rb now carries all 50 keys - 25 ' S'
    # and 25 ' E' - and an ' E' layout holds both shells, the Standard outer one
    # and the IEP inner one, every part tagged :sh. This file's job is to name
    # the parts for both.
    enh  = variant.upcase == 'E'
    opts = { :vss => payload['vs'].to_i == 1, :efs => payload['ef'].to_i == 1,
             :casters => payload['cs'].to_i == 1, :ramp => payload['rp'].to_i == 1 }
    hx = payload['hx'].to_i == 1

    assign = {}
    packs = {}
    odd = []
    gaps = []
    no_opts = []
    # AN ENHANCED BOOTH IS BOTH SHELLS, NOT A SWAPPED ONE.
    #
    # This used to translate an Enhanced design into ENH parts and hand them to
    # the OUTER slots, which builds a single shell of inner parts - a booth that
    # exists in no catalogue. base-bom.json settles it: 'MDL 4872 E' ships the
    # whole Standard wall set AND a full IEP set. So every slot is translated
    # TWICE on the Enhanced path: the Standard name for the outer slot, and the
    # ENH name for the matching inner slot, which the layout data calls
    # '<slot>i'.
    (payload['a'] || {}).each do |slot, pack|
      packs[slot] = pack.to_s
      variants = enh ? [[slot, false], ["#{slot}i", true]] : [[slot, false]]
      variants.each do |sid, want_enh|
        base = component_for(pack, opts, want_enh)
        if base.nil?
          odd << "#{sid}: #{pack.inspect}"
          next
        end
        no_opts << "#{sid}  #{base}" if want_enh && base.end_with?('VNT') &&
                                        (opts[:vss] || opts[:efs] || opts[:casters])
        name, gone = resolve_part(cfg['dir'], base, hx)
        if gone
          gaps << format('%-6s %-26s wanted  %s', sid, packs[slot], gone)
          # Standard keeps today's behaviour EXACTLY: hand the composed name
          # over and let the builder's own missing-parts report catch it. An
          # inner slot assigns nothing, so no Standard name can reach it.
          assign[sid] = base unless want_enh
        else
          assign[sid] = name
        end
      end
    end

    puts ''
    puts '=' * 74
    puts "BOOTH FROM LINK — #{key}#{hx ? '  + height extension' : ''}"
    puts "  options  #{opts.select { |_k, v| v }.keys.join(', ')}" unless opts.values.none?
    outer_n = assign.keys.count { |k| !k.end_with?('i') }
    inner_n = assign.length - outer_n
    puts "  slots    #{outer_n} outer" + (enh ? " + #{inner_n} inner (IEP) translated from the design" : ' translated from the design')
    assign.sort.each do |s, n|
      # The RAW pack is printed beside the translated name. Without it a
      # mistranslation is invisible: a wrong component name looks exactly like a
      # correctly translated slot, and the only way to tell them apart was to
      # go and decode the link by hand.
      puts format('    %-6s %-24s  <- %s', s, n, packs[s])
    end
    summarise_placement(assign)
    unless no_opts.empty?
      puts ''
      puts "  VSS/EFS/caster options NOT appended to #{no_opts.length} Enhanced vent(s) — by design."
      puts '  Enhanced has no vent option variants; the plain ENH vent fits them all.'
      no_opts.each { |x| puts "    #{x}" }
    end
    unless odd.empty?
      puts "  #{odd.length} pack(s) not translatable — those slots fall back to the layout default:"
      odd.each { |x| puts "    #{x}" }
      puts '    WARNING: on an ENHANCED booth the layout default is a STANDARD part.' if enh
    end
    unless gaps.empty?
      puts ''
      puts '!' * 74
      puts "  #{gaps.length} component file(s) DO NOT EXIST in #{cfg['dir']}:"
      gaps.each { |g| puts "    #{g}" }
      if enh
        puts ''
        puts '  THIS IS AN ENHANCED BOOTH. Nothing Standard has been put in their place.'
        puts '  Those files have to be authored before this booth can be built.'
      end
      puts '!' * 74
    end
    # ---- option parts for the overlay pass, and LOUD refusals ------------
    #
    # Rule (GOAL): no silent fallback. Every payload key is either handed to
    # the builder's overlay pass or refused BY NAME with the reason. The keys
    # that used to be dropped silently — f, ep, ad, dl/ds/dox, ms, ac, and the
    # caster-plate half of cs — are all accounted for below.
    overlay = {
      'foam_color'    => payload['f'].to_s,                 # report-only downstream
      'desk'          => payload['dk'].to_i == 1,
      'desk_large'    => payload['dl'].to_i == 1,
      'desk_slot'     => payload['ds'].to_s,
      'desk_outside'  => payload['dox'].to_i == 1,
      'mjp'           => payload['jp'].to_i == 1,
      'mjp_slot'      => payload['ms'].to_s,
      'efp'           => payload['ep'].to_i == 1 || payload['ad'].to_i == 1,
      'efp_from_ada'  => payload['ad'].to_i == 1,
      'casters_plate' => payload['cs'].to_i == 1,           # refused by name downstream
      'step'          => payload['sp'].to_i == 1            # refused by name downstream
    }
    built_opts = { 'desk' => 'desk', 'mjp' => 'MJP jack panel',
                   'efp' => 'elevated floor' }.select { |k, _| overlay[k] }.values
    puts "  option parts to build: #{built_opts.join(', ')}" unless built_opts.empty?
    refused = []
    refused << 'cs: caster PLATE + 5 in lift (vent _CP art only — plate not implemented)' if payload['cs'].to_i == 1
    refused << 'sp: step (pairs with the caster plate, which is not built)' if payload['sp'].to_i == 1
    refused << 'bt: bass traps (no .skp exists — Benton to author)' if payload['bt'].to_i == 1
    refused << 'ac: Audimute panels (no .skp exists — Benton to author)' if payload['ac'].to_i == 1
    refused << 'sl: studio light (no fixture .skp exists — Benton to author)' if payload['sl'].to_i == 1
    refused << 'rv: roof-mounted vent (out of scope per GOAL)' if payload['rv'].to_i == 1
    unless refused.empty?
      puts "  NOT built, by name and by reason (#{refused.length}):"
      refused.each { |x| puts "    #{x}" }
    end
    puts '=' * 74

    # THE REFUSAL. An Enhanced booth that is missing parts is not built at all.
    # See ENH_MISSING_ABORTS at the top of the module for why, and for how to
    # turn this into a build-anyway.
    if enh && ENH_MISSING_ABORTS && !(gaps.empty? && odd.empty?)
      lines = gaps + odd.map { |x| "untranslatable pack  #{x}" }
      UI.messagebox("This ENHANCED booth needs #{lines.length} component(s) that could not " \
                    "be resolved:\n\n" + lines.join("\n") +
                    "\n\nNOTHING WAS BUILT. Building without them would put Standard parts " \
                    "in an Enhanced booth, which is the failure this tool exists to stop.\n\n" \
                    'Full detail is in the Ruby Console. To build anyway, leaving those slots ' \
                    'empty, set ENH_MISSING_ABORTS = false in booth-from-link.rb.')
      puts '  ENHANCED BUILD REFUSED - see the list above. Nothing was placed.'
      return
    end

    $wr_no_autorun = true
    begin
      load BUILDER
    ensure
      $wr_no_autorun = false
    end
    # build_booth's third argument is a CONFIG HASH, not a positional parameter
    # list, so dropping 'deck' needs no signature change and no dead always-true
    # boolean threaded through it. The key is simply gone and the deck pass runs
    # unconditionally.
    WR_BuildBoothComponents.build_booth(key, assign,
                                        'dir' => cfg['dir'], 'hx' => hx,
                                        'dry' => cfg['dry'],
                                        'overlay' => overlay)
  end

  # -------------------------------------------------------------------- run --

  def self.run
    cfg = ask
    return if cfg.nil?

    inline = hash_payload(cfg['link'])
    return build_from_payload(inline, cfg) if inline

    origin_id = short_id(cfg['link'])
    if origin_id.nil?
      UI.messagebox("Could not find a design id in that link.\n\n" \
                    "Expected ...booth-builder?d=<id> or ...#d=<hash>.")
      return
    end

    url = "#{origin_id[0]}/api/booth-design/#{origin_id[1]}"
    puts "  fetching #{url}"
    Sketchup.status_text = 'Fetching booth design...'

    # The request object MUST be retained ( @req ) — SketchUp garbage-collects a
    # local one before the response arrives and the callback silently never runs.
    @req = Sketchup::Http::Request.new(url, Sketchup::Http::GET)
    @req.start do |_request, response|
      begin
        Sketchup.status_text = ''
        if response.status_code != 200
          UI.messagebox("The portal answered #{response.status_code} for\n#{url}\n\n" \
                        'An expired or mistyped link answers 404.')
        else
          data = JSON.parse(response.body.to_s)
          payload = data['payload']
          if payload.nil?
            UI.messagebox("The portal's answer carried no design payload:\n" \
                          "#{response.body.to_s[0, 200]}")
          else
            build_from_payload(payload, cfg)
          end
        end
      rescue Exception => e
        puts "FAILED handling the design: #{e.class}: #{e.message}"
        puts e.backtrace.first(8).map { |l| "  #{l}" }.join("\n")
        UI.messagebox("Failed handling the design:\n\n#{e.class}: #{e.message}")
      end
    end
  end
end

begin
  WR_BoothLink.run
rescue Exception => e
  puts ''
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(12).map { |l| "  #{l}" }.join("\n")
  UI.messagebox("Build from link failed:\n\n#{e.class}: #{e.message}\n\n" \
                'Full backtrace is in the Ruby Console.')
end
