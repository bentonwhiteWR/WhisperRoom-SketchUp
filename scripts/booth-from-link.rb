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
# What does NOT come through (yet): furniture and accessories — desk, MJP jack
# panel, step, bass traps, studio light — and the roof-mounted vent. Walls,
# doors, windows, vents and seals only. Anything unrecognised is reported and
# falls back to the slot's default part rather than silently vanishing.

require 'sketchup.rb'
require 'json'

# The folder field is a dropdown of folders used before, plus a Browse entry.
load File.join(File.dirname(__FILE__), 'wr-folder.rb')

module WR_BoothLink
  PREF = 'WR_BoothLink'.freeze
  BUILDER = File.join(File.dirname(__FILE__), 'build-booth-components.rb')

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
  def self.component_for(pack, o)
    s = pack.to_s.strip
    case s
    when /\AWA\s+STDDRFRM\s+([RL])\b/i
      hand = Regexp.last_match(1).upcase == 'L' ? 'Left' : 'Right'
      o[:ramp] ? "#{hand}WADoorWithRamp" : "#{hand}WADoor"
    when /\ASTDWL(\d+)\s+DRFRM\s+([RL])\b/i
      hand = Regexp.last_match(2).upcase == 'L' ? 'Left' : 'Right'
      "#{hand}#{Regexp.last_match(1)}Door"
    when /\ASTDWL(\d+)\s+WDO(\d{4})\b/i
      "#{Regexp.last_match(1)}Panel#{Regexp.last_match(2)}WDO"
    when /\ASTDWL(\d+)\s+VNT\b/i
      n = "#{Regexp.last_match(1)}VNT"
      n += '_VSS' if o[:vss]
      n += '_EFS' if o[:efs]
      n += '_CP'  if o[:casters]
      n
    when /\ASTDWL(\d+)\s+NV\b/i
      "#{Regexp.last_match(1)}NV"
    when /\ASTDWL(\d+)\z/i
      w = Regexp.last_match(1)
      %w[7 19 28 31 43].include?(w) ? "#{w}Panel" : "#{w}PanelSolid"
    end
  end

  def self.build_from_payload(payload, cfg)
    unless payload.is_a?(Hash) && payload['m'].is_a?(String)
      UI.messagebox("That link does not carry a booth design.\n\n" \
                    'It may be a website-form intent rather than a saved builder design.')
      return
    end

    key  = "#{payload['m']} #{(payload['v'] || 'S').to_s.strip}"
    opts = { :vss => payload['vs'].to_i == 1, :efs => payload['ef'].to_i == 1,
             :casters => payload['cs'].to_i == 1, :ramp => payload['rp'].to_i == 1 }
    hx = payload['hx'].to_i == 1

    assign = {}
    odd = []
    (payload['a'] || {}).each do |slot, pack|
      name = component_for(pack, opts)
      name.nil? ? odd << "#{slot}: #{pack.inspect}" : assign[slot] = name
    end

    puts ''
    puts '=' * 74
    puts "BOOTH FROM LINK — #{key}#{hx ? '  + height extension' : ''}"
    puts "  options  #{opts.select { |_k, v| v }.keys.join(', ')}" unless opts.values.none?
    puts "  slots    #{assign.length} translated from the design"
    assign.sort.each { |s, n| puts format('    %-6s %s', s, n) }
    unless odd.empty?
      puts "  #{odd.length} pack(s) not translatable — those slots fall back to the layout default:"
      odd.each { |x| puts "    #{x}" }
    end
    ignored = %w[dk sp jp bt sl rv].select { |k| payload[k].to_i == 1 }
    puts "  NOT built (out of scope for now): #{ignored.join(', ')}" unless ignored.empty?
    puts '=' * 74

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
                                        'dry' => cfg['dry'])
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
