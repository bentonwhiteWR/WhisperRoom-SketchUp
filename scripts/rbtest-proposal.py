# -*- coding: utf-8 -*-
"""RUN proposal-package.rb's render-state classifier outside SketchUp.

    python rbtest-proposal.py

WHY THIS EXISTS
---------------
The live probe of 27 Aug 2026 showed V-Ray's `in_process?` RAISING
(StandardError "Incorrect DR version") on an idle renderer, so the proposal
batch now decides render completion from `state` via two pure methods in
proposal-package.rb: `read_signal` (the raise-swallowing read) and
`classify_render` (the verdict). Those two are the whole difference between
"the render saved when it finished" and "a black frame saved on tick one",
and they are pure data-in data-out — so they are the part that CAN be proven
before anyone renders. This harness runs them in the same CRuby 3.2 VM that
rbparse.py borrows from SketchUp.

Like rbtest.py, the METHOD SOURCE IS NOT COPIED HERE. `classify_render` and
`read_signal` are lifted verbatim from proposal-package.rb on every run, and
IDLE_STATE is read off its defining line in the same file — edit the script
and the next run tests the edit.

WHAT IT PROVES / DOES NOT PROVE
-------------------------------
It proves the classifier's table: the one OBSERVED sample (:idleInitialized,
sequence_ended? true) classifies finished; unknown states classify running
even when sequence_ended? disagrees; sequence_ended? decides only when state
is unreadable; both-unreadable is :unreadable; and a raising or absent
renderer method becomes :raised instead of an escaped exception. It does NOT
prove what V-Ray's `state` returns MID-RENDER — nobody has seen that value,
which is exactly why unknown-means-running plus a timeout is the design.

CHECKED AGAINST ITSELF
----------------------
Mutation-checked when written — each of these reintroduced bugs makes it FAIL:

    IDLE_STATE match inverted (running <-> finished)     -> cases 1,2 FAIL
    read_signal rescue removed (a raise escapes)         -> harness FAIL
    seq_ended consulted before state                     -> case 3 FAIL
    :raised treated as finished (the old in_process? bug)-> case 10 FAIL

RE-CHECKED 2026-08-28, the empty-frame day. The whole state vocabulary is
now OBSERVED (see proposal-package.rb's completion section): ONLY :idleDone
means a frame exists, and even that is only believed once the row has been
seen RUNNING (the latch, threaded in as classify_render's third argument so
the method stays pure). `cam_mismatch` joined it - the pure half of "is the
camera actually settled on the scene we are about to render". Mutation-
checked again, each of these makes it FAIL (verified, not assumed):

    any /idle/ state finished, no latch (the old code) -> 1,2,6,7,forever,seq
    latch ignored on :idleDone                         -> case 6 FAIL
    cam_mismatch tolerance widened to 99               -> cam3, cam4 FAIL

ENTRY GUARDS (added 2026-08-27, the dead-button day): the panel button did
nothing because a shared $wr_no_autorun_was global was clobbered by nested
loads, leaving $wr_no_autorun stuck true and the autorun line suppressed.
The decisions are now pure methods, covered here and mutation-checked when
added — each of these reintroduced bugs makes it FAIL:

    autorun? inverted (suppressed flag runs, clear skips) -> auto1-3 FAIL
    launch_decision's not-running early return inverted   -> launch1-6 FAIL
    launch_decision reset/decline swapped                 -> launch4-6 FAIL

Do that again if you ever doubt it.

THE LIFECYCLE HALF (added 1.9.6, 30 Aug 2026)
---------------------------------------------
The 30 Aug audit's sharpest sentence: **this suite passed 64/64 while the
render lane was unlaunchable from the button.** Everything above covered ten
PURE helpers; every defect of the previous month lived in the other half --
start_run's ordering, the reconciliation, annot_push's capture-before-mutate
contract, the dialog callbacks. Those are now covered too, with SketchUp and
V-Ray stubbed (FakeModel / FakeLayer / output_size) so the REAL methods run.

    gate1-4   the size gate READS before it JUDGES (D9, the 1.9.4 blocker),
              the refusal survives for a genuinely unreadable size, and an
              image-only batch is never refused
    sum1-3    a LOST ROW is counted in the headline, not just named at the
              bottom of the summary (D11)
    lost1-3   lost_rows, the one method the headline and the closing verdict
              both read
    annot1-4  the hide record is published BEFORE the first tag is flipped,
              so a partial failure is still restorable (D10)
    busy1-3   the dialog callbacks' running guard (D12 / F5)

Mutation-checked when written -- RUN, not assumed, 30 Aug 2026. Each of these
reintroduced bugs makes the named check FAIL:

    render_size_gate JUDGE-then-READ (the 1.9.4 order)    -> gate1, gate2 FAIL
    render_size_gate refusal deleted                      -> gate3 FAIL
    summary_lines headline counts @results only           -> sum1 FAIL
    @annot_saved assigned after the hide loop             -> annot1, annot3,
                                                             annot4 FAIL
    busy? never refuses                                   -> busy1 FAIL

WHAT THIS HALF STILL DOES NOT PROVE. start_run itself is not executed here --
only the gate it now calls. step / step_body's re-entrancy split, finish's
restore ORDER and its two messagebox sites, and plan_names / uniquify /
sanitize (the FILE-column contract) remain uncovered. And nothing offline can
prove the real UI::HtmlDialog path: no batch has ever been started from the
dialog's own Export button.

THE MANIFEST HALF (1.10.7)
--------------------------
proposal-package.rb now writes manifest.json beside the images (the
45-minute finding: scene names, export order and dimension text were being
re-derived from pixels downstream). Its pure half is covered here:

    bn1-7     booth_name? — name-matching only, never derivation
    dd1-6     dim_display — '<>' substitution; a nil measured value leaves
              the raw text (placeholder and all) so absence stays VISIBLE
    st1-4     shown_annot_tags — client-safe beats everything; an unreadable
              scene state is nil-with-a-note, never a guessed list
    mr1-4     manifest_rows — the plan/results join: a planned row with no
              result is status 'lost' (the D8/D11 doctrine), width/height
              are null unless actually recorded, export order is preserved

The impure half — collect_annotations, page_hidden_tags, write_manifest —
touches the SketchUp API and is live-verified per .forge/builder/HANDOFF.md.

HARNESS LIMIT WORTH KNOWING. The barebones CRuby VM rbparse boots out of
SketchUp's DLL has no Object#class -- `1.class` raises NoMethodError in it.
proposal-package.rb interpolates e.class into every failure message, so any
lifted rescue path needs an exception class that answers it (see FakeError).
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rbparse  # noqa: E402  - reuse its DLL discovery and VM boot
import rbtest   # noqa: E402  - reuse method_source (safe: main() is guarded)

SRC = os.path.join(HERE, 'proposal-package.rb')
EXP = os.path.join(HERE, 'export-scenes.rb')


def const_line(name, src=None):
    """The verbatim defining line of a module-level constant."""
    src = src or SRC
    for ln in open(src, encoding='utf-8').read().split('\n'):
        if re.match(r'^  %s\s*=' % re.escape(name), ln):
            return ln
    raise SystemExit('%s: no constant %s' % (os.path.basename(src), name))


def const_block(name):
    """A constant whose definition runs over more than one line, verbatim.

    Ends at the first line closing the literal (`.freeze` or `].freeze`)."""
    lines = open(SRC, encoding='utf-8').read().split('\n')
    out = []
    for ln in lines:
        if not out and not re.match(r'^  %s\s*=' % re.escape(name), ln):
            continue
        out.append(ln)
        if '.freeze' in ln or (out and ln.rstrip().endswith(']')):
            return '\n'.join(out)
    raise SystemExit('proposal-package.rb: no constant %s' % name)


FIXTURE = r'''
module WR_ProposalPackage
%(idle_state)s
%(done_state)s
%(error_state)s
%(cam_fields)s
%(ev_consts)s
%(mode_fallback)s
%(aspect)s

%(ev_for)s

%(shutter_for_ev)s

%(ev_of_camera)s

%(mode_restore_target)s

%(package_size)s

%(read_signal)s

%(classify)s

%(cam_mismatch)s

%(autorun)s

%(launch)s

%(honoured_size)s

%(require_render_size)s

%(render_size_gate)s

%(lost_rows)s

%(summary_lines)s

%(annot_push)s

%(annot_pop)s

%(busy)s

%(booth_name)s

%(dim_display)s

%(shown_annot_tags)s

%(manifest_rows)s

  # ---- 1.9.6: the LIFECYCLE half. Everything above this line is a pure
  # helper; every defect of the last month lived below it. The audit of
  # 30 Aug 2026 put it plainly: this suite passed 64/64 while the render lane
  # was unlaunchable from the button, because nothing here touched start_run's
  # ordering, summary_lines' reconciliation, annot_push's capture-before-
  # mutate contract or the dialog callbacks' running guard.
  #
  # These stubs stand in for SketchUp and V-Ray so the real methods can run.
  ANNOT_TAGS = %%w[T1 T2 T3].freeze

  # honoured_size asks output_size(vray_context). @vray_readable flips between
  # "V-Ray answers 1600x900" and "V-Ray cannot be read", which is the whole
  # input space of the size gate.
  def self.vray_context; :ctx; end
  def self.output_size(_ctx); @vray_readable ? [1600, 900] : nil; end

  # The barebones CRuby VM rbparse boots out of SketchUp's DLL has NO
  # Object#class -- verified 30 Aug 2026: `1.class` raises NoMethodError in
  # it. Every failure message in proposal-package.rb interpolates e.class, so
  # without this shim the partial-failure paths (annot_push's rescue, the one
  # D10 is about) could not be exercised here at all. HARNESS ONLY: SketchUp's
  # own Ruby has the real method and is unaffected.
  # ...so the fake layer raises THIS instead, a StandardError subclass that
  # answers `class`. Reopening StandardError itself breaks `raise` in this VM
  # (tried, 30 Aug 2026); a subclass is caught by the same
  # `rescue StandardError` and leaves the built-in alone.
  class FakeError < StandardError
    def class; 'FakeError'; end
  end

  # The dialog. Every log line in the real file is rescued; here it is a sink.
  def self.log(_dlg, _text, _cls); nil; end

  class FakeLayer
    attr_reader :name
    def initialize(name, vis, boom)
      @name = name
      @vis  = vis
      @boom = boom
    end
    def visible?; @vis; end
    def visible=(v)
      raise FakeError, "layer #{@name} is locked" if @boom
      @vis = v
    end
  end
  class FakeLayers
    def initialize(h); @h = h; end
    def [](n); @h[n]; end
  end
  class FakeModel
    attr_reader :layers
    def initialize(layers); @layers = layers; end
  end

  # Stub renderers for read_signal: one answers, one raises, one is bare.
  class RendOK
    def state; :idleInitialized; end
  end
  class RendRaises
    def state; raise StandardError, 'Incorrect DR version'; end
  end
  class RendBare; end

  # Entry-guard cases (the 2026-08-27 dead button): the autorun decision and
  # the batch-guard decision, both pure. [args..., expected]
  AUTORUN_CASES = [
    [nil,   true ],   # fresh session — run
    [false, true ],   # explicitly cleared — run
    [true,  false],   # a loader (or a stale flag) suppressed it — skip, loudly
  ]
  LAUNCH_CASES = [
    # [running, reset_confirmed, expected]
    [false, false, :launch ],   # nothing running: open the dialog
    [false, true,  :launch ],   # ...even a spurious confirm changes nothing
    [nil,   false, :launch ],   # never-set ivar reads nil, same as false
    [true,  true,  :reset  ],   # flag set, user confirmed stale: clear + open
    [true,  false, :decline],   # flag set, user declined: leave it alone
    [true,  nil,   :decline],   # no answer counts as declined
  ]

  CASES = [
    # [state_val, seq_ended, seen_running(latch), expected]
    #
    # The full state vocabulary is OBSERVED (28 Aug 2026):
    #   :idleStopped/:idleInitialized/:idleDone -> sequence_ended? true
    #   :preparing/:rendering                   -> sequence_ended? false
    # ONLY :idleDone means a frame exists, and only once the row has been
    # seen running. Cases 1, 6 and 12 are the 28 Aug empty-frame bug.
    [:idleInitialized, true,    false, :idle      ],  # 1 cold: NOT finished
    [:idleInitialized, true,    true,  :idle      ],  # 2 initialized never done
    [:rendering,       true,    false, :running   ],  # 3 state decides ALONE
    [:preparing,       false,   false, :running   ],  # 4 the 440 ms lead-in
    [:idleDone,        true,    true,  :finished  ],  # 5 THE only finish
    [:idleDone,        true,    false, :idle      ],  # 6 done without ever
                                                      #   running = never ran
    [:idleStopped,     true,    true,  :idle      ],  # 7 stopped is not done
    ['IDLEDONE',       :raised, true,  :finished  ],  # 8 string, any case
    [:someNewState,    :raised, false, :running   ],  # 9 unknown = running
    [:raised,          :raised, true,  :unreadable],  # 10 both signals dead
    [:raised,          true,    true,  :finished  ],  # 11 backup, latched
    [:raised,          true,    false, :idle      ],  # 12 backup reads true
                                                      #    COLD - not finished
    [:raised,          false,   false, :running   ],  # 13 backup, running
    [nil,              nil,     true,  :unreadable],  # 14 absent readings

    # F1 -- the five documented states the 28 Aug live watch never saw.
    # Source: VRayRenderer#state in the on-disk V-Ray 7 YARD docs, 29 Apr
    # 2026. Cases 15 and 16 are the bug: before 1.9.2 :fatalError returned
    # :running (latch set, 30-minute timeout burned) and :idleError
    # returned :idle (failed with the wrong reason).
    [:fatalError,      :raised, false, :failed    ],  # 15 was :running
    [:fatalError,      :raised, true,  :failed    ],  # 16 latched, still fail
    [:idleError,       true,    true,  :failed    ],  # 17 /Aidle/ prefix must
                                                      #    NOT win over /error/
    [:renderingPaused, false,   true,  :running   ],  # 18 paused is running
    [:renderingAwaitingChanges, false, true, :running], # 19 idem
    [:idleFrameDone,   true,    true,  :idle      ],  # 20 NOT :idleDone --
                                                      #    policy unchanged,
                                                      #    pinned so a future
                                                      #    change is deliberate
  ]

  # cam_mismatch: nil means the viewport agrees with the page's camera.
  CAM_A = [10.0, 20.0, 30.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 35.0]
  CAM_CASES = [
    [CAM_A, CAM_A.dup,                       nil    ],  # identical
    [CAM_A, CAM_A.each_with_index.map { |v, i| i == 2 ? v + 0.005 : v },
                                             nil    ],  # inside tolerance
    [CAM_A, CAM_A.each_with_index.map { |v, i| i == 2 ? v + 2.0 : v },
                                             'eye.z'],  # mid-transition
    [CAM_A, CAM_A.each_with_index.map { |v, i| i == 9 ? v + 5.0 : v },
                                             'lens' ],  # different lens
    [nil,   CAM_A,                           'unreadable'],
    [CAM_A, [1.0, 2.0],                      'shape'],
  ]

  # 1.9.3 -- the per-row exposure table, the mode-restore fallback and the
  # one-aspect output size. Each of these replaces something that used to be
  # decided by accident: the exposure by the V-Ray default, the mode restore
  # by a condition that silently did not match, the height by the SketchUp
  # window.
  #
  # Mutation-checked when written -- each of these reintroduced bugs FAILS:
  #     ev_for ignoring the stored value              -> ev3, ev4
  #     ev_for defaulting everything to EV_ROOM       -> ev1, ev2
  #     ev_for accepting an out-of-range stored value -> ev5, ev6
  #     shutter_for_ev dropping the f-number term     -> sh1..sh4
  #     mode_restore_target keeping the old
  #       %%w[draft render].include? SKIP (F3)         -> mode3, mode4
  #     out_height ignoring the requested height (D4) -> h1, h2
  EV_CASES = [
    # [scene name, stored value, expected EV]
    ['04 Booth Interior',           nil,  EV_INTERIOR],  # ev1 name says interior
    ['01 Booth Exterior in Room',   nil,  EV_ROOM    ],  # ev2 anything else
    ['02 Room Context Wide',        10.5, 10.5       ],  # ev3 stored wins
    ['04 Booth Interior',           13.0, 13.0       ],  # ev4 stored beats name
    ['04 Booth Interior',           0.0,  EV_INTERIOR],  # ev5 absurd -> default
    ['02 Room Context Wide',        99.0, EV_ROOM    ],  # ev6 idem
    ['05 Room Plan',                'x',  EV_ROOM    ],  # ev7 junk is not a number
    ['03 Inside the booth',         nil,  EV_INTERIOR],  # ev8 'inside' too
  ]

  # OBSERVED, not invented: f/8 @ 1/300 is V-Ray's shipped default and is
  # documented as EV 14.23, and the bracket renders of 30 Aug 2026 used
  # exactly these shutter values at these EVs.
  SHUTTER_CASES = [
    [9.0,  8.0  ],   # sh1 the booth interior value
    [12.0, 64.0 ],   # sh2 the room value
    [14.0, 256.0],   # sh3
    [6.0,  1.0  ],   # sh4 f-number term alone
  ]

  MODE_CASES = [
    ['draft',                    'draft' ],  # mode1
    ['render',                   'render'],  # mode2
    ['unknown (never toggled)',  'draft' ],  # mode3 THE F3 BUG
    [nil,                        'draft' ],  # mode4
  ]

  SIZE_CASES = [
    ['1200', [1200, 900]],
    ['2400', [2400, 1800]],
    ['0',    [1200, 900]],    # out of range -> the documented default
  ]

  # export-scenes.rb's out_height (D4). [width, requested, vp_w, vp_h,
  # expected height, expected source fragment]
  HEIGHT_CASES = [
    [1200, '900', 2169, 859, 900, 'requested'],   # h1 explicit WINS over the window
    [1200, nil,  2169, 859, 475, 'viewport' ],   # h2 pass 1's letterbox, unchanged
    [1200, '10',  2169, 859, 475, 'out of range'],# h3 refused, and it SAYS so
    [1200, nil,  0,    0,   900, '4:3'      ],   # h4 unreadable viewport, named
  ]

  def self.check
    out = []
    CASES.each_with_index do |(st, seq, latch, want), i|
      got = classify_render(st, seq, latch)
      out << (got == want ? "#{i + 1} ok" : "#{i + 1} FAIL got #{got} want #{want}")
    end

    # A renderer that reports idle FOREVER (the 28 Aug failure mode): 1000
    # polls of the observed cold pair, latch never set because :running is
    # never seen. Not one of them may say finished.
    latch = false
    ever  = false
    1000.times do
      v = classify_render(:idleInitialized, true, latch)
      latch = true if v == :running
      ever  = true if v == :finished
    end
    out << (ever ? 'forever FAIL a cold renderer reported finished' : 'forever ok')

    # ...and the happy sequence: cold, preparing, rendering, done.
    latch = false
    seen  = [:idleInitialized, :preparing, :rendering, :rendering, :idleDone].map do |st|
      v = classify_render(st, st.to_s =~ /idle/ ? true : false, latch)
      latch = true if v == :running
      v
    end
    want = [:idle, :running, :running, :running, :finished]
    out << (seen == want ? 'seq ok' : "seq FAIL got #{seen.inspect}")

    CAM_CASES.each_with_index do |(a, b, want_frag), i|
      got = cam_mismatch(a, b)
      ok = want_frag.nil? ? got.nil? : (got.to_s.include?(want_frag))
      out << (ok ? "cam#{i + 1} ok" : "cam#{i + 1} FAIL got #{got.inspect}")
    end

    EV_CASES.each_with_index do |(nm, stored, want), i|
      got = ev_for(nm, stored)
      out << (got == want ? "ev#{i + 1} ok" : "ev#{i + 1} FAIL got #{got} want #{want}")
    end
    SHUTTER_CASES.each_with_index do |(ev, want), i|
      got = shutter_for_ev(ev)
      ok = (got - want).abs < 0.0001
      # ...and the round trip: the EV read back off the camera must be the
      # EV asked for. This is the number the run log reports.
      back = ev_of_camera(EV_F_NUMBER, got)
      ok &&= (back - ev).abs < 0.0001
      out << (ok ? "sh#{i + 1} ok" : "sh#{i + 1} FAIL got #{got} want #{want} back #{back.inspect}")
    end
    out << (ev_of_camera(0.0, 8.0).nil? && ev_of_camera(8.0, 0.0).nil? ?
              'ev-guard ok' : 'ev-guard FAIL a zero must not become an EV')
    MODE_CASES.each_with_index do |(saved, want), i|
      got = mode_restore_target(saved)
      out << (got == want ? "mode#{i + 1} ok" : "mode#{i + 1} FAIL got #{got.inspect}")
    end
    SIZE_CASES.each_with_index do |(w, want), i|
      got = package_size(w)
      out << (got == want ? "size#{i + 1} ok" : "size#{i + 1} FAIL got #{got.inspect}")
    end
    HEIGHT_CASES.each_with_index do |(w, req, vw, vh, want_h, want_src), i|
      h, src = WR_ExportScenes.out_height(w, req, vw, vh)
      ok = h == want_h && src.to_s.include?(want_src)
      out << (ok ? "h#{i + 1} ok" : "h#{i + 1} FAIL got #{[h, src].inspect}")
    end

    out << (read_signal(RendOK.new, :state) == :idleInitialized ?
              'sig-ok ok' : 'sig-ok FAIL')
    out << (read_signal(RendRaises.new, :state) == :raised ?
              'sig-raise ok' : 'sig-raise FAIL')
    out << (read_signal(RendBare.new, :state) == :raised ?
              'sig-absent ok' : 'sig-absent FAIL')
    AUTORUN_CASES.each_with_index do |(flag, want), i|
      got = autorun?(flag)
      out << (got == want ? "auto#{i + 1} ok" : "auto#{i + 1} FAIL got #{got}")
    end
    LAUNCH_CASES.each_with_index do |(running, confirmed, want), i|
      got = launch_decision(running, confirmed)
      out << (got == want ? "launch#{i + 1} ok" : "launch#{i + 1} FAIL got #{got}")
    end


    # ================================================================
    # D9 -- THE SIZE GATE'S ORDER. This is the test that would have caught
    # the 1.9.4 blocker on a fresh load.
    #
    # require_render_size! judges @size_source; honoured_size is the only
    # thing that sets it. start_run asked the gate 168 lines BEFORE the read,
    # and refused by returning, so @size_source was still nil on the next
    # press: every batch with a render row refused forever. render_size_gate
    # welds the two together, READ then JUDGE, and gate1 fails if that order
    # is ever swapped back.
    # ================================================================
    @vray_readable = true
    @size_source   = nil                    # a fresh load, nothing read yet
    sz1, why1 = render_size_gate('1200', true)
    out << ((why1.nil? && sz1 == [1600, 900]) ? 'gate1 ok' :
            "gate1 FAIL a readable V-Ray size was refused: #{why1.inspect} " \
            "size #{sz1.inspect}")

    # gate2: press it again. The old bug was a CLOSED LOOP -- the refusal
    # returned before the read, so the second press refused identically.
    @size_source = nil
    _sz2, why2 = render_size_gate('1200', true)
    out << (why2.nil? ? 'gate2 ok' :
            'gate2 FAIL the second press was refused (the closed loop is back)')

    # gate3: the refusal must SURVIVE as a real refusal. A render batch whose
    # size genuinely cannot be read is still stopped, by name.
    @vray_readable = false
    @size_source   = nil
    sz3, why3 = render_size_gate('1200', true)
    out << ((why3.to_s.include?('could not be read') && sz3 == [1200, 900]) ?
            'gate3 ok' : "gate3 FAIL an unreadable render size was allowed: " \
                         "#{why3.inspect}")

    # gate4: an image-only batch is never refused and still gets its size --
    # the Width fallback is legitimate when nothing is being rendered.
    @vray_readable = false
    @size_source   = nil
    sz4, why4 = render_size_gate('2400', false)
    out << ((why4.nil? && sz4 == [2400, 1800]) ? 'gate4 ok' :
            "gate4 FAIL image-only batch refused: #{why4.inspect} #{sz4.inspect}")

    # ================================================================
    # D11 -- A LOST ROW IS A FAILURE IN THE HEADLINE. The reconciliation
    # existed and named the row at the BOTTOM of the summary; the top line
    # was counted from @results alone, so a batch that lost a row still read
    # '0 FAILED'. A client pack one render short that reports success is the
    # worst failure this tool has.
    # ================================================================
    @cfg              = { 'dir' => 'C:/out' }
    @unmapped         = nil
    @mode_note        = nil
    @quality_problems = []
    @results = [
      { :file => '01.png', :status => 'ok',     :detail => 'written' },
      { :file => '02.png', :status => 'ok',     :detail => 'written' },
      { :file => '03.png', :status => 'failed', :detail => 'render failed' }
    ]
    @plan_files = %%w[01.png 02.png 03.png 04.png 05.png]
    sl   = summary_lines('done', [])
    head = sl.first.to_s
    okS  = head.include?('2 exported') && head.include?('3 FAILED') &&
           sl.any? { |l| l.include?('PRODUCED NO RESULT') }
    out << (okS ? 'sum1 ok' :
            "sum1 FAIL two lost rows did not reach the headline: #{head.inspect}")

    # sum2: nothing lost -- the headline must NOT inflate, and no lost-row
    # block may be printed.
    @plan_files = %%w[01.png 02.png 03.png]
    sl2 = summary_lines('done', [])
    ok2 = sl2.first.to_s.include?('1 FAILED') &&
          sl2.none? { |l| l.include?('PRODUCED NO RESULT') }
    out << (ok2 ? 'sum2 ok' : "sum2 FAIL #{sl2.first.inspect}")

    # sum3: a run that never recorded a plan reconciles against nothing.
    @plan_files = nil
    out << (summary_lines('done', []).first.to_s.include?('1 FAILED') ?
              'sum3 ok' : 'sum3 FAIL a nil plan broke the headline')

    # lost_rows itself, the one method both the headline and the closing
    # verdict read, so they can never disagree again.
    out << (lost_rows(%%w[a b c], %%w[a c]) == %%w[b] ? 'lost1 ok' : 'lost1 FAIL')
    out << (lost_rows(nil, %%w[a]) == [] ? 'lost2 ok' : 'lost2 FAIL')
    out << (lost_rows(%%w[a], %%w[a]) == [] ? 'lost3 ok' : 'lost3 FAIL')

    # ================================================================
    # D10 -- CAPTURE BEFORE MUTATE. annot_push used to assign @annot_saved
    # AFTER the hide loop and nil it in the rescue, so a raise partway
    # through left tags hidden in Benton's model with no record of what they
    # were -- annot_pop no-opped, finish no-opped, and the tags stayed off
    # into the next session. annot1/annot2 fail if that ordering returns.
    # ================================================================
    lay = { 'T1' => FakeLayer.new('T1', true, false),
            'T2' => FakeLayer.new('T2', true, false),
            'T3' => FakeLayer.new('T3', true, true) }   # T3 raises on hide
    fm = FakeModel.new(FakeLayers.new(lay))
    @client_safe = true
    @annot_saved = nil
    annot_push(fm, nil, 'row.png')
    rec = @annot_saved
    okA = !rec.nil? && rec['T1'] == true && rec['T2'] == true
    out << (okA ? 'annot1 ok' :
            "annot1 FAIL the hide record was lost on a partial failure: #{rec.inspect}")
    # ...and the record is USABLE: annot_pop puts back what was hidden.
    out << ((lay['T1'].visible? == false && lay['T2'].visible? == false) ?
              'annot2 ok' : 'annot2 FAIL the two reachable tags were not hidden')
    # The property that matters: what was hidden comes BACK. (@annot_saved is
    # not checked for nil here -- annot_pop's own nil comes after its loop and
    # T3 raises again on the way back; finish's `ensure @annot_saved = nil`
    # covers that in production.)
    annot_pop(fm, nil)
    okB = lay['T1'].visible? && lay['T2'].visible?
    out << (okB ? 'annot3 ok' :
            'annot3 FAIL tags were left hidden in the model after the batch')

    # annot4: the clean path still records every tag and restores every tag.
    lay2 = { 'T1' => FakeLayer.new('T1', true,  false),
             'T2' => FakeLayer.new('T2', false, false),
             'T3' => FakeLayer.new('T3', true,  false) }
    fm2 = FakeModel.new(FakeLayers.new(lay2))
    @annot_saved = nil
    annot_push(fm2, nil, 'row.png')
    hidden_all = lay2.values.none? { |l| l.visible? }
    annot_pop(fm2, nil)
    okC = hidden_all && lay2['T1'].visible? && !lay2['T2'].visible? &&
          lay2['T3'].visible?
    out << (okC ? 'annot4 ok' : 'annot4 FAIL clean push/pop did not round-trip')

    # ================================================================
    # D12 (F5, open since 28 Aug) -- the dialog callbacks' running guard.
    # render_production pumps the Windows message loop, so a callback CAN be
    # dispatched mid-render; setfill would then leave render materials on the
    # model, silently. busy? is the predicate all four callbacks now consult.
    # ================================================================
    @running = true
    out << (busy?(nil, 'setfill') ? 'busy1 ok' :
            'busy1 FAIL a model-mutating callback would run mid-batch')
    @running = false
    out << ((busy?(nil, 'setfill') == false) ? 'busy2 ok' :
            'busy2 FAIL the guard refuses when no batch is running')
    @running = nil
    out << ((busy?(nil, 'mark') == false) ? 'busy3 ok' : 'busy3 FAIL')

    # ================================================================
    # 1.10.7 -- THE MANIFEST'S PURE HALF. The honesty rule under test:
    # nothing may invent a number, a missing value fails BY NAME (null /
    # 'lost' / a note), and export order is preserved.
    # ================================================================
    [['MDL 4260 S', true],       # the booth-*.rb group name
     ['4872 S', true],           # build-booth.rb names the group the bare key
     ['96120 E booth', true],
     ['MDL', true],              # verbatim capture; matching is not judging
     ['Room shell', false],
     ['', false],
     ['12 chairs', false]].each_with_index do |(nm, want), i|
      got = booth_name?(nm)
      out << (got == want ? "bn#{i + 1} ok" :
              "bn#{i + 1} FAIL got #{got} for #{nm.inspect}")
    end

    [['<>', '4\' 6"', '4\' 6"'],     # dd1 auto text: substituted
     ['~<>', '10"', '~10"'],         # dd2 prefix survives
     ['CLEAR', '10"', 'CLEAR'],      # dd3 an override WINS over geometry
     ['', '10"', '10"'],             # dd4 empty raw: the measured value
     ['<>', nil, '<>'],              # dd5 nil measured: placeholder STAYS
     ['', nil, '']].each_with_index do |(raw, meas, want), i|
      got = dim_display(raw, meas)
      out << (got == want ? "dd#{i + 1} ok" :
              "dd#{i + 1} FAIL got #{got.inspect} want #{want.inspect}")
    end

    st1 = shown_annot_tags(['B'], true, ['A', 'B', 'C'], true)
    out << ((st1[0] == [] && st1[1].to_s.include?('client-safe')) ?
              'st1 ok' : "st1 FAIL #{st1.inspect}")
    st2 = shown_annot_tags(['B'], false, ['A', 'B'], false)
    out << ((st2[0].nil? && st2[1].to_s.include?('use_hidden_layers')) ?
              'st2 ok' : "st2 FAIL #{st2.inspect}")
    st3 = shown_annot_tags(nil, true, ['A'], false)
    out << ((st3[0].nil? && st3[1].to_s.include?('could not be read')) ?
              'st3 ok' : "st3 FAIL #{st3.inspect}")
    st4 = shown_annot_tags(['B'], true, ['A', 'B', 'C'], false)
    out << ((st4 == [['A', 'C'], nil]) ? 'st4 ok' : "st4 FAIL #{st4.inspect}")

    mplan = [{ :file => '01.png', :n => 1, :lane => 'image', :scene => 'S1',
               :shown => ['WR-Dims'], :shown_note => nil },
             { :file => '02 render.png', :n => 2, :lane => 'render',
               :scene => 'S2', :shown => nil, :shown_note => 'unreadable: x' },
             { :file => '03.png', :n => 3, :lane => 'image', :scene => 'S3',
               :shown => [], :shown_note => nil }]
    mres  = [{ :file => '01.png', :status => 'ok', :detail => 'image',
               :width => 1200, :height => 900,
               :groups_hidden => ['R1 / Walls / Wall 2'] },
             { :file => '02 render.png', :status => 'skipped',
               :detail => 'already existed' }]
    mr = manifest_rows(mplan, mres)
    r1 = mr[0]
    r2 = mr[1]
    r3 = mr[2]
    ok1 = r1['file'] == '01.png' && r1['scene'] == 'S1' &&
          r1['scene_index'] == 1 && r1['lane'] == 'image' &&
          r1['status'] == 'ok' && r1['width'] == 1200 &&
          r1['height'] == 900 && r1['annotation_tags_shown'] == ['WR-Dims'] &&
          !r1.key?('annotation_note')
    out << (ok1 ? 'mr1 ok' : "mr1 FAIL #{r1.inspect}")
    ok2 = r2['status'] == 'skipped' && r2['width'].nil? &&
          r2['height'].nil? && r2['annotation_tags_shown'].nil? &&
          r2['annotation_note'].to_s.include?('unreadable')
    out << (ok2 ? 'mr2 ok' : "mr2 FAIL #{r2.inspect}")
    ok3 = r3['status'] == 'lost' && r3['detail'].include?('lost row') &&
          r3['width'].nil?
    out << (ok3 ? 'mr3 ok' : "mr3 FAIL #{r3.inspect}")
    out << ((mr.map { |r| r['scene_index'] } == [1, 2, 3]) ?
              'mr4 ok' : 'mr4 FAIL export order not preserved')
    # 1.12.0 — groups_hidden rides the result row through to the manifest;
    # a row that never recorded it says null, never [].
    ok5 = r1['groups_hidden'] == ['R1 / Walls / Wall 2'] &&
          r2['groups_hidden'].nil? && r3['groups_hidden'].nil?
    out << (ok5 ? 'mr5 ok' : "mr5 FAIL #{mr.map { |r| r['groups_hidden'] }.inspect}")

    out.join(' | ')
  end
end

module WR_ExportScenes
%(height_consts)s

%(out_height)s
end

(begin
  WR_ProposalPackage.check
rescue Exception => e
  'FAIL ' + e.message
end).dup
'''

EXPECT = ('1 ok | 2 ok | 3 ok | 4 ok | 5 ok | 6 ok | 7 ok | 8 ok | 9 ok | '
          '10 ok | 11 ok | 12 ok | 13 ok | 14 ok | '
          '15 ok | 16 ok | 17 ok | 18 ok | 19 ok | 20 ok | '
          'forever ok | seq ok | '
          'cam1 ok | cam2 ok | cam3 ok | cam4 ok | cam5 ok | cam6 ok | '
          'ev1 ok | ev2 ok | ev3 ok | ev4 ok | ev5 ok | ev6 ok | ev7 ok | '
          'ev8 ok | sh1 ok | sh2 ok | sh3 ok | sh4 ok | ev-guard ok | '
          'mode1 ok | mode2 ok | mode3 ok | mode4 ok | '
          'size1 ok | size2 ok | size3 ok | '
          'h1 ok | h2 ok | h3 ok | h4 ok | '
          'sig-ok ok | sig-raise ok | sig-absent ok | '
          'auto1 ok | auto2 ok | auto3 ok | '
          'launch1 ok | launch2 ok | launch3 ok | launch4 ok | launch5 ok | '
          'launch6 ok | '
          # 1.9.6 -- the lifecycle half.
          'gate1 ok | gate2 ok | gate3 ok | gate4 ok | '
          'sum1 ok | sum2 ok | sum3 ok | lost1 ok | lost2 ok | lost3 ok | '
          'annot1 ok | annot2 ok | annot3 ok | annot4 ok | '
          'busy1 ok | busy2 ok | busy3 ok | '
          # 1.10.7 -- the manifest's pure half.
          'bn1 ok | bn2 ok | bn3 ok | bn4 ok | bn5 ok | bn6 ok | bn7 ok | '
          'dd1 ok | dd2 ok | dd3 ok | dd4 ok | dd5 ok | dd6 ok | '
          'st1 ok | st2 ok | st3 ok | st4 ok | '
          'mr1 ok | mr2 ok | mr3 ok | mr4 ok | mr5 ok')


def main():
    prog = FIXTURE % {
        'idle_state':  const_line('IDLE_STATE'),
        'done_state':  const_line('DONE_STATE'),
        'error_state': const_line('ERROR_STATE'),
        'cam_fields':  const_block('CAM_FIELDS'),
        'read_signal': rbtest.method_source(SRC, 'read_signal'),
        'classify':    rbtest.method_source(SRC, 'classify_render'),
        'cam_mismatch': rbtest.method_source(SRC, 'cam_mismatch'),
        # 'autorun' (not 'autorun?'): method_source appends \b, and ? gives
        # it no word boundary to land on. No other method starts 'autorun'.
        'autorun':     rbtest.method_source(SRC, 'autorun'),
        'launch':      rbtest.method_source(SRC, 'launch_decision'),
        'ev_consts':   '\n'.join(const_line(c) for c in
                                  ('EV_F_NUMBER', 'EV_ISO', 'EV_INTERIOR',
                                   'EV_ROOM', 'EV_MIN', 'EV_MAX', 'INTERIOR_RE')),
        'mode_fallback': const_line('MODE_FALLBACK'),
        'aspect':      '\n'.join(const_line(c) for c in ('ASPECT_W', 'ASPECT_H')),
        'ev_for':      rbtest.method_source(SRC, 'ev_for'),
        'shutter_for_ev': rbtest.method_source(SRC, 'shutter_for_ev'),
        'ev_of_camera':   rbtest.method_source(SRC, 'ev_of_camera'),
        'mode_restore_target': rbtest.method_source(SRC, 'mode_restore_target'),
        'package_size':   rbtest.method_source(SRC, 'package_size'),
        'height_consts':  '\n'.join(const_line(c, EXP) for c in
                                     ('HEIGHT_MIN', 'HEIGHT_MAX')),
        'out_height':     rbtest.method_source(EXP, 'out_height'),
        # 1.9.6 -- the lifecycle methods, lifted verbatim like everything
        # else, so editing proposal-package.rb edits what is tested.
        'honoured_size':     rbtest.method_source(SRC, 'honoured_size'),
        # 'require_render_size' (not '...!'): method_source appends \b and
        # ! gives it no word boundary. Same trick as autorun?.
        'require_render_size': rbtest.method_source(SRC, 'require_render_size'),
        'render_size_gate':  rbtest.method_source(SRC, 'render_size_gate'),
        'lost_rows':         rbtest.method_source(SRC, 'lost_rows'),
        'summary_lines':     rbtest.method_source(SRC, 'summary_lines'),
        'annot_push':        rbtest.method_source(SRC, 'annot_push'),
        'annot_pop':         rbtest.method_source(SRC, 'annot_pop'),
        'busy':              rbtest.method_source(SRC, 'busy'),
        # 1.10.7 -- the manifest's pure half.
        # 'booth_name' (not 'booth_name?'): method_source appends \b and ?
        # gives it no word boundary. Same trick as autorun?.
        'booth_name':        rbtest.method_source(SRC, 'booth_name'),
        'dim_display':       rbtest.method_source(SRC, 'dim_display'),
        'shown_annot_tags':  rbtest.method_source(SRC, 'shown_annot_tags'),
        'manifest_rows':     rbtest.method_source(SRC, 'manifest_rows'),
    }
    lib = rbparse.boot()
    got = rbparse.rb_eval(lib, prog)
    print('classify_render + read_signal + entry guards + exposure, mode '
          'restore and output shape (1.9.3)')
    print('  got      %s' % got)
    if got == EXPECT:
        print('  PASS - only :idleDone after a running state finishes,')
        print('         a cold renderer never does, unknown states keep')
        print('         running, raises become :raised, both-dead is')
        print('         :unreadable, an unsettled camera is a named mismatch,')
        print('         autorun runs unless suppressed, batch guard resets')
        print('         only on a confirmed stale flag, a render row is')
        print('         exposed from its own page, a never-toggled model is')
        print('         restored to draft instead of silently left in render,')
        print('         and an explicit output height beats the window')
        return 0
    print('  expected %s' % EXPECT)
    print('  FAIL')
    return 1


if __name__ == '__main__':
    sys.exit(main())
