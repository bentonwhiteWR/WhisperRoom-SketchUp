# diag-favourites.rb — why does starring a script not stick?
#
# Run in the Ruby Console:
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/diag-favourites.rb"
#
# Reads and writes only the WR_Tools preference store under the throwaway key
# 'diag_*', plus whatever toggle_pin already writes. Touches no geometry.
#
# Paste the whole output back. Every line is a fact, not an inference: the point
# is to find out what Sketchup.write_default/read_default actually do with a
# string on this build, because the favourites list is stored as one.

module WRDiag
  KEY = 'WR_Tools'.freeze

  def self.show(label, value)
    puts format('  %-28s %-14s %s', label, value.class.to_s, value.inspect)
  end

  # Write a string, read it straight back, and report what came out. If the
  # value does not survive, that alone explains an always-empty favourites bar.
  def self.roundtrip(label, written)
    Sketchup.write_default(KEY, 'diag_rt', written)
    got = Sketchup.read_default(KEY, 'diag_rt', '<<MISSING>>')
    ok  = got == written ? 'SAME' : 'DIFFERENT'
    puts format('  %-22s wrote %-26s got %-12s %-26s %s',
                label, written.inspect, got.class.to_s, got.inspect, ok)
  rescue Exception => e
    puts format('  %-22s wrote %-26s RAISED %s: %s',
                label, written.inspect, e.class, e.message.to_s.split("\n").first)
  end

  def self.run
    puts ''
    puts '=== 1. which copy of the plugin is loaded ==='
    loaded = $LOADED_FEATURES.grep(%r{wr_tools/main\.rb}i)
    if loaded.empty?
      puts '  wr_tools/main.rb is NOT in $LOADED_FEATURES — the extension did not load.'
    else
      loaded.each { |f| puts "  #{f}" }
    end

    defined_mod = defined?(WhisperRoom::Tools) ? 'yes' : 'NO'
    puts "  WhisperRoom::Tools defined:   #{defined_mod}"
    if defined?(WhisperRoom::Tools)
      t = WhisperRoom::Tools
      %w[read_pref write_pref read_list write_list pinned toggle_pin].each do |m|
        puts format('  responds to %-12s %s', m, t.respond_to?(m) ? 'yes' : 'NO  <-- old copy still loaded')
      end
      puts "  LIST_SEP:                     #{t.const_defined?(:LIST_SEP) ? t::LIST_SEP.inspect : 'NOT DEFINED  <-- old copy'}"
    end

    puts ''
    puts '=== 2. what write_default/read_default do to a string ==='
    roundtrip('plain',        'alpha.rb')
    roundtrip('pipe-joined',  'alpha.rb|beta.rb')
    roundtrip('with quotes',  '["alpha.rb"]')
    roundtrip('empty',        '')

    puts ''
    puts '=== 3. the real favourites value ==='
    begin
      raw = Sketchup.read_default(KEY, 'pinned', '<<no value stored>>')
      show('pinned (raw)', raw)
    rescue Exception => e
      puts "  reading 'pinned' RAISED #{e.class}: #{e.message.to_s.split("\n").first}"
      puts '  ^ that is the load-time crash, still present.'
    end

    if defined?(WhisperRoom::Tools) && WhisperRoom::Tools.respond_to?(:pinned)
      begin
        show('Tools.pinned', WhisperRoom::Tools.pinned)
      rescue Exception => e
        puts "  Tools.pinned RAISED #{e.class}: #{e.message}"
      end
    end

    puts ''
    puts '=== 4. does toggle_pin persist? ==='
    if defined?(WhisperRoom::Tools) && WhisperRoom::Tools.respond_to?(:toggle_pin)
      t = WhisperRoom::Tools
      victim = begin
        s = t.scan.first
        s && s['name']
      rescue Exception
        nil
      end
      if victim.nil?
        puts '  scan found no scripts — cannot test. That is itself the bug.'
      else
        puts "  test script: #{victim.inspect}"
        before = t.pinned
        show('pinned before', before)
        t.toggle_pin(victim)
        after = t.pinned
        show('pinned after toggle', after)
        show('raw after toggle', Sketchup.read_default(KEY, 'pinned', '<<none>>'))
        puts(after == before ? '  DID NOT PERSIST  <-- this is the failure' : '  persisted OK')
        t.toggle_pin(victim) if after != before # leave the list as we found it
        show('pinned restored', t.pinned)
      end
    else
      puts '  toggle_pin unavailable — see section 1.'
    end

    puts ''
    puts '=== 5. is the dialog callback reaching Ruby? ==='
    puts '  Open the WhisperRoom panel, click a star, and watch for a WR-PIN line'
    puts '  below. No line means the click never left the HTML dialog.'
    if defined?(WhisperRoom::Tools)
      t = WhisperRoom::Tools
      unless t.respond_to?(:diag_patched?)
        t.singleton_class.send(:alias_method, :toggle_pin_orig, :toggle_pin)
        t.define_singleton_method(:toggle_pin) do |name|
          puts "WR-PIN callback fired for #{name.inspect}"
          r = toggle_pin_orig(name)
          puts "WR-PIN list is now #{pinned.inspect}"
          r
        end
        t.define_singleton_method(:diag_patched?) { true }
        puts '  tracer installed.'
      else
        puts '  tracer already installed.'
      end
    end

    puts ''
    puts '=== end. Paste everything above. ==='
    Sketchup.write_default(KEY, 'diag_rt', '')
    nil
  end
end

WRDiag.run
