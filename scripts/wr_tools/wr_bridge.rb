# WhisperRoom Bridge — a resident job listener inside SketchUp.
#
# WHAT IT IS FOR
#
# SketchUp has no command line and no remote control. Every check on a tool that
# needs a live model — does the room build, does the light land, does the scene
# export — has been a human clicking through the Ruby Console and eyeballing the
# result. scripts/rbtest-*.py covers the PURE half of the Ruby logic outside
# SketchUp. This is the impure complement: it runs a job INSIDE the running
# application and hands back stdout, the return value, and any exception with its
# backtrace, so those checklists can become assertions.
#
# OFF BY DEFAULT, AND THAT IS DELIBERATE. A resident poller in the daily-driver
# SketchUp should exist only when somebody asked for it. On load this file looks
# for an `enabled` marker in the bridge root. No marker: no timer, no polling,
# nothing resident but two menu items.
#
# HOW IT WORKS — a file-drop protocol over a directory pair
#
# No sockets, no HTTP, no threads. SketchUp's Ruby is single-threaded and its
# only safe scheduler is UI.start_timer, which is already this codebase's polling
# idiom (scripts/proposal-package.rb's `step`). The listener is a repeating timer
# that claims one job per tick, evaluates it, and writes one result file.
#
#     %LOCALAPPDATA%\WhisperRoom\bridge\SketchUp 2026\
#         enabled     marker — no marker, no polling (one switch for every window)
#         art/        default sink for job-written PNGs (shared)
#         bridge.log  one line per job, tagged with the listener's pid
#         inst-<pid>/ ONE SLOT PER SKETCHUP PROCESS (1.85.0)
#             alive       heartbeat, rewritten first thing every tick
#             model.json  the active model's title/path/guid, rewritten on change
#             stopped     present while this listener is stopped
#             in/         <id>.job.json      the client writes
#             run/        <id>.job.rb, <id>.running    the listener owns
#             out/        <id>.result.json   the listener writes, the client reads
#         in/ run/ out/  the pre-1.85 shared inbox, still served — see below
#
# TWO FILES OPEN AT ONCE (1.85.0). Every SketchUp of one version used to poll
# the same in/, so with two files open a job ran in whichever window claimed it
# first. Now each process polls only its own inst-<pid>/ slot and publishes
# which file it has open; the client resolves `--model <path|fragment>` to
# exactly one slot, or refuses and lists the open files. With one window open
# and no --model nothing changes for the caller. The job also carries the
# `target` model it was resolved against, and run_job re-checks active_model
# before any job code runs, so a window that switched files in between refuses
# (status refused, reason wrong-model) instead of running on the wrong drawing.
# The shared in/ is still served for an OLD client, but only while this is the
# only listening window; with two it refuses the job as ambiguous-target.
#
# %LOCALAPPDATA% and never OneDrive: a synced folder puts a second writer and a
# replication delay into exactly the read this whole protocol depends on. A
# per-version subfolder because 2024 and 2026 are both installed here and would
# otherwise poll the same inbox and race for the same job. WR_BRIDGE_DIR
# overrides the lot; both sides read it.
#
# THE THREE PROPERTIES EVERY DECISION BELOW SERVES
#
# 1. A HALF-WRITTEN RESULT MUST BE UNREADABLE, NOT MISREAD. This is the failure
#    that would silently poison every future test: a truncated file parsed as a
#    real answer. So the result is written to <id>.result.tmp and File.rename'd
#    into place — atomic to a reader within one directory on NTFS — and it
#    carries `complete` as its LAST key, which the client requires. A truncated
#    file fails JSON parse; a JSON-valid file without `complete` is corrupt, and
#    is never a result.
#
# 2. A BLOCKED JOB MUST NEVER READ AS A PASS. Nothing here can time a job out:
#    single-threaded, no preemption — once eval is running, the timer does not
#    run either. All timeout enforcement is the client's. What this side does is
#    stop the modal happening at all: for the job's extent UI.messagebox and its
#    friends RAISE instead of opening, so a prompting tool fails by name with a
#    backtrace instead of freezing SketchUp for a human to find.
#
# 3. NOTHING THE BRIDGE DOES CAN DAMAGE REAL WORK. See `check_write`. Note the
#    honest limit stated there: this is a guardrail against accident, NOT a
#    sandbox. It fences the SketchUp APIs a job realistically uses. It does not
#    fence a bare File.write, and nothing here should ever be mistaken for a
#    security boundary — jobs are this repo's own code, run at the agent's
#    request.
#
# EDITING THIS FILE COSTS A REINSTALL AND A RESTART. wr_tools/ is read from the
# INSTALLED plugin folder (CLAUDE.md). That is why the listener stays small and
# why anything expected to churn — assertion helpers, capture wrappers, scratch
# model builders — lives in scripts/wr-bridge-lib.rb, which sits in SCRIPTS_DIR
# and is therefore read LIVE from the repo checkout. Iterating on test logic
# needs no reinstall; iterating on the protocol does.

