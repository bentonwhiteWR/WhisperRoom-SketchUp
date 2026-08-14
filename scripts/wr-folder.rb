# wr-folder.rb — one folder picker for every script that needs a folder.
#
# NOT A COMMAND. A library, `load`ed by the scripts that use it, and listed in
# wr_tools' SKIP so it never shows up in the panel as something to run.
#
# THE PROBLEM
#
# UI.inputbox has text fields and dropdowns. It has no Browse button, and there
# is no API to put one there. So every script here grew the same workaround —
# "Output folder — blank to browse" — which means the only way to reach a folder
# browser is to clear a field first, and the normal path is pasting a path in by
# hand. Reported, fairly, as odd.
#
# THE FIX
#
# Make the folder field a DROPDOWN of folders you have used before, with
# "Browse for a folder..." as the last entry. The common case — same folder as
# last time — is now zero typing and zero clicks beyond opening the list. The
# uncommon case is one extra click and a real Windows folder browser.
#
# The browser only opens AFTER the inputbox is dismissed, because a modal cannot
# be raised from inside another modal's field. That is why this is two calls:
# `field` builds the dropdown, `resolve` turns the pick into a path.
#
#   default, list = WR_Folder.field('angled', DEFAULTS['dir'])
#   ...
#   dir = WR_Folder.resolve(res[2], 'angled', 'Where should the images go?')
#   return nil if dir.nil?
#
# The KEY namespaces the history, so the angled exporter's folders do not
# clutter the component-probe's list.
#
# STORAGE follows the wr_tools rules, and they are not optional:
# Sketchup.read_default EVALS the stored string and write_default does not escape
# quotes inside it, so a quote comes back as a SyntaxError — which descends from
# ScriptError, not StandardError, and escapes a plain rescue. Quotes are stripped
# going in and Exception is rescued coming out. The list is pipe-joined because
# "|" is illegal in a Windows path and so cannot appear inside one.

require 'sketchup.rb'

module WR_Folder
  PREF   = 'WR_Folders'.freeze
  BROWSE = 'Browse for a folder...'.freeze
  MAX    = 8      # more than this and the dropdown is worse than typing

  def self.read_list(key)
    Sketchup.read_default(PREF, key.to_s, '').to_s.split('|').reject(&:empty?)
  rescue Exception
    begin
      Sketchup.write_default(PREF, key.to_s, '')
    rescue Exception
      nil
    end
    []
  end

  def self.write_list(key, list)
    Sketchup.write_default(PREF, key.to_s, list.join('|').delete('"'))
  rescue Exception
    nil
  end

  def self.norm(p)
    p.to_s.strip.tr('\\', '/').sub(%r{/+\z}, '')
  end

  def self.remember(key, path)
    p = norm(path)
    return if p.empty? || p.include?('|')
    list = ([p] + read_list(key).reject { |x| x.casecmp(p).zero? }).first(MAX)
    write_list(key, list)
  end

  # [default, list] for a UI.inputbox folder field. `fallback` seeds the history
  # the very first time, so a script with a sensible default folder still offers
  # it rather than opening on "Browse..." and making you find it.
  def self.field(key, fallback = '')
    list = read_list(key)
    list = [norm(fallback)] if list.empty? && !norm(fallback).empty?
    list += [BROWSE]
    [list.first, list.join('|')]
  end

  # Turn what the dropdown returned into a real folder path, or nil if the user
  # backed out. `create` is for OUTPUT folders, which may not exist yet;
  # input folders pass create=false and are checked instead.
  def self.resolve(picked, key, title = 'Choose a folder', create = true)
    p = norm(picked)

    if p.empty? || p == norm(BROWSE)
      start = read_list(key).first
      opts = { :title => title }
      opts[:directory] = start if start && File.directory?(start)
      chosen = begin
                 UI.select_directory(opts)
               rescue Exception
                 begin
                   UI.select_directory(:title => title)
                 rescue Exception
                   nil
                 end
               end
      return nil if chosen.nil? || chosen.to_s.empty?
      p = norm(chosen)
    end

    return nil if p.empty?

    unless File.directory?(p)
      if create
        begin
          require 'fileutils'
          FileUtils.mkdir_p(p)
        rescue Exception => e
          UI.messagebox("Cannot create that folder:\n#{p}\n\n#{e.class}: #{e.message}")
          return nil
        end
      else
        UI.messagebox("Not a folder:\n#{p}")
        return nil
      end
    end

    remember(key, p)
    p
  end
end
