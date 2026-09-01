# -*- coding: utf-8 -*-
"""REAL Ruby syntax check for the scripts in this folder. Not a heuristic.

    python rbparse.py              # every .rb here and in wr_tools/
    python rbparse.py foo.rb ...   # just these

Exit 0 when everything parses, 1 otherwise.

WHY THIS EXISTS, AND WHY rbcheck.py IS NOT ENOUGH
-------------------------------------------------
Every file in this repo used to be verified with `rbcheck.py`, which counts
brackets and `end`s. It is honest about being a heuristic, but the honesty gets
lost in the retelling: "rbcheck.py reports the file balanced" has been written
in commit messages as though it meant the file parses. It does not. A file can
balance perfectly and still be a syntax error --

    a = 1 +
    end

-- balanced brackets, balanced `end`s, and Ruby will not load it.

That gap is expensive here specifically. `wr_tools/main.rb` `load`s these
scripts live from the repo, and a SyntaxError descends from ScriptError, not
StandardError, so it slips past an ordinary rescue and the tool appears to do
nothing at all. Silence is the failure mode, so a real parser is the check.

HOW IT WORKS
------------
There is still no `ruby.exe` on this machine -- not on PATH, not in the
SketchUp install, and WSL has no distribution. But SketchUp 2024 ships the
complete CRuby 3.2 shared library:

    C:\\Program Files\\SketchUp\\SketchUp 2024\\x64-ucrt-ruby320.dll

This module loads that DLL with ctypes, boots a minimal VM (`ruby_setup` +
`ruby_init_loadpath`), and calls `RubyVM::InstructionSequence.compile` on each
file. That is a genuine parse by the very parser SketchUp itself will use, so a
clean run here means the file will load. It is the closest thing to `ruby -c`
this machine can offer, and it is not an approximation of one.

A clean run means the script PARSES. It still does not mean the script works.

Caveat worth knowing if you extend this: the minimal VM does not define every
core method -- `Object#class` and `RUBY_DESCRIPTION` are both absent -- so the
in-Ruby harness below deliberately formats errors with `e.message` only.
"""
import ctypes
import os
import sys

SU_DIR = r"C:\Program Files\SketchUp\SketchUp 2024"
DLL = "x64-ucrt-ruby320.dll"

HARNESS = '''
(begin
  src = File.binread(%r)
  src.force_encoding("UTF-8")
  RubyVM::InstructionSequence.compile(src, %r)
  "OK"
rescue Exception => e
  "FAIL " + e.message
end).dup
'''


def boot():
    """Load SketchUp's Ruby DLL and bring up a minimal VM."""
    dll = os.path.join(SU_DIR, DLL)
    if not os.path.exists(dll):
        raise SystemExit(
            "Ruby library not found:\n  %s\n\n"
            "This tool borrows SketchUp's own embedded Ruby. If SketchUp 2024 is\n"
            "installed elsewhere, edit SU_DIR at the top of this file." % dll)
    os.add_dll_directory(SU_DIR)
    lib = ctypes.CDLL(dll)

    argc = ctypes.c_int(1)
    argv_buf = (ctypes.c_char_p * 2)(b"rbparse", None)
    argv = ctypes.pointer(ctypes.cast(argv_buf, ctypes.POINTER(ctypes.c_char_p)))
    try:
        lib.ruby_sysinit(ctypes.byref(argc), argv)
    except Exception:
        pass

    lib.ruby_setup.restype = ctypes.c_int
    rc = lib.ruby_setup()
    if rc != 0:
        raise SystemExit("ruby_setup failed: %d" % rc)
    lib.ruby_init_loadpath()

    lib.rb_eval_string_protect.restype = ctypes.c_uint64
    lib.rb_eval_string_protect.argtypes = [ctypes.c_char_p,
                                           ctypes.POINTER(ctypes.c_int)]
    lib.rb_string_value_cstr.restype = ctypes.c_char_p
    lib.rb_string_value_cstr.argtypes = [ctypes.POINTER(ctypes.c_uint64)]
    return lib


# What a failed protected eval leaves behind, read back through `$!`. The
# exception's `inspect` carries its class name (`#<NameError: ...>`) without
# needing Object#class, which this minimal VM does not define -- the same
# reason HARNESS above formats with e.message only. Every branch rescues so
# the diagnostic itself can never be the thing that raises.
ERRINFO = '''
(begin
  e = $!
  if e.nil?
    "(no exception recorded)"
  else
    ins = (e.inspect rescue nil).to_s
    cls = ins =~ /\\A#<([A-Za-z0-9_:]+)[:>]/ ? Regexp.last_match(1) : "Exception"
    msg = (e.message rescue "(message unreadable)")
    bt  = ((e.backtrace || []).first rescue nil)
    bt ? "#{cls}: #{msg}\\n  at #{bt}" : "#{cls}: #{msg}"
  end
rescue Exception
  "(exception unreadable)"
end).dup
'''


def rb_eval(lib, src):
    st = ctypes.c_int(0)
    val = lib.rb_eval_string_protect(src.encode("utf-8"), ctypes.byref(st))
    if st.value != 0:
        # Surface the REAL Ruby exception. Until 1.19.3 this raised a bare
        # "the check harness itself raised inside Ruby", which is how
        # rbtest-lights.py sat red for two weeks over an unlifted constant
        # nobody could see the name of.
        st2 = ctypes.c_int(0)
        dv = lib.rb_eval_string_protect(ERRINFO.encode("utf-8"), ctypes.byref(st2))
        detail = "(exception unreadable)"
        if st2.value == 0:
            d = ctypes.c_uint64(dv)
            detail = lib.rb_string_value_cstr(ctypes.byref(d)).decode("utf-8", "replace")
        raise RuntimeError("the check harness itself raised inside Ruby -- " + detail)
    v = ctypes.c_uint64(val)
    return lib.rb_string_value_cstr(ctypes.byref(v)).decode("utf-8", "replace")


def targets(args):
    if args:
        return args
    here = os.path.dirname(os.path.abspath(__file__))
    out = []
    for d in (here, os.path.join(here, "wr_tools")):
        if os.path.isdir(d):
            out += [os.path.join(d, f) for f in sorted(os.listdir(d))
                    if f.lower().endswith(".rb")]
    return out


def main():
    files = targets(sys.argv[1:])
    if not files:
        print("no .rb files to check")
        return 0
    lib = boot()
    bad = []
    for f in files:
        rb = os.path.abspath(f).replace("\\", "/")
        out = rb_eval(lib, HARNESS % (rb, rb))
        short = os.path.basename(rb)
        if out == "OK":
            print("ok    %s" % short)
        else:
            bad.append(short)
            print("FAIL  %s" % short)
            for ln in out.splitlines():
                print("      " + ln)
    print("")
    if bad:
        print("%d of %d file(s) DO NOT PARSE: %s" %
              (len(bad), len(files), ", ".join(bad)))
    else:
        print("%d file(s) parse. (Parsing is not working -- run it.)" % len(files))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