require 'sketchup.rb'
require 'json'

module WhisperRoom
  module Bridge

    # Raised in place of a modal dialog. A prompting tool then fails by name,
    # with a backtrace naming the line that tried to prompt, instead of parking
    # a dialog in front of a SketchUp nobody is sitting at.
    class ModalBlocked < StandardError; end

    # Raised by a write fence. See check_write.
    class Forbidden < StandardError; end

    POLL_S   = 0.25          # four globs a second on a small directory is free
    CAP      = 256 * 1024    # per-stream capture cap
    MAX_DEPTH = 6            # how deep a return value may nest and stay verbatim

    # 24 -> "SketchUp 2024", 26 -> "SketchUp 2026". Sketchup.version is
    # "26.0.100"-shaped; its major has tracked the year since 2013.
    def self.version_name
      "SketchUp 20#{Sketchup.version.to_i}"
    end

    def self.root
      env = ENV['WR_BRIDGE_DIR']
      return env.tr('\\', '/') if env && !env.empty?
      base = ENV['LOCALAPPDATA'].to_s.tr('\\', '/')
      File.join(base, 'WhisperRoom', 'bridge', version_name)
    end

    # The VERSION root: enabled, art/, bridge.log. Shared by every window.
    def self.dir(*parts)
      File.join(root, *parts)
    end

    # ------------------------------------------------------------ the slot --
    #
    # ONE SLOT PER PROCESS, named by pid. A single process only ever has one
    # active_model, so a slot never has to say which of its windows a job is
    # for; and if SketchUp ever hosts two files in one process, the target
    # check in run_job still refuses a job for the file that is not active.

    SLOT_PREFIX   = 'inst-'
    PEER_FRESH_S  = 5.0            # a peer heartbeat younger than this is listening
    SWEEP_AFTER_S = 24 * 3600      # a peer slot silent this long is a relic

    def self.slot_name
      "#{SLOT_PREFIX}#{Process.pid}"
    end

    def self.slot_root
      File.join(root, slot_name)
    end

    def self.slot(*parts)
      File.join(slot_root, *parts)
    end

    # Where the job being run lives: this slot, or the version root for a job
    # that came in through the pre-1.85 shared inbox. Set for one job only.
    def self.box(*parts)
      File.join(@box || slot_root, *parts)
    end

    def self.enabled?
      File.exist?(dir('enabled'))
    end

    def self.ensure_tree
      require 'fileutils'
      [root, dir('art'), dir('in'), dir('run'), dir('out'),
       slot_root, slot('in'), slot('run'), slot('out')].each do |d|
        FileUtils.mkdir_p(d) unless File.directory?(d)
      end
      root
    end

    def self.log(line)
      File.open(dir('bridge.log'), 'a') do |f|
        f.write("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}  [#{Process.pid}] #{line}\n")
      end
    rescue Exception
      nil
    end

    # Write a small file so a reader sees the old content or the new, never a
    # half. Ruby's rename on Windows replaces an existing target; the delete
    # fallback is for an antivirus or indexer briefly holding the old one.
    def self.atomic_write(path, text)
      tmp = path + '.tmp'
      File.open(tmp, 'wb') { |f| f.write(text) }
      begin
        File.rename(tmp, path)
      rescue Exception
        begin; File.delete(path); rescue Exception; nil; end
        File.rename(tmp, path)
      end
    end

    # The slot's identity card: which file this process has open. Rewritten
    # only when it changes (or goes missing), not four times a second.
    def self.publish_identity
      m = model_hash
      key = JSON.generate(m)
      return if key == @identity_key && File.exist?(slot('model.json'))
      card = m.merge('pid' => Process.pid,
                     'sketchup' => scrub(Sketchup.version.to_s),
                     'plugin' => plugin_version,
                     'updated' => stamp(Time.now))
      atomic_write(slot('model.json'), JSON.generate(card))
      @identity_key = key
    rescue Exception
      nil
    end

    # Every OTHER slot whose heartbeat is fresh: [{name, title, path}].
    def self.live_peers
      now = Time.now
      Dir.glob(File.join(root, "#{SLOT_PREFIX}*")).map do |d|
        name = File.basename(d)
        next nil if name == slot_name || !File.directory?(d)
        age = (now - File.mtime(File.join(d, 'alive')) rescue nil)
        next nil unless age && age < PEER_FRESH_S
        card = (JSON.parse(File.read(File.join(d, 'model.json'))) rescue {})
        { 'name' => name, 'title' => card['title'].to_s, 'path' => card['path'].to_s }
      end.compact
    rescue Exception
      []
    end

    def self.same_path?(a, b)
      a.to_s.tr('\\', '/').downcase == b.to_s.tr('\\', '/').downcase
    end

    # Nil when the job may run here; otherwise [reason, sentence].
    #
    # THE TARGET CHECK. The client resolved this job against the model.json it
    # read a moment ago. If the window has since opened another file, the path
    # (or, for an untitled model, the guid) no longer matches and the job is
    # refused before any of its code runs.
    def self.target_refusal(job)
      t = job['target']
      if t.is_a?(Hash)
        now = model_hash
        want_p = t['path'].to_s
        ok = if !want_p.empty?
               same_path?(want_p, now['path'])
             else
               now['path'].to_s.empty? &&
                 (t['guid'].to_s.empty? || t['guid'].to_s == now['guid'].to_s)
             end
        return nil if ok
        return ['wrong-model',
                "this job was addressed to #{t['title'].to_s.inspect} " \
                "(#{want_p.empty? ? 'untitled' : want_p}) but this SketchUp " \
                "(pid #{Process.pid}) now has #{now['title'].to_s.inspect} " \
                "(#{now['path'].to_s.empty? ? 'untitled' : now['path']}) open. " \
                'The window switched files after the client resolved it. ' \
                'Run `python scripts/sketchup-bridge.py ping` and resubmit.']
      end

      # An untargeted job from the shared inbox is a pre-1.85 client. It is
      # only safe while this is the one window listening.
      if @box && @box == root
        peers = live_peers
        unless peers.empty?
          files = ([model_hash] + peers).map do |p|
            "#{p['title'].inspect} #{p['path'].to_s.empty? ? '(untitled)' : p['path']}"
          end
          return ['ambiguous-target',
                  "#{peers.length + 1} SketchUp windows are listening and this job " \
                  'names no model, so it could land on the wrong one. Open files: ' +
                  files.join('; ') + '. Update the client (git pull) and pass ' \
                  '--model <path or file-name fragment>.']
        end
      end
      nil
    end

    # ------------------------------------------------------------- the tee --
    #
    # $stdout is SWAPPED FOR A TEE, NOT REPLACED, and that is the whole point of
    # the design. Everything still reaches the Ruby Console, so a human watching
    # sees the normal picture — and if some output source inside SketchUp turns
    # out to bypass $stdout, the cost is an UNRECORDED line, not a LOST one.
    #
    # A plain duck-typed object with a `write` method does capture Kernel#puts in
    # SketchUp's own CRuby 3.2 (probed against x64-ucrt-ruby320.dll before this
    # was written). `puts` and the rest are implemented anyway, because a script
    # that calls $stdout.puts directly should not hit method_missing, and
    # method_missing forwards the remainder — $stdout.clear still reaches
    # Sketchup::Console.
    class Tee
      attr_reader :dropped

      def initialize(inner, cap = CAP)
        @inner   = inner
        @cap     = cap
        @buf     = ''.dup
        @dropped = 0
      end

      def text
        return @buf if @dropped.zero?
        @buf + "\n[...truncated #{@dropped} bytes]"
      end

      def record(s)
        s = s.to_s
        room = @cap - @buf.bytesize
        if room <= 0
          @dropped += s.bytesize
        elsif s.bytesize <= room
          @buf << s
        else
          @buf << s.byteslice(0, room)
          @dropped += s.bytesize - room
        end
      end
      private :record

      def write(*args)
        n = 0
        args.each do |a|
          s = a.to_s
          n += s.bytesize
          record(s)
        end
        begin
          @inner.write(*args)
        rescue Exception
          nil
        end
        n
      end

      def <<(s)
        write(s)
        self
      end

      def print(*args)
        args.each { |a| write(a) }
        nil
      end

      def printf(fmt, *args)
        write(format(fmt, *args))
        nil
      end

      # Kernel#puts semantics: no args is one newline; an array is flattened;
      # a string already ending in a newline does not get a second one.
      def puts(*args)
        if args.empty?
          write("\n")
          return nil
        end
        args.each do |a|
          if a.is_a?(Array)
            a.empty? ? write("\n") : puts(*a)
          else
            s = a.nil? ? '' : a.to_s
            write(s.end_with?("\n") ? s : s + "\n")
          end
        end
        nil
      end

      def flush;      self; end
      def sync;       true; end
      def sync=(v);   v;    end
      def tty?;       false; end
      def isatty;     false; end
      def close;      nil;  end
      def closed?;    false; end

      def respond_to_missing?(name, priv = false)
        @inner.respond_to?(name, priv) || super
      end

      def method_missing(name, *args, &blk)
        if @inner.respond_to?(name)
          @inner.send(name, *args, &blk)
        else
          super
        end
      end
    end

    # ------------------------------------------------------- write fencing --
    #
    # THIS IS A GUARDRAIL, NOT A SANDBOX. It fences the SketchUp APIs a job
    # realistically uses to put bytes on disk — Model#save, #save_copy,
    # #save_thumbnail, View#write_image. It does NOT fence a bare File.write,
    # and no reading of it should treat it as a security boundary. Jobs are this
    # repo's own code, run at the agent's request; the fence exists so an
    # accident cannot reach finished client work.

    DENY_PATTERNS = [
      %r{/desktop/proposalfiles(/|\z)},
      %r{\Ap:/},
      %r{/whisperroomquote(/|\z)}
    ].freeze

    def self.norm(path)
      File.expand_path(path.to_s).tr('\\', '/').downcase
    end

    # Nil unless the path is refused; otherwise the sentence saying why.
    def self.write_refusal(path)
      p = norm(path)

      DENY_PATTERNS.each do |re|
        if p =~ re
          return "#{path}\nis on the bridge's absolute deny list " \
                 "(ProposalFiles, the P: share, and any WhisperRoomQuote folder " \
                 'are read-only to this bridge — no job option overrides it).'
        end
      end

      allowed = [root, ENV['TEMP'], ENV['TMP']].compact.reject(&:empty?)
      allowed += (@write_roots || [])
      allowed = allowed.map { |a| norm(a) }

      return nil if allowed.any? { |a| p == a || p.start_with?(a + '/') }

      "#{path}\nis outside every directory this job may write to. Allowed: " +
        allowed.join(', ') +
        ". Add one with the job's write_roots, or write into the bridge's art/ folder."
    end

    def self.check_write(path)
      why = write_refusal(path)
      raise Forbidden, why if why
      @artifacts << File.expand_path(path.to_s).tr('\\', '/') if @artifacts
      path
    end

    # --------------------------------------------------------- API patches --
    #
    # Captured as aliases and restored in an ensure. The `unless already` guard
    # matters: if a restore were ever missed, re-aliasing would capture the
    # PATCHED method as the original and the patch would become permanent for
    # the session — a bridge that quietly broke UI.messagebox for the human
    # sitting in front of it.

    MODALS = [:messagebox, :inputbox, :openpanel, :savepanel, :select_directory].freeze

    def self.patch_modals
      sc = UI.singleton_class
      @modal_patched = []
      MODALS.each do |m|
        next unless UI.respond_to?(m)
        saved = :"wr_bridge_orig_#{m}"
        sc.send(:alias_method, saved, m) unless sc.method_defined?(saved) ||
                                                sc.private_method_defined?(saved)
        sc.send(:define_method, m) do |*args, &_blk|
          shown = args.map { |a| a.inspect }.join(', ')
          raise WhisperRoom::Bridge::ModalBlocked,
                "UI.#{m}(#{shown}) — a job tried to open a modal dialog. The " \
                'bridge blocks these so SketchUp cannot freeze waiting for a ' \
                'click nobody is there to give. Pass modal:"allow" if a human ' \
                'is sitting in front of SketchUp and means to answer it.'
        end
        @modal_patched << [m, saved]
      end
    end

    def self.unpatch_modals
      sc = UI.singleton_class
      (@modal_patched || []).each { |(m, saved)| sc.send(:alias_method, m, saved) }
      @modal_patched = nil
    end

    def self.patch_writers
      @writer_patched = []

      { Sketchup::Model => [:save, :save_copy, :save_thumbnail],
        Sketchup::View  => [:write_image] }.each do |klass, names|
        names.each do |m|
          next unless klass.method_defined?(m)
          saved = :"wr_bridge_orig_#{m}"
          unless klass.method_defined?(saved) || klass.private_method_defined?(saved)
            klass.send(:alias_method, saved, m)
          end
          @writer_patched << [klass, m, saved]
        end
      end

      # SAVE IN PLACE ALWAYS RAISES. Not "check the path" — there is no path to
      # check, and overwriting the drawing somebody has open is the one thing
      # this bridge must never be able to do. Named models are allowed to be
      # RUN against (Benton, 30 Aug 2026); they are not allowed to be written.
      [:save, :save_copy].each do |m|
        next unless Sketchup::Model.method_defined?(:"wr_bridge_orig_#{m}")
        Sketchup::Model.send(:define_method, m) do |*args|
          if args.empty? || args.first.to_s.empty?
            raise WhisperRoom::Bridge::Forbidden,
                  "Sketchup::Model##{m} with no path saves over the model that is " \
                  'open. The bridge never does that — a job may read and modify a ' \
                  'model in memory, but the file on disk is not its to overwrite.'
          end
          WhisperRoom::Bridge.check_write(args.first)
          send(:"wr_bridge_orig_#{m}", *args)
        end
      end

      if Sketchup::Model.method_defined?(:wr_bridge_orig_save_thumbnail)
        Sketchup::Model.send(:define_method, :save_thumbnail) do |*args|
          WhisperRoom::Bridge.check_write(args.first) unless args.empty?
          send(:wr_bridge_orig_save_thumbnail, *args)
        end
      end

      # write_image takes either a filename or an options hash carrying
      # :filename. Both reach the same fence.
      if Sketchup::View.method_defined?(:wr_bridge_orig_write_image)
        Sketchup::View.send(:define_method, :write_image) do |*args|
          first = args.first
          target = first.is_a?(Hash) ? (first[:filename] || first['filename']) : first
          WhisperRoom::Bridge.check_write(target) if target
          send(:wr_bridge_orig_write_image, *args)
        end
      end
    end

    def self.unpatch_writers
      (@writer_patched || []).each do |(klass, m, saved)|
        klass.send(:alias_method, m, saved)
      end
      @writer_patched = nil
    end

    # ------------------------------------------------- value serialisation --
    #
    # ENCODING THE RETURN VALUE MUST NEVER BE ABLE TO RAISE, because that would
    # turn a job that passed into a result the client reports as a failure — or
    # worse, into no result file at all. Anything not JSON-native becomes null
    # with an honest value_class and a truncated inspect in value_repr.
    #
    # Every string is scrubbed first. SketchUp on Windows hands back model
    # titles and file paths that are not valid UTF-8, and to_json raises on
    # those.

    def self.scrub(s)
      s.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
    rescue Exception
      '?'
    end

    def self.json_safe(v, depth = 0)
      return :__unsafe__ if depth > MAX_DEPTH
      case v
      when nil, true, false then v
      when Integer          then v
      when Float            then (v.finite? ? v : :__unsafe__)
      when String           then scrub(v)
      when Symbol           then scrub(v.to_s)
      when Array
        out = []
        v.each do |x|
          e = json_safe(x, depth + 1)
          return :__unsafe__ if e == :__unsafe__
          out << e
        end
        out
      when Hash
        out = {}
        v.each do |k, x|
          e = json_safe(x, depth + 1)
          return :__unsafe__ if e == :__unsafe__
          out[scrub(k.to_s)] = e
        end
        out
      else
        :__unsafe__
      end
    rescue Exception
      :__unsafe__
    end

    def self.repr(v)
      s = scrub(v.inspect)
      s.bytesize > 8192 ? s.byteslice(0, 8192) + ' […truncated]' : s
    rescue Exception => e
      "<inspect raised #{e.class}>"
    end

    def self.error_hash(e, depth = 0)
      return nil if e.nil?
      h = {
        'class'     => scrub(e.class.name),
        'message'   => scrub(e.message),
        'backtrace' => (e.backtrace || []).first(60).map { |l| scrub(l) }
      }
      begin
        h['cause'] = (depth < 3 ? error_hash(e.cause, depth + 1) : nil)
      rescue Exception
        h['cause'] = nil
      end
      h
    rescue Exception
      { 'class' => 'UnreportableError', 'message' => '', 'backtrace' => [], 'cause' => nil }
    end

    def self.stamp(t)
      t.strftime('%Y-%m-%dT%H:%M:%S.') + format('%03d', (t.usec / 1000)) + t.strftime('%z')
    end

    def self.plugin_version
      @plugin_version ||= begin
        File.read(File.join(File.dirname(__FILE__), 'VERSION')).strip
      rescue Exception
        'unknown'
      end
    end

    def self.env_hash
      {
        'sketchup' => scrub(Sketchup.version.to_s),
        'ruby'     => scrub(RUBY_VERSION),
        'plugin'   => plugin_version,
        'os'       => (Sketchup.platform.to_s rescue 'unknown'),
        'bridge'   => scrub(root),
        'pid'      => Process.pid,
        'slot'     => scrub(box)
      }
    rescue Exception
      { 'sketchup' => '?', 'ruby' => '?', 'plugin' => '?', 'os' => '?', 'bridge' => '?',
        'pid' => nil, 'slot' => '?' }
    end

    def self.model_hash
      m = Sketchup.active_model
      return { 'title' => '', 'path' => '', 'guid' => '' } unless m
      { 'title' => scrub(m.title.to_s),
        'path'  => scrub(m.path.to_s),
        'guid'  => scrub((m.guid rescue '').to_s) }
    rescue Exception
      { 'title' => '?', 'path' => '?', 'guid' => '?' }
    end

    # THE LAST KEY WRITTEN IS `complete`, AND THE CLIENT REQUIRES IT. Combined
    # with the rename this is the whole answer to "a half-written result read as
    # a complete one": a truncated file cannot parse, and a file that parses but
    # has no `complete` is reported as corrupt rather than as an answer.
    def self.write_result(id, h)
      h = h.dup
      h.delete('complete')
      h['complete'] = true

      json = begin
        JSON.generate(h)
      rescue Exception => e
        # The serialise step is itself wrapped: there is ALWAYS a result file,
        # even when building the real one failed.
        JSON.generate(
          'id' => id.to_s, 'status' => 'error',
          'stdout' => '', 'stderr' => '',
          'value' => nil, 'value_class' => 'NilClass', 'value_repr' => '',
          'error' => { 'class' => 'BridgeSerialisationError',
                       'message' => "the job ran, but its result could not be encoded: " \
                                    "#{e.class}: #{e.message}",
                       'backtrace' => [], 'cause' => nil },
          'artifacts' => [], 'complete' => true
        )
      end

      tmp  = box('out', "#{id}.result.tmp")
      fin  = box('out', "#{id}.result.json")
      File.open(tmp, 'wb') { |f| f.write(json) }
      File.rename(tmp, fin)
    rescue Exception => e
      log("RESULT WRITE FAILED #{id}: #{e.class}: #{e.message}")
    end

    # ------------------------------------------------------------ the tick --

    def self.tick
      # THE HEARTBEAT IS THE FIRST THING, ALWAYS. It is what separates "SketchUp
      # is not there" from "SketchUp is wedged", and it must never be skipped by
      # a job's own failure.
      begin
        File.open(slot('alive'), 'wb') { |f| f.write(stamp(Time.now)) }
      rescue Exception
        # The slot was swept or deleted from outside: rebuild it rather than
        # go silently invisible for the rest of the session.
        begin; ensure_tree; rescue Exception; nil; end
      end
      publish_identity

      # The marker is re-read every tick so `disable` takes effect at once, from
      # the menu or from outside. The reverse — a marker appearing while nothing
      # polls — needs a restart, and the client says so.
      unless enabled?
        stop
        return
      end

      return if @busy
      @busy = true
      begin
        claim_and_run
      rescue Exception => e
        log("TICK FAILED: #{e.class}: #{e.message}")
      ensure
        @busy = false
      end
    end

    # This slot's inbox first, then the pre-1.85 shared one (target_refusal
    # decides whether a shared-inbox job may run here).
    def self.claim_and_run
      [slot_root, root].each do |b|
        jobs = Dir.glob(File.join(b, 'in', '*.job.json'))
        next if jobs.empty?
        path = jobs.min_by { |p| File.mtime(p) rescue Time.now }

        # CLAIM BY RENAME. A second listener — another window on the shared
        # inbox, a stale session — loses the race instead of running the job a
        # second time.
        id    = File.basename(path, '.job.json')
        claim = File.join(b, 'run', "#{id}.job.json")
        begin
          File.rename(path, claim)
        rescue Exception
          next                      # somebody else got it; nothing to report
        end

        @box = b
        begin
          run_job(id, claim)
        ensure
          @box = nil
        end
        return
      end
    end

    def self.run_job(id, claim)
      started = Time.now
      job = nil

      begin
        job = JSON.parse(File.read(claim))
      rescue Exception => e
        return refuse(id, started, 'bad-job-json',
                      "the job file did not parse as JSON: #{e.class}: #{e.message}")
      end

      src = job['ruby'].to_s
      if src.strip.empty?
        return refuse(id, started, 'empty-job', 'the job carried no Ruby source.')
      end

      # Before ANY job code: is this still the model the job was addressed to?
      wrong = begin
        target_refusal(job)
      rescue Exception => e
        ['target-check', "the target check itself failed: #{e.class}: #{e.message}"]
      end
      return refuse(id, started, wrong[0], wrong[1]) if wrong

      # NAMED MODELS ARE ALLOWED (Benton, 30 Aug 2026 — this overrides the
      # spec's pre-flight refusal). A job may run against a real drawing that is
      # open. What stays, in full, is every WRITE fence: no save over any model,
      # and the absolute deny list still governs write_image and every
      # bridge-mediated write. Running against a real drawing is fine;
      # overwriting one is not.

      rb_path = box('run', "#{id}.job.rb")
      running = box('run', "#{id}.running")
      begin
        File.open(rb_path, 'wb') { |f| f.write(src) }
        File.open(running, 'wb') do |f|
          f.write(JSON.generate('id' => id,
                                'label' => scrub(job['label'].to_s),
                                'started' => stamp(started)))
        end
      rescue Exception => e
        return refuse(id, started, 'bridge-io',
                      "could not stage the job on disk: #{e.class}: #{e.message}")
      end

      @write_roots = Array(job['write_roots']).map { |r| r.to_s }.reject(&:empty?)
      @artifacts   = []

      out = Tee.new($stdout)
      err = Tee.new($stderr)
      was_out, was_err = $stdout, $stderr
      was_no, was_sup  = $wr_no_autorun, $wr_suppress_autorun
      suppress = job.key?('suppress_autorun') ? !!job['suppress_autorun'] : true
      modal    = (job['modal'] || 'raise').to_s

      value  = nil
      raised = nil

      begin
        $stdout, $stderr = out, err
        # BOTH GLOBALS, for the reason main.rb's load_quietly gives: the scripts
        # disagree about the spelling — auto-dimension.rb reads
        # $wr_suppress_autorun, the others read $wr_no_autorun — and they are
        # restored after, because leaving them set silences the autorun for the
        # next script the human runs, which looks exactly like a dead button.
        if suppress
          $wr_no_autorun = true
          $wr_suppress_autorun = true
        end
        patch_modals if modal != 'allow'
        patch_writers

        # eval, NOT load, and this deviates from the GOAL's wording on purpose:
        # `load` returns true and DISCARDS the job's value, which is one of the
        # three things this bridge exists to return. eval with an explicit
        # filename gives the same file:line backtraces, and the .rb really is on
        # disk at that path, so a backtrace line is an openable file.
        # TOPLEVEL_BINDING so a job behaves like Ruby Console input — which is
        # the thing these tests stand in for. Consequence for job authors: jobs
        # SHARE TOP-LEVEL STATE across a SketchUp session. Write them idempotent.
        value = eval(src, TOPLEVEL_BINDING, rb_path, 1) # rubocop:disable Security/Eval
      rescue Exception => e
        # rescue Exception, NOT StandardError, and main.rb carries this lesson in
        # full at its `toggle` method: a SyntaxError in a job — or in a script the
        # job loads — descends from ScriptError, sails past a StandardError
        # handler, and is swallowed by SketchUp. The job would then hang to the
        # client's timeout for no visible reason.
        raised = e
      ensure
        begin; unpatch_writers; rescue Exception; nil; end
        begin; unpatch_modals;  rescue Exception; nil; end
        $wr_no_autorun, $wr_suppress_autorun = was_no, was_sup
        $stdout, $stderr = was_out, was_err
      end

      finished = Time.now
      safe = raised ? nil : json_safe(value)

      result = {
        'id'          => id,
        'status'      => (raised ? 'error' : 'ok'),
        'started'     => stamp(started),
        'finished'    => stamp(finished),
        'elapsed_s'   => ((finished - started) * 1000).round / 1000.0,
        # SCRUBBED, like every other string that goes near to_json, and for one
        # extra reason of their own: the 256 KB cap truncates on a BYTE
        # boundary, which can cut a multi-byte character in half. An invalid
        # UTF-8 byte in here would raise out of JSON.generate and turn a job
        # that passed into a bridge error — the exact class of accident the
        # serialiser is written to make impossible.
        'stdout'      => scrub(out.text),
        'stderr'      => scrub(err.text),
        'value'       => (safe == :__unsafe__ ? nil : safe),
        'value_class' => scrub(raised ? 'NilClass' : value.class.name),
        'value_repr'  => (raised ? '' : repr(value)),
        'error'       => (raised ? error_hash(raised) : nil),
        'artifacts'   => (@artifacts || []).select { |a| File.exist?(a) },
        'model'       => model_hash,
        'env'         => env_hash
      }

      @write_roots = nil
      @artifacts   = nil

      # .running goes BEFORE the result is written. The client reads them in the
      # other order — result first — so it can never see "no result, still
      # running" for a job that has in fact finished.
      begin; File.delete(running); rescue Exception; nil; end
      write_result(id, result)
      log("#{id} #{result['status']} #{result['elapsed_s']}s #{scrub(job['label'].to_s)}")
    end

    # A fence or a malformed job stopped it BEFORE any job code ran. Empty
    # stdout is part of the evidence: nothing of the job's ran to produce any.
    def self.refuse(id, started, reason, why)
      now = Time.now
      write_result(id,
        'id'          => id,
        'status'      => 'refused',
        'started'     => stamp(started),
        'finished'    => stamp(now),
        'elapsed_s'   => ((now - started) * 1000).round / 1000.0,
        'stdout'      => '',
        'stderr'      => '',
        'value'       => nil,
        'value_class' => 'NilClass',
        'value_repr'  => '',
        'error'       => { 'class' => 'Refused', 'message' => why,
                           'backtrace' => [], 'cause' => nil },
        'reason'      => reason,
        'artifacts'   => [],
        'model'       => model_hash,
        'env'         => env_hash)
      log("#{id} refused (#{reason})")
      nil
    end

    # ----------------------------------------------------- start and stop --

    def self.running?
      !@timer.nil?
    end

    def self.start
      return false if @timer
      ensure_tree
      sweep_stale
      begin; File.delete(slot('stopped')); rescue Exception; nil; end
      @identity_key = nil
      @busy = false
      @timer = UI.start_timer(POLL_S, true) { tick }
      log("listener started (#{version_name}, plugin #{plugin_version}, #{slot_name})")
      puts "WR BRIDGE listening — #{slot_root}"
      true
    end

    def self.stop
      return false unless @timer
      begin
        UI.stop_timer(@timer)
      rescue Exception
        nil
      end
      @timer = nil
      # Tells the client this slot is switched off, not busy: a stale heartbeat
      # alone cannot tell the two apart while the process is still running.
      begin
        File.open(slot('stopped'), 'wb') { |f| f.write(stamp(Time.now)) }
      rescue Exception
        nil
      end
      log('listener stopped')
      puts 'WR BRIDGE stopped.'
      true
    end

    # Only one listener owns this slot, so a leftover .running in it can only be
    # a crash relic (a reused pid). Leaving it would make the very NEXT timeout
    # misreport as "a job is wedged" when nothing is running at all. Leftover
    # jobs in a reused slot were addressed to a dead process and are dropped.
    #
    # The shared inbox's run/ is left alone: another window may be running a
    # shared-inbox job right now, and a marker there is only ever read by its
    # own job id, so a relic cannot mislead a later job.
    #
    # PEER SLOTS are removed only after SWEEP_AFTER_S of silence. Time alone,
    # deliberately: Ruby's Process.kill(0, pid) on Windows is not something to
    # trust near another running SketchUp. The client's `ping` sweeps sooner,
    # because it can ask Windows whether the pid is still a SketchUp.
    def self.sweep_stale
      require 'fileutils'
      marks = Dir.glob(slot('run', '*.running')) + Dir.glob(slot('in', '*.job.json'))
      marks.each do |f|
        begin
          File.delete(f)
          log("swept stale #{File.basename(f)}")
        rescue Exception
          nil
        end
      end

      now = Time.now
      Dir.glob(File.join(root, "#{SLOT_PREFIX}*")).each do |d|
        next unless File.basename(d) =~ /\A#{SLOT_PREFIX}\d+\z/
        next if File.basename(d) == slot_name || !File.directory?(d)
        beat = File.join(d, 'alive')
        seen = File.exist?(beat) ? File.mtime(beat) : File.mtime(d)
        next unless now - seen > SWEEP_AFTER_S
        begin
          FileUtils.rm_rf(d)
          log("swept silent slot #{File.basename(d)}")
        rescue Exception
          nil
        end
      end
    rescue Exception
      nil
    end

    def self.enable
      ensure_tree
      File.open(dir('enabled'), 'wb') { |f| f.write(stamp(Time.now)) }
      start
      root
    end

    def self.disable
      stop
      begin; File.delete(dir('enabled')); rescue Exception; nil; end
      root
    end

    # Two menu items, added unconditionally — they are the only resident thing
    # when the bridge is off, and they cost nothing. `main.rb` adds them under
    # the WhisperRoom submenu it already owns; this is the fallback for a load
    # order where that submenu is not reachable.
    def self.add_menu(menu)
      menu.add_item('Bridge: enable') do
        r = enable
        UI.messagebox("WhisperRoom bridge ENABLED.\n\n#{r}\n\nIt is polling now — " \
                      'no restart needed.')
      end
      menu.add_item('Bridge: disable') do
        r = disable
        UI.messagebox("WhisperRoom bridge DISABLED.\n\n#{r}")
      end
    end

    # ON LOAD: the marker decides. No marker, no timer, nothing resident. This
    # is what makes the whole loop automatable without a human clicking a menu
    # item — the marker can be created from outside while SketchUp is closed,
    # and the bridge is live the moment SketchUp next starts.
    unless defined?(@loaded) && @loaded
      @loaded = true
      begin
        if enabled?
          start
        else
          puts 'WR BRIDGE present but OFF (no `enabled` marker). ' \
               "Enable: Extensions > WhisperRoom > Bridge: enable, or create\n  " \
               "#{dir('enabled')}\nand restart SketchUp."
        end
      rescue Exception => e
        puts "WR BRIDGE failed to start: #{e.class}: #{e.message}"
      end
    end
  end
end
