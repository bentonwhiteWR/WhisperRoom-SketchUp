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
    seq_ended consulted before state                     -> case 2 FAIL
    :raised treated as finished (the old in_process? bug)-> case 6 FAIL

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


def const_line(name):
    """The verbatim defining line of a module-level constant."""
    for ln in open(SRC, encoding='utf-8').read().split('\n'):
        if re.match(r'^  %s\s*=' % re.escape(name), ln):
            return ln
    raise SystemExit('proposal-package.rb: no constant %s' % name)


FIXTURE = r'''
module WR_ProposalPackage
%(idle_state)s

%(read_signal)s

%(classify)s

  # Stub renderers for read_signal: one answers, one raises, one is bare.
  class RendOK
    def state; :idleInitialized; end
  end
  class RendRaises
    def state; raise StandardError, 'Incorrect DR version'; end
  end
  class RendBare; end

  CASES = [
    # [state_val, seq_ended, expected]
    [:idleInitialized, true,    :finished  ],  # 1 the observed cold sample
    [:rendering,       true,    :running   ],  # 2 state decides ALONE - an
                                               #   unknown state is running
                                               #   even if seq says ended
    [:idleDone,        false,   :finished  ],  # 3 /idle/i is a family match
    ['IDLEStopped',    :raised, :finished  ],  # 4 string state, any case
    [:preparing,       :raised, :running   ],  # 5 unknown + no backup
    [:raised,          :raised, :unreadable],  # 6 the in_process? disease on
                                               #   both signals at once
    [:raised,          true,    :finished  ],  # 7 backup signal decides
    [:raised,          false,   :running   ],  # 8 backup signal decides
    [nil,              nil,     :unreadable],  # 9 absent readings
  ]

  def self.check
    out = []
    CASES.each_with_index do |(st, seq, want), i|
      got = classify_render(st, seq)
      out << (got == want ? "#{i + 1} ok" : "#{i + 1} FAIL got #{got} want #{want}")
    end
    out << (read_signal(RendOK.new, :state) == :idleInitialized ?
              'sig-ok ok' : 'sig-ok FAIL')
    out << (read_signal(RendRaises.new, :state) == :raised ?
              'sig-raise ok' : 'sig-raise FAIL')
    out << (read_signal(RendBare.new, :state) == :raised ?
              'sig-absent ok' : 'sig-absent FAIL')
    out.join(' | ')
  end
end

(begin
  WR_ProposalPackage.check
rescue Exception => e
  'FAIL ' + e.message
end).dup
'''

EXPECT = ('1 ok | 2 ok | 3 ok | 4 ok | 5 ok | 6 ok | 7 ok | 8 ok | 9 ok | '
          'sig-ok ok | sig-raise ok | sig-absent ok')


def main():
    prog = FIXTURE % {
        'idle_state':  const_line('IDLE_STATE'),
        'read_signal': rbtest.method_source(SRC, 'read_signal'),
        'classify':    rbtest.method_source(SRC, 'classify_render'),
    }
    lib = rbparse.boot()
    got = rbparse.rb_eval(lib, prog)
    print('classify_render + read_signal: the render-completion verdict')
    print('  got      %s' % got)
    if got == EXPECT:
        print('  PASS - observed idle finishes, unknown states keep running,')
        print('         raises become :raised, both-dead is :unreadable')
        return 0
    print('  expected %s' % EXPECT)
    print('  FAIL')
    return 1


if __name__ == '__main__':
    sys.exit(main())
