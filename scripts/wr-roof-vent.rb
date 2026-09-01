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
# HOW THE UNIT IS SEATED, AND WHICH SIDE "RIGHT" MEANS
# ------------------------------------------------------------------------
# Benton gave placement offsets on 31 Aug 2026 (.forge/roof-vent-placement.md)
# and RESOLVED them the same day after all 22 parts were measured against them
# (.forge/builder/roof-vent/measure-rm.py, observed). The rule is two lines:
#
#   1. CENTRE the unit on the booth's NOMINAL footprint — the model number in
#      inches, which sits NOMINAL_INSET (1 in) inboard of the exterior face on
#      every side. Benton, 31 Aug: "Yes on almost all."
#   2. EXCEPT the four 84-INCH-WIDE models (4284, 6084, 8484, 10284), which go
#      FLUSH RIGHT. Benton, verbatim: "Shift those to the right. The left side
#      should have the gap of 3.25, and no gap on the right side."
#
# The arithmetic closes exactly and is the reason the exception is believable:
# each of those four flat parts measures 80.750 in wide against an 84 in
# nominal, so 3.250 + 80.750 + 0 = 84.000. Centring split that same slack into
# the 1.625 a side that made the parts look wrong against his stated 3.125.
#
# WHICH SIDE IS RIGHT. "Flush right" is meaningless without an orientation, and
# a mirrored one puts the unit on the wrong side of four models with no error
# anywhere. This codebase already has the convention and it is not invented
# here: booth-from-link.rb's WALL_WORD — the portal's own words for each wall,
# identical on all 25 catalogue layouts — reads
#
#     N => Back    S => Front    E => Right    W => Left
#
# and wr-booth-data.rb places those slots (observed): S panels at low y, N at
# high y, W at low x, E at high x. So in booth-local coordinates
#
#     +x is the booth's RIGHT (the E wall the portal labels "Right")
#     -x is its LEFT (W)
#     -y is the FRONT (S, the door wall)   +y is the BACK (N)
#
# i.e. RIGHT means +x for a viewer standing in FRONT of the booth and looking
# AT it. That is also the vocabulary Benton is reading when he says "right",
# because it is what the booth builder's "YOUR BOOTH" panel prints. Verified in
# the viewport, not only by assertion: .forge/builder/roof-vent/seat-shot.py
# builds an 8484 and an 8484-with-VSS roof-mount booth in a scratch model and
# captures a top-down and a front view, and the gap is on the LEFT.
#
# THE REFERENCE FACE, which Benton had not settled, fell out of the same
# measurement: front and back land on the NOMINAL footprint exactly on all 22
# parts — 4 in a side, 3 in on 4284/8484/84102/84126 — and are consequences of
# centring rather than inputs. RM102186.skp corroborates it: 21 of the 22 files
# are authored recentred on the origin and that one is not. It sits at
# (3.250, 4.000, 0) in its own file, which is exactly its own centred per-side
# offsets (observed, .forge/builder/roof-vent/measure-rm-faces.py).
#
# HX BOOTHS TAKE THE SAME PART. The absent RM<model>_HX.skp was never a gap.
# Benton, 31 Aug 2026: "No HX components for RM. These RM components just sit
# on the ceiling. Albeit, 10 in higher since the roof is 10 in higher." So
# nothing here special-cases hx: wr-overlays seats the unit on the booth's
# MEASURED roof plane, and the height extension raises that plane by building
# the booth from 91 in panels instead of 81 (build-booth-components, observed),
# which is HX_ADD and agrees with his stated 10 in. ceiling_required adds the
# same HX_ADD to the install clearance, so an HX roof-mount booth's ceiling
# figure follows the booth up.
#
# WHAT IS STILL REFUSED, BY NAME:
#   * rv = 1 on 4230 / 4242 / 4848 / 127 LP. No part exists at all.
# EFS is NOT consulted by the seating. Benton tied the flush-right shift to EFS
# being tight on those booths but instructed it for all four 84-in-wide models
# unconditionally, so it is implemented BY MODEL WIDTH. A 6084 with no EFS is
# therefore shifted too; that is the open question to put back to him.
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

  # ------------------------------------------------------------- seating --
  #
  # The booth's NOMINAL footprint — the model number in inches — sits this far
  # inboard of the exterior face on every side, so a booth whose exterior is
  # spec[:w] x spec[:h] carries its nominal rectangle from (1, 1) to
  # (w - 1, h - 1) in booth-local coordinates. Every offset Benton gave is
  # measured from that rectangle, confirmed on all 22 parts (see the header).
  NOMINAL_INSET = 1.0

  # The four models whose roof unit goes FLUSH RIGHT (+x, the E wall the portal
  # calls "Right") instead of centred. Benton, 31 Aug 2026: "Shift those to the
  # right. The left side should have the gap of 3.25, and no gap on the right
  # side." They are exactly the four 84-INCH-WIDE models — width is the SECOND
  # number in the model name, so 10284 is in and 84102 is not.
  #
  # LISTED, not computed from the width, on purpose: the rule as given is about
  # these four booths, and a list is a thing Benton can read and correct in one
  # line. It is cross-checked against the 84-in width in rbtest-roofvent.py so
  # the two cannot drift.
  FLUSH_RIGHT_MODELS = %w[4284 6084 8484 10284].freeze

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
  # THE MEASURED PART WINS, ALWAYS, when there is a measurement. Benton stated
  # 10 in flat and 16.5 in with the silencers stacked (VSS) on 31 Aug 2026,
  # and on the same day confirmed the VSS parts are correct as authored — the
  # stack fits the envelope. So the 16.5 is a drawing figure for the tallest
  # case, not a per-part height, and quoting it for every VSS booth over-reports
  # the ceiling on the 16 whose VSS file measures the same 10.3125 as its flat
  # twin. The six that DO measure taller (4260, 4284, 4872, 4896, 6060, 7272)
  # are then simply taller, and say so.
  #
  # This code used to take the LARGER of stated and measured. That was the
  # right call while the VSS files were suspected of being unauthored; Benton's
  # ruling settles it the other way, and an inflated ceiling requirement
  # disqualifies booths that fit.
  def self.unit_height(model, vss)
    key = vss ? :vss : :flat
    stated = STATED_UNIT_H[key]
    row = MEASURED[digits(model)]
    measured = row && row[key] && row[key][2]
    return [stated, "stated by Benton; no measurement for #{digits(model)}"] if measured.nil?
    [measured, format('measured off %s.skp (%.4f); Benton stated %g as the ' \
                      'drawing figure', part_name(model, vss), measured, stated)]
  end

  # Is this a model whose roof unit goes flush to the RIGHT (+x) rather than
  # centred? See FLUSH_RIGHT_MODELS and the header for which side +x is.
  def self.flush_right(model)
    FLUSH_RIGHT_MODELS.include?(digits(model))
  end

  # WHERE THE ROOF UNIT GOES, in booth-local inches. This is the whole seating
  # rule and the only place it is expressed.
  #
  #   ext_w, ext_d   the booth's EXTERIOR footprint, x then y — spec[:w] and
  #                  spec[:h] out of wr-booth-data.rb.
  #   part_w, part_d the roof part's own measured box, x then y.
  #
  # Returns a hash: :x / :y are where the part's LOW corner goes, :left,
  # :right, :front and :back are the resulting gaps to the nominal footprint
  # (so a reader can check the arithmetic closed), :rule names which of the two
  # rules was applied, and :error is non-nil when the part cannot be seated at
  # all — a part wider or deeper than the footprint it sits on is a bad
  # measurement or the wrong file, and is refused rather than hung over an edge.
  #
  # Coercion is written `x * 1.0`, never `x.to_f` — the same convention and the
  # same reason as wr-drop-lights.rb's pure section: rbtest-roofvent.py runs
  # this file in the minimal CRuby VM rbparse.py boots, and that VM does not
  # define Float#to_f. A method that cannot be exercised offline is a method
  # with no test.
  def self.seat(model, ext_w, ext_d, part_w, part_d)
    nom_w = ext_w * 1.0 - 2.0 * NOMINAL_INSET
    nom_d = ext_d * 1.0 - 2.0 * NOMINAL_INSET
    slack_x = nom_w - part_w * 1.0
    slack_y = nom_d - part_d * 1.0
    if slack_x < -0.001 || slack_y < -0.001
      return { :error => format('%s.skp measures %.3f x %.3f in, which does not ' \
                                'fit the %.1f x %.1f in nominal footprint of %s ' \
                                '— refusing to hang the roof unit over an edge',
                                part_name(model, false).to_s, part_w, part_d,
                                nom_w, nom_d, digits(model)) }
    end
    flush = flush_right(model)
    left  = flush ? slack_x : slack_x / 2.0
    front = slack_y / 2.0
    { :x => NOMINAL_INSET + left, :y => NOMINAL_INSET + front,
      :left => left, :right => slack_x - left,
      :front => front, :back => slack_y - front,
      :flush_right => flush,
      :rule => flush ? 'flush RIGHT (+x, the E wall) on the nominal footprint' :
                       'centred on the nominal footprint' }
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
               :why => "#{digits(model)} has no roof part, so there is no " \
                       'unit to add — this link is refused, see below' }
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

  # Every reason the roof unit cannot be seated on THIS booth, named. An EMPTY
  # list means the unit gets placed, which is now the ordinary case: Benton
  # settled the seating on 31 Aug 2026 and answered the HX question the same
  # day. One reason is left, and it is a real one.
  #
  # HX IS NO LONGER A BLOCKER, and the missing RM<model>_HX.skp was never a
  # gap. Benton, 31 Aug 2026: "No HX components for RM. These RM components
  # just sit on the ceiling. Albeit, 10 in higher since the roof is 10 in
  # higher." So the same part is used and only its z changes — and nothing here
  # adds 10 to anything, because wr-overlays seats the unit on the booth's
  # MEASURED roof plane. The height extension raises that plane by construction
  # (build-booth-components builds an HX booth from 91 in panels instead of
  # 81 — observed, `cfg['hx'] ? 91.0 : 81.0`), which agrees with Benton's
  # stated 10 in and with HX_ADD here. A `+ 10 if hx` branch would encode a
  # number the geometry already knows and would go silently wrong the day any
  # other option moved the roof.
  #
  # EFS IS DELIBERATELY NOT HERE EITHER. It used to block, because Benton had
  # said an EFS booth's unit "might be directly on the right edge". His ruling
  # replaced that with a rule keyed to MODEL WIDTH — the four 84-in-wide models
  # shift right, everything else centres, EFS or no EFS — so consulting the ef
  # flag would now be the invention. seating_note says so out loud on every
  # build, so a booth seated the wrong way is visible rather than silent.
  def self.roof_unit_blockers(model, variant, hx, efs, vss)
    d = digits(model)
    return [] if PART_MODELS.include?(d)
    ["no roof part exists for #{d.empty? ? model.to_s : d} — RM#{d}.skp is " \
     'not on the share, and the portal does not offer roof-mounted ' \
     'ventilation on 4230, 4242, 4848 or 127 LP. A link that claims rv = 1 ' \
     'on this model cannot be a real design.']
  end

  # How this booth's unit was seated, in the words a reader can check it in.
  # Printed on every roof-mounted build so the rule is visible at the moment it
  # is applied, and so the one thing still worth Benton's eye — that the shift
  # is keyed to model width and not to the EFS flag — is in front of him.
  #
  # One console line per element, kept inside 78 columns.
  def self.seating_note(model, vss, efs = false)
    d = digits(model)
    if flush_right(d)
      out = ['SEATED FLUSH RIGHT. The four 84-in-wide models (4284, 6084, 8484,',
             '10284) are shifted hard against the right edge of the nominal',
             'footprint: 3.25 in of gap on the LEFT and none on the right',
             '(Benton, 31 Aug 2026). RIGHT is +x — the E wall the booth builder',
             'labels "Right", i.e. your right when you stand in front of the',
             'booth and look at it.']
      out << 'Keyed to MODEL WIDTH, not to the EFS flag: Benton gave EFS as the'
      out << 'reason but named all four models unconditionally. This booth ' +
             (efs ? 'HAS' : 'has NO') + ' EFS'
      out << 'and is shifted either way. Say so if that is wrong.'
    else
      out = ['SEATED CENTRED on the booth NOMINAL footprint — the model number',
             'in inches, 1 in inboard of the exterior face per side (Benton,',
             '31 Aug 2026: "Yes on almost all"). Front and back offsets fall',
             'out of the centring and match his stated 4 in a side, or 3 in on',
             'the 84 series, exactly on all 22 parts as measured.']
    end
    out << 'The measured table is MEASURED in scripts/wr-roof-vent.rb; re-run'
    out << '.forge/builder/roof-vent/measure-rm.py to reproduce it.'
    out
  end
end
