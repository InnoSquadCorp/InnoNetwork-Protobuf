#!/usr/bin/env ruby
# Read-only post-resolution check. Never reset, delete or repair a build cache.
require 'json'
require 'open3'

abort 'Usage: check_dependency_integrity.rb SCRATCH_PATH PACKAGE_RESOLVED' unless ARGV.length == 2

def require_value(condition, message)
  raise ArgumentError, message unless condition
end

def object(value, label)
  require_value(value.is_a?(Hash), "#{label} must be an object")
  value
end

def string(value, label)
  require_value(value.is_a?(String) && !value.empty? && !value.include?("\0"), "#{label} must be a nonempty string")
  value
end

def unique_entries(entries, label)
  require_value(entries.is_a?(Array), "#{label} must be an array")
  entries.each_with_object({}) do |entry, result|
    object(entry, label)
    identity = yield entry
    string(identity, "#{label} identity")
    require_value(!result.key?(identity), "duplicate #{label} identity: #{identity}")
    result[identity] = entry
  end
end

def git(path, *args)
  out, err, status = Open3.capture3({ 'GIT_NO_REPLACE_OBJECTS' => '1' },
                                  'git', '-C', path, '-c', 'core.fsmonitor=false', *args)
  require_value(status.success? && err.empty?, "Git inspection failed at #{path} (#{args.join(' ')}): #{err}#{out}")
  out.strip
end

begin
  # A redirected Git invocation would inspect something other than the active
  # SwiftPM checkout. Do not silently accept evidence from that other repository.
  %w[GIT_DIR GIT_COMMON_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES].each do |key|
    require_value(ENV[key].nil? || ENV[key].empty?, "unset #{key} before inspecting dependency checkouts")
  end
  scratch = File.realpath(ARGV[0])
  workspace = object(JSON.parse(File.read(File.join(scratch, 'workspace-state.json'))), 'workspace')
  graph = unique_entries(object(workspace['object'], 'workspace object')['dependencies'], 'graph') do |entry|
    object(entry['packageRef'], 'packageRef')['identity']
  end
  lock = object(JSON.parse(File.read(ARGV[1])), 'lockfile')
  require_value([2, 3].include?(lock['version']), 'only Package.resolved versions 2 and 3 are supported')
  pins = unique_entries(lock['pins'], 'lockfile') { |entry| entry['identity'] }
  verified = []
  local = []
  paths = []
  graph.each do |identity, entry|
    ref = entry.fetch('packageRef')
    state = object(entry['state'], "#{identity} state")
    require_value(entry['basedOn'].nil?, "#{identity}: edited dependencies are not immutable checkouts")
    if state['name'] == 'fileSystem'
      require_value(ref['kind'] == 'fileSystem' && !pins.key?(identity), "#{identity}: local dependency substitutes a locked checkout")
      path = File.realpath(string(state['path'], "#{identity} local path"))
      require_value(File.realpath(string(ref['location'], "#{identity} location")) == path &&
                    File.file?(File.join(path, 'Package.swift')), "#{identity}: inconsistent local package path")
      local << identity
      next
    end
    require_value(state['name'] == 'sourceControlCheckout', "#{identity}: unsupported dependency state #{state['name'].inspect}")
    pin = pins[identity]
    require_value(!pin.nil?, "#{identity}: missing lockfile pin")
    require_value(%w[remoteSourceControl localSourceControl].include?(ref['kind']) &&
                  pin['kind'] == ref['kind'] && pin['location'] == string(ref['location'], "#{identity} location"),
                  "#{identity}: lockfile/graph source mismatch")
    checkout = object(state['checkoutState'], "#{identity} checkout state")
    pinned = object(pin['state'], "#{identity} pin state")
    revision = string(checkout['revision'], "#{identity} revision")
    require_value(/\A[0-9a-f]{40}\z/.match?(revision), "#{identity}: revision must be a full SHA")
    %w[version branch].each do |key|
      string(checkout[key], "#{identity} #{key}") unless checkout[key].nil?
    end
    require_value(checkout['version'].nil? || checkout['branch'].nil?, "#{identity}: version and branch cannot both be set")
    %w[revision version branch].each do |key|
      require_value(checkout[key] == pinned[key], "#{identity}: lockfile/graph #{key} mismatch")
    end
    subpath = string(entry['subpath'], "#{identity} checkout subpath")
    require_value(!['.', '..'].include?(subpath) && !subpath.include?('/') && !subpath.include?('\\'),
                  "#{identity}: checkout subpath must be a single directory name")
    base = File.realpath(File.join(scratch, 'checkouts'))
    path = File.realpath(File.join(base, subpath))
    require_value(File.dirname(path) == base && !paths.include?(path), "#{identity}: checkout escapes or duplicates the checkouts directory")
    paths << path
    require_value(File.realpath(git(path, 'rev-parse', '--show-toplevel')) == path, "#{identity}: checkout is not a Git root")
    require_value(git(path, 'rev-parse', 'HEAD') == revision, "#{identity}: checkout HEAD differs from active graph")
    git(path, 'cat-file', '-e', "#{revision}^{commit}")
    require_value(git(path, 'status', '--porcelain', '--untracked-files=all').empty?, "#{identity}: checkout has local changes")
    verified << identity
  end
  unused = pins.keys - verified
  require_value(unused.empty?, "lockfile pins absent from active graph: #{unused.join(', ')}; resolve dependencies in this scratch path again")
  puts "Dependency integrity: PASS (#{verified.length} lock/graph/HEAD/object/clean checkouts; #{local.length} local paths)"
  puts "Local paths are not revision-certified by this check: #{local.join(', ')}" unless local.empty?
rescue SystemCallError, JSON::ParserError, KeyError, TypeError, ArgumentError => error
  abort "Dependency integrity: FAIL: #{error.message}"
end
