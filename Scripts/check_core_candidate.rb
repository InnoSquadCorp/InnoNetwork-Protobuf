#!/usr/bin/env ruby
# Validate the candidate pin and, optionally, the actual local checkout/SwiftPM graph.
require 'json'
require 'open3'

abort 'Usage: check_core_candidate.rb [CORE_CHECKOUT [WORKSPACE_STATE_JSON]]' if ARGV.length > 2
root = File.expand_path('..', __dir__)
begin
  pin = File.binread(File.join(root, '.github/core-candidate.sha'))
rescue SystemCallError => error
  abort "Cannot read core candidate pin: #{error.message}"
end
abort 'Core candidate must be one lowercase, full 40-character commit SHA.' unless /\A[0-9a-f]{40}\n?\z/.match?(pin)
expected = pin.chomp
if ARGV.empty?
  puts expected
  exit
end

def git!(path, *args)
  output, status = Open3.capture2e('git', '-C', path, *args)
  abort "Cannot inspect core checkout: #{output}" unless status.success?
  output.strip
end

begin
  core = File.realpath(ARGV[0])
  abort 'Core path must be the Git/package root, not a nested directory.' unless
    File.realpath(git!(core, 'rev-parse', '--show-toplevel')) == core && File.file?(File.join(core, 'Package.swift'))
  actual = git!(core, 'rev-parse', 'HEAD')
  abort "Core candidate mismatch: expected #{expected}, found #{actual}." unless actual == expected
  abort 'Core candidate has local changes; validate an immutable checkout.' unless
    git!(core, 'status', '--porcelain', '--untracked-files=normal').empty?

  if ARGV[1]
    state = JSON.parse(File.read(ARGV[1]))
    abort 'Malformed SwiftPM workspace state.' unless state.is_a?(Hash) && state['object'].is_a?(Hash)
    dependencies = state.fetch('object').fetch('dependencies')
    abort 'Malformed SwiftPM dependency list.' unless dependencies.is_a?(Array) && dependencies.all? { |entry| entry.is_a?(Hash) }
    cores = dependencies.select { |entry| entry.dig('packageRef', 'name') == 'InnoNetwork' }
    abort 'Active SwiftPM graph must contain exactly one local InnoNetwork dependency.' unless cores.length == 1
    dependency = cores.first
    abort 'Active SwiftPM graph does not use the pinned local core checkout.' unless
      dependency.dig('state', 'name') == 'fileSystem' &&
      File.realpath(dependency.fetch('packageRef').fetch('location')) == core &&
      File.realpath(dependency.fetch('state').fetch('path')) == core
  end
  puts "core-candidate: OK #{expected}#{ARGV[1] ? ' (active SwiftPM graph verified)' : ''}"
rescue SystemCallError, JSON::ParserError, KeyError, TypeError => error
  abort "Invalid candidate validation input: #{error.message}"
end
