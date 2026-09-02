# -*- coding: utf-8 -*-
"""How many times does refresh_fav_labels scan the scripts folder?

Lifts favourite_at and refresh_fav_labels verbatim out of main.rb, runs them
under SketchUp's own Ruby (scripts/rbparse.py boots the DLL) against 18 stub
toolbar commands and a scan() that counts itself, and prints the count -- for
the committed main.rb (git show <rev>) and for the working tree.

    python .forge/builder/panel-overhaul/rbtest-refresh.py [rev]

Audit A11 / spec slice 4: a star click used to cost 18 scans; it must be 1.
"""
import os, re, subprocess, sys
ROOT = "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp"
sys.path.insert(0, ROOT + "/scripts")
import rbparse

def method(src, name):
    m = re.search(r"    def self\.%s\b.*?\n    end\n" % re.escape(name), src, re.S)
    assert m, name
    body = m.group(0)
    # The method swallows everything; with --raise the real exception surfaces.
    if "--raise" in sys.argv:
        body = body.replace("    rescue StandardError\n      nil\n    end\n", "    end\n")
    return body

def harness(src):
    return '''
module WhisperRoom
  module Tools
    SLOT_EMPTY = '-'
    SLOT_N = 18
    @scan_calls = 0
    def self.scan
      @scan_calls += 1
      (0...18).map { |i| { 'name' => "s#{i}.rb", 'title' => "T#{i}", 'file' => "f#{i}" } }
    end
    def self.scan_calls; @scan_calls; end
    def self.slots; (0...18).map { |i| (i %% 2 == 0) ? "s#{i}.rb" : SLOT_EMPTY }; end
    def self.blank?(v); v.nil? || v.to_s.empty? || v.to_s == SLOT_EMPTY; end
    def self.slot_label(i); "L#{i}"; end
    def self.slot_icon_path(i); "no-such-file.svg"; end
    class Cmd; attr_accessor :tooltip, :status_bar_text, :small_icon, :large_icon; end
    @fav_cmds = Array.new(18) { Cmd.new }
    @toolbars = []
    def self.cmds; @fav_cmds; end
%s
%s
  end
end
WhisperRoom::Tools.refresh_fav_labels
tips = WhisperRoom::Tools.cmds.map(&:tooltip)
"scan calls: #{WhisperRoom::Tools.scan_calls}; filled tooltips: #{tips.count { |t| t =~ /\\AT\\d+  \\(L\\d+\\)\\z/ }}; empty: #{tips.count { |t| t =~ /empty/ }}"
''' % (method(src, "favourite_at"), method(src, "refresh_fav_labels"))

args = [a for a in sys.argv[1:] if not a.startswith("--")]
rev = args[0] if args else "HEAD"
old = subprocess.run(["git", "-C", ROOT, "show", "%s:scripts/wr_tools/main.rb" % rev],
                     capture_output=True, text=True, encoding="utf-8").stdout
new = open(ROOT + "/scripts/wr_tools/main.rb", encoding="utf-8").read()
lib = rbparse.boot()
# Each run lives in its own module name so the two definitions cannot mix.
print("%-14s %s" % (rev + ":", rbparse.rb_eval(lib, harness(old).replace("WhisperRoom", "WRold"))))
print("%-14s %s" % ("working tree:", rbparse.rb_eval(lib, harness(new).replace("WhisperRoom", "WRnew"))))
