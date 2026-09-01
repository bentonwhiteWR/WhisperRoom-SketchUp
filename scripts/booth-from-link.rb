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
# Accepts all three link forms the portal produces (v2.502.0 ships a third):
#
#   .../booth-builder#3=<short base64url>
#     The NEW structural encoding (portal v2.502.0, 2026-09-01): a byte
#     array, 15-39 characters where #d= ran 407-764. Decoded locally, no
#     network — see the "#3= structural decode" section below. Both hash
#     forms converge on the SAME payload hash, so everything downstream of
#     build_from_payload is untouched.
#
#   https://sales.whisperroom.com/booth-builder?d=e0d972ac9fec
#     A short id. The design lives server-side; this fetches
#     GET /api/booth-design/<id> (public, no auth) and reads the payload.
#
#   .../booth-builder#d=<long base64>
#     The older self-contained hash. STILL MINTED by the portal (the #3=
#     encoder sits behind a feature flag, and the server writes #d= into
#     HubSpot rep notes), still valid, and per the wire-format guide it
#     must never stop working. Decoded locally, no network.
#
# The host is NEVER part of the format — production is sales.whisperroom.com,
# staging is a Railway hostname. Every path here takes the origin from the
# link it was given and hard-codes nothing.
#
# The payload contract (from booth-builder.html's designPayload()):
#   m  'MDL 7272'   v 'S'|'E'    hx/vs/ef/cs/rp  0|1   a { slotId => pack }
#   packs: 'STDWL46' | 'STDWL46 VNT' | 'STDWL46 CBL' | 'STDWL46 DRFRM R'
#          | 'STDWL46 WDO3236' | 'WA STDDRFRM L' | 'STDWL40 NV'
#
# A ' CBL' pack is a CABLE WALL, and it reaches us two ways that must not be
# confused. A customer can specify a cable wall on any booth. Separately, a
# ROOF-MOUNTED booth (rv = 1) carries every one of its vent walls as a cable
# wall, because booth-builder.html's applyRoofVent() does that swap — "the same
# swap the production RM BOM does", its own words — BEFORE the link is
# serialised. So the substitution is already done by the time the payload
# reaches us: never redo it here, and never infer roof-mounted ventilation from
# the presence of CBL packs. rv is the only thing that says roof-mounted.
#
# Beyond the walls, the OPTION PARTS now come through too: desk (dk/dl/ds/dox),
# MJP jack panel (jp/ms), the elevated floor (ep, or the ad ADA bundle's
# floor), and the CASTER PLATE (cs — the CP plate set under the booth, plus
# the 4.75 in booth lift; the vent-art _CP suffix is applied here as before)
# all ride into the builder's overlay pass (wr-overlays.rb), which also
# places the foam sheets and duct covers every booth ships with. Foam colour
# (f) is read and REPORTED — Foam.skp has no colour variants to apply.
#
# What still does NOT build, each named LOUDLY below rather than dropped:
# the step (sp — StepFront.skp exists but its placement is not sourced end to
# end; see wr-overlays.rb's header), bass traps (bt) and the Audimute package
# (ac) — no .skp exists for either — the studio light (sl, no fixture .skp),
# and the ROOF UNIT of a roof-mounted booth (rv — the part exists on the share
# and has now been measured, but its seating is not confirmed; wr-roof-vent.rb
# names the part, the ceiling it needs, and every blocker, per booth).
#
# ROOF-MOUNTED VENTILATION, precisely. On an rv = 1 booth the WALLS are built
# correctly and completely: the former vent walls are cable walls, which is what
# such a booth actually ships with. What is missing is the roof assembly and
# nothing else. That distinction used to be lost — the console said only "out of
# scope", while the untranslated CBL packs silently fell back to VENT walls, so
# a wrong booth wore the costume of a known limitation. RM_HALF_APPLY_ABORTS
# below is the fence that keeps the two halves from parting company again.
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

