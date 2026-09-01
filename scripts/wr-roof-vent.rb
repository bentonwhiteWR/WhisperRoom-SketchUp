# wr-roof-vent.rb — the roof-mounted ventilation (RM) unit: which part it is,
# how much ceiling it needs, and every reason it is not seated yet.
#
# NOT A COMMAND. A library, `load`ed by booth-from-link.rb, and in wr_tools'
# SKIP so it never appears in the panel. Nothing here touches the SketchUp API,
# so scripts/rbtest-roofvent.py runs the whole file outside SketchUp.
#
# WHAT A ROOF-MOUNTED BOOTH IS. The ducts leave the walls and go on the roof.
# booth-builder.html's applyRoofVent() rewrites every ' VNT' pack to ' CBL'
# before the link is serialised, so the walls arrive already swapped and
# booth-from-link builds them correctly today. What this file is about is the
# other half: the roof assembly itself.
#
# THE ROOF UNIT IS ONE PART. RM<model>.skp on P:/Sketchup/NewMasterComponentList
# is the complete roof assembly for that booth — both boxes, every duct — and
# needs seating, not assembling (Benton, 31 Aug 2026; corroborated by measuring
# all 22: each holds an even set of 'VSS duct box' + duct-box instances, one
# pair per vent set, 2 to 4 pairs by model — observed).
#
# ------------------------------------------------------------------------
# WHY NOTHING IS PLACED HERE YET — READ THIS BEFORE ADDING A TRANSLATION
# ------------------------------------------------------------------------
# Benton gave placement offsets on 31 Aug 2026 (.forge/roof-vent-placement.md):
# 4 in off the front and back edges, 3 in on "the 84 series", and 3.125 in off
# the left and right for "most". Giving BOTH edges of both axes over-determines
# the part's size, so the numbers are checkable, and all 22 parts were measured
# against them (.forge/builder/roof-vent/measure-rm.py, observed).
#
#   FRONT AND BACK CONFIRM, exactly, on all 22 — measured from the booth's
#   NOMINAL footprint (the model number in inches, which is the exterior minus
#   1 in per side). Every part is nominal_depth - 8.000, and the three 84
#   series are nominal_depth - 6.000. That closes his open question about the
#   reference face: it is neither the exterior nor the interior, it is nominal.
#
#   LEFT AND RIGHT DO NOT. Exactly one model of 22 (9696) measures 3.125 in a
#   side. Fourteen measure 3.250, four measure 1.625 (all four of them 84 in
#   wide), and three others differ again. The measured table is MEASURED below;
#   re-run .forge/builder/roof-vent/measure-rm.py to reproduce it.
#
# So the left/right figure is unconfirmed, and it is not this file's to round.
# Until Benton rules on it, roof_unit_blockers names every open question and
# nothing roof-side is drawn. Placement is not a number this codebase gets to
# invent (CLAUDE.md).
#
# ONE PIECE OF EVIDENCE MAY SETTLE IT IN A SENTENCE. Twenty-one of the 22 parts
# are authored with their geometry moved to the origin. RM102186.skp is not: it
# sits at (3.250, 4.000, 0) in its own file, which is exactly its own measured
# per-side offsets (observed, .forge/builder/roof-vent/measure-rm-faces.py). So
# that one un-recentred file is authored in booth-NOMINAL coordinates, CENTRED
# on the nominal footprint, and its offsets are consequences of the part's width
# rather than inputs. If "centre it on the nominal footprint" is the rule, every
# part is already right and placement is a few lines. It is still Benton's to
# confirm: on the four 84-in-wide models that implies 1.625 in a side, half what
# he said, and that gap is too large to wave through.
#
# WHAT IS NOT IN THE BUILD LIBRARY, ON PURPOSE. The share also carries
# RM60/RM72/.../RM192, their _BACK twins, RM60_VSS / RM72_VSS, and the
# RMVentilation*SideView / RMVSS_Stack_* composites. Those are ART SCENERY:
# their size sets match the portal's own render tables character for character
# (RM_FRONT_SIZES, RM_BACK_SET, RM_VSS_SET in layout-render.js), not the 22
# buildable models. art_only names them so no build path can ever compose one.
#
# THE VSS TRAP, and it is a real one. The ART rule is that only 60 and 72 have
# a VSS variant (RM_VSS_SET). The PART rule is different: all 22 models have an
# RM<model>VSS.skp (observed). Borrowing the art rule would silently skip 20 of
# them, so vss_part_name never consults a size set — every supported model has
# one.

