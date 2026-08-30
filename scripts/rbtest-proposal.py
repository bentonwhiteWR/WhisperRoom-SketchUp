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
          'launch6 ok')


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