# What a roof-mounted booth's roof unit is, how much ceiling it needs, and every
# reason it is not seated yet. Read its header before changing anything rv.
load File.join(File.dirname(__FILE__), 'wr-roof-vent.rb')

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

  # What to do when a ROOF-MOUNTED booth's vent-wall swap arrives half applied.
  #
  # Roof-mounted ventilation is one change made in two places: the ducts move to
  # a roof unit, and every vent wall becomes a cable wall. Either half without
  # the other is a booth that does not exist:
  #
  #   cable walls, no roof unit   -> a booth with NO ventilation at all
  #   roof unit, vent walls kept  -> ventilation twice over
  #
  # Both render as a perfectly plausible booth, which is why this is a refusal
  # and not a warning. The check is on the payload, where the evidence is: on an
  # rv = 1 booth EVERY layout slot the model ventilates must carry a CBL pack.
  # The count of those slots is the model's vent-set count — cross-checked for
  # all 50 layout keys against the catalogue's own `vents` figure in
  # whisperroom-catalog/data/models.json, which agreed on every one (observed,
  # 2026-08-31), and it is the same number the portal calls layout.ventSets and
  # holds to the invariant (VNT + CBL) === ventSets.
  #
  # true  — refuse the build and name every slot that disagrees.
  # false — build anyway, still naming them. Flip this only to look at a booth
  #         you already know is half-swapped.
  RM_HALF_APPLY_ABORTS = true

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

  # Older hash: #d=<base64url JSON>, self-contained. Still minted by the
  # portal, still valid, must keep decoding forever (wire-format guide,
  # Rule 3.2). NOTHING in the #3= work below may change this method's
  # behaviour — a regression here is worse than not reading #3= at all.
  def self.hash_payload(link)
    m = link.match(/#d=([A-Za-z0-9_-]+)/)
    return nil unless m
    h = m[1].tr('-_', '+/')
    h += '=' * ((4 - h.length % 4) % 4)
    JSON.parse(h.unpack1('m'))
  rescue StandardError
    nil
  end

  # ---------------------------------------------------- #3= structural decode --
  #
  # The short booth-design link the portal ships in v2.502.0 (2026-09-01).
  # Source of truth: the wire-format guide ("The #3= booth-design link"),
  # itself read out of booth-builder.html's codec and pinned by the portal's
  # own 135-check test suite. The layout on the wire:
  #
  #   byte 0     format version — always 1; anything else is REFUSED
  #   byte 1     model index into V3_MODELS (frozen, append-only)
  #   byte 2     variant bit0 | hinge bit1 | facing bits2-3 | foam bits4-6
  #              (bit 7 unused; written 0, not validated on read — guide §6.4)
  #   bytes 3-6  32-bit flag word, LITTLE-ENDIAN; bit index = V3_FLAGS index
  #   then, ONLY when the flag bit says so, in exactly this order:
  #     1 byte   desk slot   (bit 22, 1-based ordinal into the slot order)
  #     1 byte   MJP slot    (bit 23, same)
  #     1 byte   package     (bit 24, 0-based into V3_PACKAGES)
  #     5 bytes  room        (bit 20; ft/ft/ft, then packed inch nibbles)
  #     N bytes  wall map    (bit 21; one byte per slot, N-S-E-W order,
  #                           255 = "not specified, use the slot default")
  #   Any shortfall or trailing byte is a hard error — a truncated link never
  #   half-restores. Flag bits 28-31 are reserved, must be zero, and are
  #   REFUSED when set, not masked off (guide §2.4).
  #
  # THE TABLES BELOW ARE WIRE FORMAT (guide, Rule 3.1). Append-only, forever:
  # never reorder, never delete, never repurpose an index. Index 16 of the
  # model table is MDL 96120 for all time. When a link carries an index these
  # tables do not have, the answer is a refusal that names it — the link is
  # newer than the plugin — never a clamp and never a guess at a neighbour.
  #
  # Every refusal raises V3Refusal with the reason BY NAME. This decoder
  # never half-decodes: the caller gets a complete payload or a refusal,
  # because a wrong number reaching a drawing is the worst outcome this
  # repo knows.
  #
  # KNOWN OPEN POINTS, stated rather than papered over:
  #   - Companion code 9 (the 7" WA companion) reconstructs to the guide's
  #     own SKU column verbatim, 'STDWL7 / WL16' — one slot, two physical
  #     panels. component_for has no branch for that string, so downstream
  #     reports it untranslatable and the slot falls to its layout default,
  #     LOUDLY. What single string the portal's #d= payload carries for that
  #     slot is not stated in the guide; until it is, loud beats invented.
  #   - The guide's own fully-loaded example ships wd = 1 (wide-access door)
  #     with a plain DRFRM byte in the door slot; v3_report warns when that
  #     combination arrives, because the build follows the pack strings.
  #   - The decode is deliberately FAITHFUL, not normalised: the portal's
  #     applyDesign() contradiction rules (nv forces vs/ef/rv off, ADA only
  #     restores whole, dl forces dox off, vent-set BOM re-seating — guide
  #     §4.1) are applied by NEITHER hash path here, so both forms of the
  #     same link build the same booth. Adding a normaliser is a decision to
  #     make for both paths together, not a #3= side effect.

  class V3Refusal < StandardError; end

  # Model index -> [name, module]. The module is the model's wall series
  # (40- or 46-inch nominal panels); it is not in the link, it decides the
  # window width in v3_sku (26 on the 40-series, 32 on the 46-series).
  V3_MODELS = [
    ['MDL 4230', 40],   ['MDL 4242', 40],   ['MDL 4260', 40],
    ['MDL 4284', 40],   ['MDL 4848', 46],   ['MDL 4872', 46],
    ['MDL 4896', 46],   ['MDL 6060', 40],   ['MDL 6084', 40],
    ['MDL 7272', 46],   ['MDL 7296', 46],   ['MDL 8484', 40],
    ['MDL 9696', 46],   ['MDL 10284', 40],  ['MDL 84102', 40],
    ['MDL 84126', 40],  ['MDL 96120', 46],  ['MDL 96144', 46],
    ['MDL 96168', 46],  ['MDL 96192', 46],  ['MDL 102102', 40],
    ['MDL 102126', 40], ['MDL 102144', 40], ['MDL 102168', 40],
    ['MDL 102186', 40]
  ].freeze

  V3_FOAM   = %w[Gray Orange Blue Purple Burgundy].freeze
  V3_FACING = %w[N S E W].freeze
  V3_CORNER = %w[NW NE SW SE].freeze

  # Flag-word bits 0-19, in bit order. These are literally the #d= payload's
  # own key names, which is what lets one build_from_payload serve both forms.
  V3_FLAGS = %w[wd rp hx cs vs ef rv sl jp bt dk sp nv ac ad ep dl hp
                dox re].freeze

  V3_PACKAGES = ['Voice Over Basic', 'Voice Over Deluxe', 'Audiology Basic',
                 'Audiology Deluxe', 'Office Booth', 'Work From Home Booth',
                 'Drum Booth', 'Audiology Basic Plus', 'Audiology Compact',
                 'Audiology Ultra', 'Audiology Premium', 'Creator Basic',
                 'Creator Deluxe', 'Practice Basic', 'Practice Deluxe',
                 'Recording Studio', 'Drum Studio', 'Meeting Booth',
                 'Maker Space'].freeze

  # New short hash: #3=<base64url>. Returns the raw hash text (validated in
  # v3_bytes, so a malformed one is refused by name, not treated as "no link").
  def self.v3_hash(link)
    m = link.to_s.match(/#3=(\S+)/)
    m && m[1]
  end

  # base64url, UNPADDED: the standard alphabet with + -> - and / -> _, all
  # '=' stripped. The guide is explicit that anything outside [A-Za-z0-9_-]
  # is rejected, so the alphabet is checked FIRST — unpack('m') would
  # silently skip characters it does not like, and a skipped character
  # shifts every byte after it. Decoded by hand rather than through
  # String#unpack so the whole thing runs under rbtest's minimal VM, which
  # has no unpack; forty characters of shifting costs nothing.
  V3_B64 = (('A'..'Z').to_a + ('a'..'z').to_a + ('0'..'9').to_a +
            %w[- _]).each_with_index.to_h.freeze

  def self.v3_bytes(hash)
    bad = hash.scan(/[^A-Za-z0-9_-]/).uniq
    unless bad.empty?
      raise V3Refusal, "the payload contains #{bad.map(&:inspect).join(', ')} " \
                       '— not base64url ([A-Za-z0-9_-] only). The link is ' \
                       'mangled, most likely by an email client or a copy-paste.'
    end
    if hash.length % 4 == 1
      raise V3Refusal, "a base64url payload can never be #{hash.length} " \
                       'characters long (length % 4 == 1) — the link lost ' \
                       'characters in transit.'
    end
    acc = 0
    nbits = 0
    bytes = []
    hash.each_char do |c|
      acc = (acc << 6) | V3_B64[c]
      nbits += 6
      next if nbits < 8
      nbits -= 8
      bytes << ((acc >> nbits) & 0xFF)
    end
    bytes
  end

  # The model's outer wall slots, [id, drawn width] in the canonical N-S-E-W
  # order the wall-map bytes line up against. Derived from wr-booth-data.rb —
  # the same digitised layouts the builder itself reads — rather than
  # hard-coded, per the guide's own instruction ("derive it from the layout
  # data, which is allowed to diverge later"). Within a wall the slots sort
  # by their number: the guide's canonical table is ascending on every one
  # of the 25 models, and wr-booth-data's LISTING order is not to be trusted
  # for this — MDL 6060/6084 list E1 before E0 (a gen-booth artifact), and
  # taking that order as canonical would swap two wall-map bytes silently.
  # rbtest-boothlink-v3.py pins the derived order against the guide's table
  # for all 25 models, both variants. Inner (IEP) slots are excluded; the
  # link describes the outer shell and build_from_payload mirrors it inward.
  # Returns nil — not [] — when the layout cannot be read, so "no slots" and
  # "could not tell" stay distinguishable.
  def self.v3_slots(key)
    return nil unless File.exist?(DATA)
    load DATA
    spec = WR_BOOTH_DATA::BOOTHS[key]
    return nil if spec.nil?
    panels = (spec[:parts] || []).select { |p| p[:k] == 'panel' && p[:sh] != 'in' }
    %w[N S E W].flat_map do |wall|
      panels.select { |p| p[:id].to_s.start_with?(wall) }
            .sort_by { |p| p[:id].to_s[1..-1].to_i }
            .map do |p|
        xs = p[:poly].map { |q| q[0] }
        ys = p[:poly].map { |q| q[1] }
        [p[:id].to_s, [xs.max - xs.min, ys.max - ys.min].max]
      end
    end
  rescue StandardError
    nil
  end

  # The guide's width snap: the slot's drawn width, snapped to the nearest of
  # [16, 22, 28, module]. 43 is deliberately NOT in the set — it exists only
  # as a wide-access companion, and including it made the 84-series' 42/44 in
  # nominal slots snap to a phantom wall (guide §2.10).
  def self.v3_snap(width, mod)
    [16, 22, 28, mod].min_by { |w| (w - width).abs }
  end

  # Slot-vocabulary code -> the exact SKU string the #d= payload would carry,
  # so the two hash forms hand build_from_payload identical packs. Codes 0-8
  # take the snapped slot width; the window numeric is <width><height> with
  # the width fixed by the module. Codes 9-15 are fixed strings — their
  # widths come from the wide-access-door geometry, not from the slot.
  # Returns nil for a code outside the frozen 16-entry vocabulary.
  def self.v3_sku(code, snapped, mod, hinge)
    wdo = mod == 40 ? 26 : 32
    case code
    when 0  then "STDWL#{snapped}"
    when 1  then "STDWL#{snapped} VNT"
    when 2  then "STDWL#{snapped} CBL"
    when 3  then "STDWL#{snapped} DRFRM #{hinge}"
    when 4  then "WA STDDRFRM #{hinge}"
    when 5  then "STDWL#{snapped} WDO#{wdo}30"
    when 6  then "STDWL#{snapped} WDO#{wdo}36"
    when 7  then "STDWL#{snapped} WDO#{wdo}42"
    when 8  then "STDWL#{snapped} WDO#{wdo}48"
    when 9  then 'STDWL7 / WL16'   # the guide's own SKU column, verbatim; see
                                   # the header note on companion code 9
    when 10 then 'STDWL19'
    when 11 then 'STDWL31'
    when 12 then 'STDWL43'
    when 13 then 'STDWL43 WDO2636'
    when 14 then 'STDWL43 WDO2648'
    when 15 then 'STDWL31 WDO1648'
    end
  end

  # #3= hash text -> the SAME payload hash shape hash_payload returns, so
  # build_from_payload and everything below it need no change. Raises
  # V3Refusal, with the reason named, on anything malformed — never returns
  # a partial payload.
  def self.v3_payload(hash)
    b = v3_bytes(hash)
    if b.length < 7
      raise V3Refusal, "the payload is #{b.length} byte(s); even a booth with " \
                       'nothing optional is 7 (format, model, enums, flag word). ' \
                       'The link is truncated.'
    end
    unless b[0] == 1
      raise V3Refusal, "unknown format version #{b[0]} — this plugin reads " \
                       'only version 1. The link is newer than the plugin; ' \
                       'update the plugin rather than trusting a partial read.'
    end
    model, mod = V3_MODELS[b[1]]
    if model.nil?
      raise V3Refusal, "unknown model index #{b[1]} — this plugin knows " \
                       "0..#{V3_MODELS.length - 1}. The link is newer than " \
                       'the plugin. Refusing rather than guessing a nearby ' \
                       'model (wire-format guide, Rule 3.1).'
    end

    enums   = b[2]
    variant = (enums & 1) == 1 ? 'E' : 'S'
    hinge   = ((enums >> 1) & 1) == 1 ? 'L' : 'R'
    facing  = V3_FACING[(enums >> 2) & 3]
    foam_ix = (enums >> 4) & 7
    foam    = V3_FOAM[foam_ix]
    if foam.nil?
      raise V3Refusal, "unknown foam colour index #{foam_ix} — this plugin " \
                       "knows 0..#{V3_FOAM.length - 1}. The link is newer " \
                       'than the plugin.'
    end

    flags = b[3] | (b[4] << 8) | (b[5] << 16) | (b[6] << 24)
    if (flags & 0xF0000000) != 0
      raise V3Refusal, 'reserved flag bits 28-31 are set. Those bits belong ' \
                       'to a future format; the guide is explicit that they ' \
                       'are refused, not masked off (§2.4).'
    end
    corner_ix = (flags >> 25) & 7
    corner = corner_ix.zero? ? nil : V3_CORNER[corner_ix - 1]
    if corner.nil? && !corner_ix.zero?
      raise V3Refusal, "unknown room-corner value #{corner_ix} — this plugin " \
                       "knows 1..#{V3_CORNER.length} (and 0 for none)."
    end

    key = "#{model} #{variant}"
    slots = v3_slots(key)
    if slots.nil? || slots.empty?
      raise V3Refusal, "the layout for #{key} could not be read from " \
                       'wr-booth-data.rb, so the wall map cannot be sized or ' \
                       'named. Nothing decoded.'
    end

    # The buffer length is fully determined by the flag word plus the slot
    # count. Anything else is a truncated or padded link, refused whole.
    need = 7
    need += 1 if flags[22] == 1                 # desk slot
    need += 1 if flags[23] == 1                 # MJP slot
    need += 1 if flags[24] == 1                 # package
    need += 5 if flags[20] == 1                 # room block
    need += slots.length if flags[21] == 1      # wall map
    unless b.length == need
      how = b.length < need ? 'truncated' : 'carrying trailing bytes'
      raise V3Refusal, "the payload is #{b.length} byte(s) but the flag word " \
                       "says it must be exactly #{need} for #{key} " \
                       "(#{slots.length} wall slots). The link is #{how}; " \
                       'refusing rather than half-restoring.'
    end

    payload = { 'ver' => 2, 'm' => model, 'v' => variant, 'h' => hinge,
                'f' => foam, 'fc' => facing }
    V3_FLAGS.each_with_index { |k, i| payload[k] = flags[i] }

    pos = 7
    # Desk and MJP slot bytes are 1-based ordinals into the canonical slot
    # order; the #d= payload carries slot ID STRINGS, so translate here.
    if flags[22] == 1
      n = b[pos]
      pos += 1
      unless n >= 1 && n <= slots.length
        raise V3Refusal, "desk-slot ordinal #{n} is outside 1..#{slots.length} " \
                         "for #{key}."
      end
      payload['ds'] = slots[n - 1][0]
    end
    if flags[23] == 1
      n = b[pos]
      pos += 1
      unless n >= 1 && n <= slots.length
        raise V3Refusal, "MJP-slot ordinal #{n} is outside 1..#{slots.length} " \
                         "for #{key}."
      end
      payload['ms'] = slots[n - 1][0]
    end
    if flags[24] == 1
      n = b[pos]
      pos += 1
      pk = V3_PACKAGES[n]
      if pk.nil?
        raise V3Refusal, "unknown package index #{n} — this plugin knows " \
                         "0..#{V3_PACKAGES.length - 1}. The link is newer " \
                         'than the plugin.'
      end
      payload['pk'] = pk
    end
    if flags[20] == 1
      wf, lf, cf, wl_in, c_in = b[pos, 5]
      pos += 5
      payload['rm'] = {
        'wFt' => wf == 255 ? '' : wf.to_s,
        'wIn' => (wl_in >> 4) == 15 ? '' : (wl_in >> 4).to_s,
        'lFt' => lf == 255 ? '' : lf.to_s,
        'lIn' => (wl_in & 15) == 15 ? '' : (wl_in & 15).to_s,
        'cFt' => cf == 255 ? '' : cf.to_s,
        'cIn' => (c_in >> 4) == 15 ? '' : (c_in >> 4).to_s
      }
    end
    payload['rc'] = corner if corner
    if flags[21] == 1
      a = {}
      slots.each_with_index do |(sid, width), i|
        v = b[pos + i]
        next if v == 255                # not specified: the slot default rules
        sku = v3_sku(v, v3_snap(width, mod), mod, hinge)
        if sku.nil?
          raise V3Refusal, "wall-map byte #{v} at slot #{sid} is not in the " \
                           '16-entry slot vocabulary — the link is newer ' \
                           'than the plugin.'
        end
        a[sid] = sku
      end
      payload['a'] = a
    end
    payload
  end

  # Provenance for the console before the build prints its own report: what
  # the short link decoded to, plus the two things a #3= link can say that
  # the build itself will not surface.
  def self.v3_report(payload)
    puts "  decoded #3= structural link -> #{payload['m']} #{payload['v']}, " \
         "door #{payload['h']}, foam #{payload['f']}" \
         "#{payload['pk'] ? ", package \"#{payload['pk']}\"" : ''}"
    rm = payload['rm']
    if rm
      dim = lambda do |ft, inch|
        ft.empty? && inch.empty? ? '?' : "#{ft.empty? ? '0' : ft}'" +
          (inch.empty? ? '' : "-#{inch}\"")
      end
      puts "  room in the link: #{dim.call(rm['wFt'], rm['wIn'])} x " \
           "#{dim.call(rm['lFt'], rm['lIn'])} x #{dim.call(rm['cFt'], rm['cIn'])} " \
           "ceiling#{payload['rc'] ? ", booth in the #{payload['rc']} corner" : ''}" \
           ' (reported only; the builder does not draw the room)'
      if payload['re'].to_i == 1
        puts '  ROOM IS AN EXAMPLE (re flag): the portal seeded it so the page had'
        puts '  something to show. It is NOT the customer\'s measurement — do not'
        puts '  let it reach a drawing as one.'
      end
    end
    # The wd option flag travels separately from the wall map, and the
    # portal's own examples ship wd = 1 with a plain DRFRM byte in the door
    # slot (the WA-ness is applied by its restore step). Downstream here
    # builds from the pack strings alone, so say it loudly when the two
    # disagree rather than letting a standard door stand in silently.
    if payload['wd'].to_i == 1 && !(payload['a'] || {}).values.any? { |s| s.start_with?('WA ') }
      puts '  WIDE-ACCESS DOOR flag (wd) is set, but no wall-map slot carries the'
      puts '  WA pack — the wall map says a standard door frame. The build follows'
      puts '  the wall map, so the WIDE door is NOT what will stand in the model.'
      puts '  Check the portal page for this link before trusting the door.'
    end
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
    when /\ASTDWL(\d+)\s+CBL\b/i
      # CABLE WALL. Named '<w>PanelCBL' / 'ENH <w>PanelCBL' — not '<w>CBL' —
      # and the library carries exactly the four, each with an _HX twin:
      # 40PanelCBL, 46PanelCBL, ENH 35.5PanelCBL, ENH 41.5PanelCBL (observed
      # 2026-08-31 by listing P:/Sketchup/NewMasterComponentList). Those are the
      # widths that can be vent walls, which is the same set, because a cable
      # wall is what a vent wall becomes under roof-mounted ventilation.
      #
      # NO OPTION SUFFIXES, deliberately. _VSS / _EFS / _CP name silencer and
      # caster hardware that lives on a VENT wall; a cable wall has none of it,
      # and no such file exists. On a roof-mounted booth the EFS is on the roof
      # (the portal suppresses the wall-side EFS outright), so appending it here
      # would compose both a filename that cannot exist and a wrong product.
      w = enh ? enh_width(Regexp.last_match(1)) : Regexp.last_match(1)
      w && "#{p}#{w}PanelCBL"
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

  # ------------------------------------------------- roof-mount half-apply --
  #
  # The layout data is the same file build_booth reads, and it is loaded fresh
  # here for the same reason build_booth reloads it: rebalance_walls edits the
  # loaded polygons in place. Only :id and :sk are read, so this cannot disturb
  # a later build.
  DATA = File.join(File.dirname(__FILE__), 'wr-booth-data.rb')

  # The OUTER-shell slot ids this model ventilates. Inner (IEP) slots mirror
  # them and are excluded so nothing is counted twice on an Enhanced booth.
  # Returns nil - not [] - when the layout cannot be read, so "no vent slots"
  # and "could not tell" stay distinguishable.
  def self.vent_slot_ids(key)
    return nil unless File.exist?(DATA)
    load DATA
    spec = WR_BOOTH_DATA::BOOTHS[key]
    return nil if spec.nil?
    (spec[:parts] || []).select { |p| p[:k] == 'panel' && p[:sk] == 'VNT' && p[:sh] != 'in' }
                        .map { |p| p[:id].to_s }
  rescue StandardError
    nil
  end

  # Named without Ruby's predicate '?' on purpose: scripts/rbtest.py's
  # method_source lifts a method by matching `def self.<name>\b`, and a name
  # ending in '?' leaves no word boundary there. A test that cannot lift the
  # real method has to copy it, and a copy drifts — which is the whole reason
  # this defect was traced from source rather than run. See
  # scripts/rbtest-boothlink-cbl.py.
  def self.cbl_pack(pack)
    pack.to_s =~ /\sCBL\b/i ? true : false
  end

  # Returns [] when the roof-mount swap is whole (or the booth is not roof
  # mounted), and a list of named complaints otherwise. Nothing here infers roof
  # mounting from the packs: `roof` comes from rv and rv alone, because a cable
  # wall is a legitimate product on a booth with ordinary wall ventilation.
  def self.roof_vent_complaints(roof, key, packs)
    return [] unless roof
    slots = vent_slot_ids(key)
    if slots.nil?
      return ["the layout for #{key} could not be read, so the roof-mount " \
              'vent-wall swap could not be checked at all']
    end
    if slots.empty?
      return ["#{key} has no vent walls in its layout, so rv = 1 (roof-mounted " \
              'ventilation) cannot be what this booth is']
    end
    bad = slots.reject { |sid| cbl_pack(packs[sid]) }
    return [] if bad.empty?
    got = slots.length - bad.length
    ["#{got} of #{slots.length} vent slot(s) carry a cable-wall (CBL) pack; a " \
     'roof-mounted booth must carry one on every single one'] +
      bad.map do |sid|
        pk = packs[sid].to_s
        "  #{sid}: #{pk.empty? ? '(no pack in the link at all)' : pk.inspect} " \
        '— expected a CBL pack here'
      end
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
    kinds = { 'Door' => [], 'Window' => [], 'Ventilation' => [], 'Cable wall' => [] }
    assign.sort.each do |slot, name|
      next if slot.end_with?('i')     # the inner shell mirrors the outer one
      # CBL is tested before VNT for the same reason wr-overlays' kind_of does
      # it: a cable wall is not a vent wall, and on a roof-mounted booth every
      # wall in this row is a cable wall. Listing them is how a reader sees at a
      # glance whether the roof-mount swap arrived whole.
      k = if name =~ /Door/i then 'Door'
          elsif name =~ /WDO/i then 'Window'
          elsif name =~ /CBL/i then 'Cable wall'
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
    # ---- roof-mounted ventilation: say exactly what was and was not built ----
    roof = payload['rv'].to_i == 1
    # Every reason the roof unit cannot be seated on THIS booth. Computed ONCE,
    # here, because three things downstream have to agree about it: the console
    # block, the "NOT built" list, and whether the overlay pass is asked to
    # place the part at all. They disagreed once and the tool announced it was
    # building a part it had just refused.
    rm_block = roof ? WR_RoofVent.roof_unit_blockers(key, variant, hx, opts[:efs],
                                                     opts[:vss] ? true : false) : []
    rm_bad = roof_vent_complaints(roof, key, packs) +
             WR_RoofVent.impossible_roof_link(key, roof)
    # THE HEIGHT A ROOM MUST GIVE. Printed on every booth, because it is the
    # constraint that disqualifies a booth faster than floor area does
    # (CLAUDE.md) and this tool never used to say it at all. On a roof-mounted
    # booth the roof unit is ADDED — the portal's fit card does not add it, and
    # under-reports an RM booth's ceiling by 10 to 16.5 in as a result.
    ch = WR_RoofVent.ceiling_required(key, variant, hx, roof,
                                      opts[:vss] ? true : false)
    puts ''
    if ch[:unit] > 0
      puts format('  CEILING THE ROOM MUST GIVE: %s (%.2f in) — %.2f booth install ' \
                  'clearance', WR_RoofVent.ft(ch[:total]), ch[:total], ch[:booth])
      puts format('    + %.2f in of roof unit (%s).', ch[:unit], ch[:why])
      puts '    The booth builder portal does NOT add the roof unit to its fit card,'
      puts '    so its figure for this booth is low by that amount.'
    else
      puts format('  CEILING THE ROOM MUST GIVE: %s (%.2f in) install clearance.',
                  WR_RoofVent.ft(ch[:total]), ch[:total])
    end
    if roof
      puts ''
      puts '  ROOF-MOUNTED VENTILATION (rv = 1)'
      puts '    WALLS: BUILT, and built correctly. This booth\'s vent walls are'
      puts '           CABLE walls — the ducts move to the roof — and that is what'
      puts '           is standing in the model. They are listed under "Cable wall"'
      puts '           above. No vent hardware, no duct covers, no EFS on the walls.'
      rm_part = WR_RoofVent.part_name(key, opts[:vss] ? true : false)
      if rm_block.empty?
        # This is the PLAN, printed before build_booth runs. The overlay pass
        # prints what actually landed, including a refusal if the .skp is not
        # on the share — so read the two together rather than this alone.
        puts '    ROOF UNIT: TO BE SEATED. ' +
             "#{rm_part}.skp goes on the roof — the whole"
        puts '           assembly, both boxes and every duct, as one part. Its plan'
        puts '           position and the measured roof it sits on are printed by the'
        puts '           overlay pass below; the rule it is seated by is:'
        WR_RoofVent.seating_note(key, opts[:vss] ? true : false,
                                 opts[:efs] ? true : false).each do |l|
          puts "             #{l}"
        end
      else
        puts '    ROOF UNIT: NOT BUILT. The part is ' +
             (rm_part ? "#{rm_part}.skp on the parts share" : 'not on the share at all') +
             '.'
        rm_block.each { |b| puts "           - #{b}" }
        puts '    So: a COMPLETE set of walls for a roof-mounted booth, MISSING the'
        puts '    roof assembly. Not a booth that was merely "skipped" — and not a'
        puts '    finished booth either. Do not send this drawing out as complete.'
      end
    elsif packs.any? { |_s, pk| cbl_pack(pk) }
      # Not an error: a cable wall is a product in its own right. Said out loud
      # so nobody reads CBL walls as evidence of roof-mounted ventilation, in
      # either direction.
      puts ''
      puts '  This booth has CABLE wall(s) and rv = 0 — the link does not claim'
      puts '  roof-mounted ventilation. Built as specified; a cable wall is a'
      puts '  product on its own. Nothing was inferred about the roof.'
    end
    unless rm_bad.empty?
      puts ''
      puts '!' * 74
      puts '  THIS ROOF-MOUNTED LINK DOES NOT DESCRIBE A BOOTH THAT CAN EXIST:'
      rm_bad.each { |x| puts "    #{x}" }
      puts '  A roof-mounted booth turns EVERY vent wall into a cable wall. A booth'
      puts '  with some of each is a booth that ships with ventilation twice over'
      puts '  or not at all, and both of those render as a perfectly normal booth.'
      puts '!' * 74
    end
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
      'casters_plate' => payload['cs'].to_i == 1,           # CP plate set + 4.75 in booth lift
      'step'          => payload['sp'].to_i == 1,           # refused by name downstream
      # The ROOF UNIT of a roof-mounted booth. rv, and rv alone, says roof
      # mounted — never the presence of CBL packs (see the file header). vs
      # picks the VSS twin; ef is passed for REPORTING only, because the
      # seating is keyed to model width and not to the EFS flag
      # (wr-roof-vent.rb).
      'roof_vent'     => roof && rm_block.empty?,
      'roof_vss'      => opts[:vss] ? true : false,
      'roof_efs'      => opts[:efs] ? true : false
    }
    built_opts = { 'desk' => 'desk', 'mjp' => 'MJP jack panel',
                   'efp' => 'elevated floor',
                   'casters_plate' => 'caster plate (CP set + 4.75 in booth lift)',
                   'roof_vent' => 'roof unit (RM assembly, seated on the roof)'
                 }.select { |k, _| overlay[k] }.values
    puts "  option parts to build: #{built_opts.join(', ')}" unless built_opts.empty?
    refused = []
    refused << 'sp: step (plate now builds; step placement not sourced — see wr-overlays.rb)' if payload['sp'].to_i == 1
    refused << 'bt: bass traps (no .skp exists — Benton to author)' if payload['bt'].to_i == 1
    refused << 'ac: Audimute panels (no .skp exists — Benton to author)' if payload['ac'].to_i == 1
    refused << 'sl: studio light (no fixture .skp exists — Benton to author)' if payload['sl'].to_i == 1
    # The ROOF UNIT now BUILDS (Benton settled the seating on 31 Aug 2026), so
    # this is a refusal only in the one case wr-roof-vent still names: a model
    # with no RM part at all. Listing it unconditionally, as this used to,
    # would understate a booth that is now complete.
    #
    # The VSS booth wants the VSS part. All 22 models have one — do NOT borrow
    # the portal's ART rule (RM_VSS_SET, only 60 and 72), which would name the
    # flat part on 20 of them. See wr-roof-vent.rb's header.
    if payload['rv'].to_i == 1
      rm_name = WR_RoofVent.part_name(key, opts[:vss] ? true : false)
      WR_RoofVent.roof_unit_blockers(key, variant, hx, opts[:efs],
                                     opts[:vss] ? true : false).each do |b|
        refused << "rv: the ROOF UNIT only (#{rm_name || 'no RM part'}.skp) " \
                   "— #{b} The cable walls a roof-mounted booth ships with " \
                   'ARE built.'
      end
    end
    unless refused.empty?
      puts "  NOT built, by name and by reason (#{refused.length}):"
      refused.each { |x| puts "    #{x}" }
    end
    puts '=' * 74

    # THE ROOF-MOUNT REFUSAL. A half-applied roof-mount swap is refused before
    # any geometry, on Standard and Enhanced alike — see RM_HALF_APPLY_ABORTS.
    if RM_HALF_APPLY_ABORTS && !rm_bad.empty?
      # The console line goes FIRST. UI.messagebox is the last statement of the
      # refusal for a human at the Ruby Console, but under the bridge it raises,
      # so a refusal recorded only after it would be missing from exactly the
      # transcript a test reads.
      puts '  ROOF-MOUNT BUILD REFUSED - see the reason(s) above. Nothing was placed.'
      UI.messagebox("This link says ROOF-MOUNTED VENTILATION (rv = 1), but it does not " \
                    "describe a booth that can exist:\n\n" + rm_bad.join("\n") +
                    "\n\nNOTHING WAS BUILT. A roof-mounted booth turns every vent wall into " \
                    "a cable wall. Half of that swap builds a booth that is either " \
                    "double-ventilated or not ventilated at all, and both look right in a " \
                    "render.\n\nFull detail is in the Ruby Console. To build anyway, set " \
                    'RM_HALF_APPLY_ABORTS = false in booth-from-link.rb.')
      return
    end

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

    # The NEW #3= structural hash is recognised first, and a malformed one is
    # REFUSED BY NAME here — it must not fall through to the "could not find
    # a design id" message, which would misreport a mangled link as no link.
    v3 = v3_hash(cfg['link'])
    if v3
      begin
        payload = v3_payload(v3)
      rescue V3Refusal => e
        puts "REFUSED #3= link: #{e.message}"
        UI.messagebox("This #3= short link cannot be decoded:\n\n#{e.message}\n\n" \
                      'NOTHING WAS BUILT. A link this tool cannot decode whole ' \
                      'is never decoded in part.')
        return
      end
      v3_report(payload)
      return build_from_payload(payload, cfg)
    end

    inline = hash_payload(cfg['link'])
    return build_from_payload(inline, cfg) if inline

    origin_id = short_id(cfg['link'])
    if origin_id.nil?
      UI.messagebox("Could not find a design id in that link.\n\n" \
                    "Expected ...booth-builder?d=<id>, ...#d=<hash> " \
                    "or ...#3=<hash>.")
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

# The autorun is guarded like every other tool script's ($wr_no_autorun /
# $wr_suppress_autorun, see wr-bridge-lib.rb's WRB.tool). It was not, which meant
# this file could only ever be loaded by a human at the Ruby Console: any test
# harness loading it got UI.inputbox, which the bridge refuses. That is why the
# CBL defect below was traced from source for a day instead of being run once.
begin
  WR_BoothLink.run unless $wr_no_autorun || $wr_suppress_autorun
rescue Exception => e
  puts ''
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(12).map { |l| "  #{l}" }.join("\n")
  UI.messagebox("Build from link failed:\n\n#{e.class}: #{e.message}\n\n" \
                'Full backtrace is in the Ruby Console.')
end
