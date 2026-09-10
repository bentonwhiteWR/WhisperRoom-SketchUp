# -*- coding: utf-8 -*-
"""RUN wr_tools/main.rb's preference layer outside SketchUp.

    python rbtest-panel-prefs.py

Same VM as rbtest.py (read its header). Every method is lifted VERBATIM from
scripts/wr_tools/main.rb on each run — main.rb's methods sit four spaces deep
inside `module WhisperRoom; module Tools`, hence the local method_source — so
the test cannot drift from the code. Sketchup.read_default/write_default are a
Hash here; nothing else is stubbed.

WHAT IS EXERCISED — the 1.46.0 shop-default rules:

  1. THE DAVE CASE. Three own slots, fifteen never-touched dashes, a full shop
     layout: his three stay where they are, the shop fills the rest, and each
     inherited seat wears the SHOP's icon while each own seat wears his.
  2. A never-touched user (no keys at all) sees the shop bar exactly.
  3. Deliberate clear: set_slot(i, nil, nil) on an inherited seat stores
     SLOT_CLEARED and the seat STAYS empty — the shop entry does not return.
  4. Editing one seat does not adopt the rest: after set_slot the own list
     still holds dashes elsewhere and inherited_slots still names them.
  5. toggle_pin on an inherited tool un-stars it (cleared, sticks); toggling
     again lands it in the first empty seat as the user's own.
  6. Reset: RESET in the three slot keys + ui_dev makes own_list empty, slots
     equal the shop bar, and read_pref('ui_dev') fall through to the shop.
  7. The fall-through rule itself: a key holding '' (empty list = a choice)
     does NOT fall through; RESET and UNSET do. RESET survives write_pref.
  8. Legacy: no 'slots' key, an old flat 'pinned' list -> own_slots from it.

CHECKED AGAINST ITSELF — reintroduce either and it reports FAIL:
    merge_slots: `if on[i] == SLOT_CLEARED` -> `if false`   (clear no longer sticks)
    read_pref:   `unless unset?(v)` -> `unless v.to_s == UNSET`   (reset ignored)
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rbparse  # noqa: E402

MAIN = os.path.join(HERE, 'wr_tools', 'main.rb')


def method_source(name):
    """`    def self.<name>` ... the first line that is exactly `    end`."""
    lines = open(MAIN, encoding='utf-8').read().split('\n')
    lines = [ln.rstrip('\r') for ln in lines]
    start = None
    for i, ln in enumerate(lines):
        if re.match(r'^    def self\.%s(?![\w?!])' % re.escape(name), ln):
            start = i
            break
    if start is None:
        raise SystemExit('main.rb: no method self.%s' % name)
    for j in range(start + 1, len(lines)):
        if lines[j] == '    end':
            return '\n'.join(lines[start:j + 1])
    raise SystemExit('main.rb: self.%s never closes' % name)


def const_source(name):
    """The one-line `    NAME = ...` definition, verbatim."""
    for ln in open(MAIN, encoding='utf-8').read().split('\n'):
        if re.match(r'^    %s = ' % re.escape(name), ln):
            return ln.rstrip('\r')
    raise SystemExit('main.rb: no constant %s' % name)


METHODS = ['unset?', 'read_pref', 'write_pref', 'read_list', 'write_list',
           'pad', 'blank?', 'merge_slots', 'own_list', 'own_slots', 'own_icons',
           'shop_list', 'shop_slots', 'slots', 'slot_icons', 'inherited_slots',
           'write_slots', 'set_slot', 'toggle_pin', 'pinned']
CONSTS = ['LIST_SEP', 'UNSET', 'RESET', 'SLOT_EMPTY', 'SLOT_CLEARED']

FIXTURE = r'''
# The minimal VM rbparse boots lacks some core conversions (rbtest.py shims
# Integer#to_f for the same reason). set_slot's `i.to_i` is fine in SketchUp.
class Integer
  def to_i; self; end
end

module Sketchup
  @store = {}
  def self.store; @store; end
  def self.reset!; @store = {}; end
  def self.read_default(sec, key, default = nil)
    @store.key?([sec, key.to_s]) ? @store[[sec, key.to_s]] : default
  end
  def self.write_default(sec, key, value)
    @store[[sec, key.to_s]] = value
    true
  end
end

module WhisperRoom
  module Tools
    PREF_KEY = 'WR_Tools'.freeze
    SLOT_N = 18
%(consts)s

    def self.shop; @shop_stub ||= {}; end
    def self.shop=(h); @shop_stub = h; end
    def self.shop_defaults; shop; end
    def self.refresh_fav_labels; nil; end

%(methods)s

    # ---- fixtures ---------------------------------------------------------
    BENTON = %%w[a.rb b.rb c.rb d.rb e.rb f.rb g.rb h.rb i.rb j.rb k.rb - m.rb k.rb o.rb - - -]
    BICONS = %%w[ia ib ic id ie if ig ih ii ij - - im in io - - -]

    def self.shop_benton!
      self.shop = { 'slots' => BENTON.join('|'), 'slot_icons' => BICONS.join('|'),
                    'pinned' => BENTON.reject { |n| blank?(n) }.join('|'),
                    'ui_dev' => 'true' }
    end

    def self.dave!
      Sketchup.reset!
      shop_benton!
      own = Array.new(SLOT_N, '-'); ic = Array.new(SLOT_N, '-')
      own[0] = 'dave1.rb'; ic[0] = 'x1'
      own[4] = 'dave2.rb'; ic[4] = '-'      # no icon picked: wears its own face
      own[11] = 'dave3.rb'; ic[11] = 'x3'   # a seat the shop leaves empty
      Sketchup.write_default(PREF_KEY, 'slots', own.join('|'))
      Sketchup.write_default(PREF_KEY, 'slot_icons', ic.join('|'))
      Sketchup.write_default(PREF_KEY, 'ui_dev', 'false')
    end

    def self.row(list); list.join(','); end

    def self.check
      out = []
      # 1. Dave
      dave!
      n = slots; ic = slot_icons
      out << '1 ' + row(n)
      out << '1i ' + row(ic)
      out << '1inh ' + row(inherited_slots)
      # 2. never touched
      Sketchup.reset!; shop_benton!
      out << '2 ' + ((slots == BENTON && slot_icons == BICONS) ? 'shop-exact' : 'MISMATCH ' + row(slots))
      # 3. deliberate clear of an inherited seat (seat 1 = b.rb)
      dave!
      set_slot(1, nil, nil)
      out << '3 seat1=' + slots[1] + ' own=' + own_slots[1] + ' icon=' + slot_icons[1]
      # 4. that edit adopted nothing else
      out << '4 own=' + row(own_slots) + ' inh=' + row(inherited_slots)
      # 5. un-star an inherited tool, then star it again
      dave!
      toggle_pin('c.rb')
      a = slots[2] + '/' + own_slots[2]
      toggle_pin('c.rb')
      free = own_slots.index('c.rb')
      out << '5 after-unstar=' + a + ' restar-seat=' + free.to_s + ' seen=' + slots[free] + ' pinned=' + pinned.size.to_s
      # 6. reset
      dave!
      %%w[slots slot_icons pinned ui_dev].each { |k| write_pref(k, RESET) }
      out << '6 own=' + own_list('slots').size.to_s + ' bar=' + (slots == BENTON ? 'shop-exact' : 'MISMATCH') +
             ' ui_dev=' + read_pref('ui_dev', 'false') + ' stored=' + Sketchup.read_default(PREF_KEY, 'slots').to_s
      # 7. fall-through rule
      Sketchup.reset!; shop_benton!
      Sketchup.write_default(PREF_KEY, 'ui_dev', '')
      empty = read_pref('ui_dev', 'fb')
      write_pref('ui_dev', RESET)
      reset = read_pref('ui_dev', 'fb')
      never = read_pref('nothing', 'fb')
      out << '7 empty=[' + empty + '] reset=' + reset + ' never=' + never +
             ' marker=' + (Sketchup.read_default(PREF_KEY, 'ui_dev') == RESET ? 'intact' : 'DAMAGED')
      # 8. legacy flat pinned
      Sketchup.reset!; self.shop = {}
      Sketchup.write_default(PREF_KEY, 'pinned', 'p.rb|q.rb')
      out << '8 ' + row(own_slots.first(3)) + ' seen=' + row(slots.first(3))
      out.join("\n")
    end
  end
end

(begin
  WhisperRoom::Tools.check
rescue Exception => e
  'FAIL ' + e.inspect + ' at ' + (e.backtrace || []).first.to_s   # e.class is absent in this VM
end).dup
'''

EXPECT = '\n'.join([
    # Dave's 0, 4, 11 stay; the shop fills 1-3, 5-10, 12-14; 15-17 nobody.
    '1 dave1.rb,b.rb,c.rb,d.rb,dave2.rb,f.rb,g.rb,h.rb,i.rb,j.rb,k.rb,dave3.rb,m.rb,k.rb,o.rb,-,-,-',
    '1i x1,ib,ic,id,-,if,ig,ih,ii,ij,-,x3,im,in,io,-,-,-',
    '1inh 1,2,3,5,6,7,8,9,10,12,13,14',
    '2 shop-exact',
    '3 seat1=- own=<cleared> icon=-',
    '4 own=dave1.rb,<cleared>,-,-,dave2.rb,-,-,-,-,-,-,dave3.rb,-,-,-,-,-,- inh=2,3,5,6,7,8,9,10,12,13,14',
    '5 after-unstar=-/<cleared> restar-seat=2 seen=c.rb pinned=15',
    '6 own=0 bar=shop-exact ui_dev=true stored=<<wr-shop-default>>',
    '7 empty=[] reset=true never=fb marker=intact',
    '8 p.rb,q.rb,- seen=p.rb,q.rb,-',
])


def main():
    prog = FIXTURE % {
        'consts': '\n'.join(const_source(c) for c in CONSTS),
        'methods': '\n\n'.join(method_source(m) for m in METHODS),
    }
    lib = rbparse.boot()
    got = rbparse.rb_eval(lib, prog)
    print('main.rb preference layer: per-position merge, deliberate clear, reset fall-through')
    ok = got == EXPECT
    if ok:
        for ln in got.split('\n'):
            print('  ok  ' + ln)
        print('PASS  %d checks' % len(EXPECT.split('\n')))
    else:
        exp = EXPECT.split('\n')
        for i, ln in enumerate(got.split('\n')):
            mark = 'ok ' if i < len(exp) and ln == exp[i] else 'BAD'
            print('  %s %s' % (mark, ln))
            if mark == 'BAD' and i < len(exp):
                print('      expected %s' % exp[i])
        print('FAIL')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