module WR_RoofVent
  # Re-loadable like wr-deck.rb and wr-overlays.rb.
  constants.each { |c| remove_const(c) rescue nil }

  # The 22 models with a per-model roof part (observed, by listing
  # P:/Sketchup/NewMasterComponentList on 2026-08-31). This is exactly the set
  # the portal will offer roof-mounted ventilation on: layout-render.js's
  # RM_NO_SIZES excludes 4230, 4242, 4848 and '127 LP', and those four are the
  # only catalogue sizes missing from this list.
  PART_MODELS = %w[
    4260 4284 4872 4896 6060 6084 7272 7296 8484 84102 84126
    9696 96120 96144 96168 96192 102102 102126 102144 102168 102186 10284
  ].freeze

  # MEASURED, not stated. Each row is the part's face bounding box in inches,
  # x (left-right) by y (front-back) by z (how far it stands above whatever it
  # seats on), for the flat part and its VSS twin. Read live out of
  # P:/Sketchup/NewMasterComponentList on 2026-08-31 by
  # .forge/builder/roof-vent/measure-rm.py; the face box and the plain
  # definition box agreed to the thousandth on all 44 files, so no annotation
  # is inflating these.
  #
  # Only the z column is used today, and only to keep the ceiling requirement
  # honest (see unit_height). The x/y columns are here as the evidence behind
  # the offsets finding above, NOT as a placement source.
  MEASURED = {
    '4260'   => { :flat => [54.114,  34.0, 10.3125], :vss => [ 53.500, 34.0, 13.000] },
    '4284'   => { :flat => [80.750,  36.0, 10.3125], :vss => [ 84.000, 34.0, 19.500] },
    '4872'   => { :flat => [65.500,  40.0, 10.3125], :vss => [ 65.500, 40.0, 10.324] },
    '4896'   => { :flat => [89.500,  40.0, 10.3125], :vss => [ 89.500, 40.0, 13.000] },
    '6060'   => { :flat => [54.114,  52.0, 10.3125], :vss => [ 53.500, 52.0, 16.813] },
    '6084'   => { :flat => [80.750,  52.0, 10.3125], :vss => [ 80.750, 52.0, 10.3125] },
    '7272'   => { :flat => [65.500,  64.0, 10.3125], :vss => [ 67.675, 64.0, 10.499] },
    '7296'   => { :flat => [89.500,  64.0, 10.3125], :vss => [ 89.500, 64.0, 10.3125] },
    '8484'   => { :flat => [80.750,  78.0, 10.3125], :vss => [ 80.750, 78.0, 10.3125] },
    '84102'  => { :flat => [96.000,  78.0, 10.3125], :vss => [ 96.000, 78.0, 10.3125] },
    '84126'  => { :flat => [119.500, 78.0, 10.3125], :vss => [119.500, 78.0, 10.3125] },
    '9696'   => { :flat => [89.750,  88.0, 10.3125], :vss => [ 89.500, 88.0, 10.3125] },
    '96120'  => { :flat => [113.500, 88.0, 10.3125], :vss => [113.500, 88.0, 10.3125] },
    '96144'  => { :flat => [137.500, 88.0, 10.3125], :vss => [137.500, 88.0, 10.3125] },
    '96168'  => { :flat => [161.500, 88.0, 10.3125], :vss => [161.500, 88.0, 10.3125] },
    '96192'  => { :flat => [185.500, 88.0, 10.3125], :vss => [185.500, 88.0, 10.3125] },
    '102102' => { :flat => [95.500,  94.0, 10.3125], :vss => [ 95.500, 94.0, 10.3125] },
    '102126' => { :flat => [119.500, 94.0, 10.3125], :vss => [119.500, 94.0, 10.3125] },
    '102144' => { :flat => [137.500, 94.0, 10.3125], :vss => [137.500, 94.0, 10.3125] },
    '102168' => { :flat => [161.500, 94.0, 10.3125], :vss => [161.500, 94.0, 10.3125] },
    '102186' => { :flat => [179.500, 94.0, 10.3125], :vss => [179.500, 94.0, 10.3125] },
    '10284'  => { :flat => [80.750,  94.0, 10.3125], :vss => [ 80.750, 94.0, 10.3125] }
  }.freeze

  # STATED, by Benton, 31 Aug 2026: the roof unit adds 10 in to what the room
  # has to give, or 16.5 in when the silencers are stacked (VSS). The portal
  # carries the same pair as a DRAWING figure (layout-render.js's rmH).
  STATED_UNIT_H = { :flat => 10.0, :vss => 16.5 }.freeze

  # The catalogue's install clearance — the height a room must give, which is
  # NOT the booth's exact exterior height (CLAUDE.md: it is the space needed to
  # lift the tray ceiling on during assembly). 6'-11" Standard and 7'-1"
  # Enhanced, observed in whisperroom-catalog/data/models.json, identical on
  # every model in the file.
  STD_CLEARANCE = 83.0
  ENH_CLEARANCE = 85.0

  # The height extension. wr-overlays takes the panel height from 81 to 91 on
  # an HX booth, so HX raises everything above it by the same 10 (derived).
  HX_ADD = 10.0

  # Art-only families on the same share. Matching by NAME rather than by an
  # exclusion list of files, so a newly exported RM144_BACK.skp is excluded the
  # day it lands instead of the day someone remembers to add it.
  ART_ONLY = [
    /\ARM\d+\z/,                 # RM60 .. RM192, the per-WALL-LENGTH art subjects
    /\ARM\d+_/,                  # RM60_BACK, RM72_VSS, RM60_VSS_BACK
    /SideView\z/i,               # RMVentilationLeftSideView and the rest
    /\ARMVSS_Stack_/i,           # RMVSS_Stack_LeftSideView / RightSideView
    /\ARMVentilation/i           # the two loose boxes and the composites
  ].freeze

  # 'MDL 7272' / 'MDL 7272 S' / '7272' -> '7272'. Returns '' when there is no
  # model in the string, so callers get a miss from has_part rather than a nil
  # blowing up two frames later.
  def self.digits(model)
    m = model.to_s.strip.sub(/\AMDL\s+/i, '').sub(/\s+[SE]\z/i, '')
    m =~ /\A\d+\z/ ? m : ''
  end

  # Is this one of the 22 models a roof part exists for?
  def self.has_part(model)
    PART_MODELS.include?(digits(model))
  end

  # Is this component name one of the art-only families that must never reach
  # a build? True for RM60, RM72_VSS, RMVentilationIntakeBox, the side views.
  # False for RM7272 and RM7272VSS.
  def self.art_only(name)
    n = name.to_s.strip.sub(/\.skp\z/i, '')
    return false if PART_MODELS.include?(n.sub(/\ARM/, '').sub(/VSS\z/, ''))
    ART_ONLY.any? { |re| n =~ re }
  end

  # The .skp base name for a booth's roof unit, or nil when no part exists.
  # The VSS variant has NO underscore and exists on all 22 — see the VSS trap
  # in the header. resolve_part's norm_name forgives the separator either way,
  # but the name composed here is the real one.
  def self.part_name(model, vss)
    d = digits(model)
    return nil unless PART_MODELS.include?(d)
    "RM#{d}#{vss ? 'VSS' : ''}"
  end

  # How tall the roof unit stands above the roof, and where the figure came
  # from. Returns [inches, provenance].
  #
  # Benton's stated 10 / 16.5 and the measured parts disagree in BOTH
  # directions, so this takes the LARGER and says which it took. Ceiling height
  # disqualifies a booth faster than anything else (CLAUDE.md), so the one
  # error that must not happen here is under-reporting:
  #
  #   flat — every part measures 10.3125, a shade over the stated 10, so the
  #          measurement wins by 5/16 in.
  #   VSS  — 16 of the 22 VSS parts measure exactly the same 10.3125 as their
  #          flat twin rather than anything like 16.5, which reads as VSS
  #          geometry not yet authored on those files rather than as a real
  #          height. The stated 16.5 wins, and the disagreement is reported.
  def self.unit_height(model, vss)
    key = vss ? :vss : :flat
    stated = STATED_UNIT_H[key]
    row = MEASURED[digits(model)]
    measured = row && row[key] && row[key][2]
    return [stated, "stated by Benton; no measurement for #{digits(model)}"] if measured.nil?
    if measured > stated + 0.001
      [measured, format('measured off %s.skp (%.4f); Benton stated %g',
                        part_name(model, vss), measured, stated)]
    else
      [stated, format('stated by Benton (%g); %s.skp measures only %.4f',
                      stated, part_name(model, vss), measured)]
    end
  end

  # The height a room must give for this booth, roof unit included.
  #
  # Returns a hash: :booth is the catalogue install clearance plus the height
  # extension, :unit is the roof unit (0.0 when the booth is not roof mounted),
  # :total is what the room needs, and :why explains the unit figure.
  #
  # THIS IS THE NUMBER THE PORTAL GETS WRONG. booth-builder.html's fit card
  # compares the room ceiling against standingHeight + 2 and never adds the
  # roof unit at all, so it tells a shopper an RM booth needs about 7'-1" when
  # it needs nearly 8 ft (read off the portal source by the Researcher on
  # 2026-08-31 — reported, not exercised in a browser). Routed to Benton;
  # WhisperRoomQuote is read-only from here.
  def self.ceiling_required(model, variant, hx, roof, vss)
    booth = (variant.to_s.upcase == 'E' ? ENH_CLEARANCE : STD_CLEARANCE) +
            (hx ? HX_ADD : 0.0)
    return { :booth => booth, :unit => 0.0, :total => booth, :why => nil } unless roof
    # rv = 1 on a model with no roof part is an impossible link, refused by
    # impossible_roof_link. Adding a height for a unit that cannot exist would
    # put a fictional number in front of whoever reads the refusal.
    unless has_part(model)
      return { :booth => booth, :unit => 0.0, :total => booth,
               :why => "#{digits(model)} has no roof part, so there is no unit "                        'to add — this link is refused, see below' }
    end
    h, why = unit_height(model, vss)
    { :booth => booth, :unit => h, :total => booth + h, :why => why }
  end

  # Inches -> 7'-11.3", same shape csusb-106.rb and smith-studio.rb print.
  def self.ft(inches)
    f = (inches / 12.0).floor
    format("%d'-%.1f\"", f, inches - (f * 12.0))
  end

  # A link that claims roof-mounted ventilation on a model that has no roof
  # part is not a design that can exist, and it is not harmless: its vent walls
  # arrive already swapped to cable walls, so building it produces a booth with
  # no ventilation at all. Returns a complaint for booth-from-link's roof-mount
  # fence, in the same shape as roof_vent_complaints, or [].
  def self.impossible_roof_link(model, roof)
    return [] unless roof
    return [] if has_part(model)
    d = digits(model)
    ["#{d.empty? ? model.to_s : d} has no roof part (RM#{d}.skp is not on the " \
     'share) and the portal does not offer roof-mounted ventilation on 4230, ' \
     '4242, 4848 or 127 LP, so rv = 1 cannot be what this booth is',
     '  its vent walls have already been swapped to CABLE walls in the link, ' \
     'so building it would produce a booth with NO ventilation at all']
  end

  # Every reason the roof unit cannot be seated on THIS booth, named. An empty
  # list would mean the only thing left is the placement itself; today the
  # placement is unsourced for every booth, so seating_unsourced is always the
  # last entry. Each string is written to be read by Benton, not by a program.
  def self.roof_unit_blockers(model, variant, hx, efs, vss)
    d = digits(model)
    out = []
    if !PART_MODELS.include?(d)
      out << "no roof part exists for #{d.empty? ? model.to_s : d} — " \
             "RM#{d}.skp is not on the share, and the portal does not offer " \
             'roof-mounted ventilation on 4230, 4242, 4848 or 127 LP. A link ' \
             'that claims rv = 1 on this model cannot be a real design.'
      return out
    end
    if hx
      out << "this is a HEIGHT-EXTENDED (HX) booth and no RM#{d}_HX.skp " \
             'exists. Whether an HX booth takes the same roof unit 10 in ' \
             'higher, or a different one, is unanswered — so nothing is ' \
             'placed rather than a guess being placed 10 in wrong.'
    end
    if efs
      out << 'this link carries EFS (ef = 1). Benton said the roof unit on an ' \
             'EFS booth "might be directly on the right edge" rather than off ' \
             'it — the difference between 0 in and about 3 in — and "might" is ' \
             'his word. Both behaviours are wrong to guess at, so neither is ' \
             'built.'
    end
    out << format('the seating is not confirmed — %s.skp measures %.3f x %.3f ' \
                  'x %.4f in; see the note below.',
                  part_name(model, vss), *MEASURED[d][vss ? :vss : :flat])
    out
  end

  # The seating blocker in full, one console line per element. Kept out of
  # roof_unit_blockers so that list stays one entry per REASON — the thing a
  # caller counts — while the explanation stays readable at 78 columns.
  def self.seating_note
    ['Its FRONT/BACK offsets match Benton exactly — 4 in, or 3 in on the 84',
     'series — measured off the booth NOMINAL footprint (the model number in',
     'inches, which is the exterior minus 1 in a side). That also answers which',
     'face the offsets are taken from, which he had not settled.',
     'Its LEFT/RIGHT offsets do NOT match the stated 3.125 in: exactly 1 of the',
     '22 models measures 3.125 a side. Seating the part today would mean',
     'picking a number he did not give, so nothing is seated.',
     'The measured table is MEASURED in scripts/wr-roof-vent.rb; re-run',
     '.forge/builder/roof-vent/measure-rm.py to reproduce it.']
  end
end
