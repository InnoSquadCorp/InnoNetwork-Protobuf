#!/usr/bin/env ruby
require 'tmpdir'
require 'json'
require 'rbconfig'
require_relative 'lib/git_fixture'

script = File.join(__dir__, 'check_dependency_integrity.rb')
Dir.mktmpdir('protobuf-dependency-integrity-') do |dir|
  scratch = File.join(dir, 'scratch')
  checkout = File.join(scratch, 'checkouts', 'dependency')
  local = File.join(dir, 'local')
  GitFixture.create(checkout)
  FileUtils.mkdir_p(local)
  [local, checkout].each { |path| File.write(File.join(path, 'Package.swift'), "// fixture\n") }
  GitFixture.run!('git', '-C', checkout, 'add', 'Package.swift')
  GitFixture.run!('git', '-C', checkout, 'commit', '-qm', 'fixture')
  revision = GitFixture.run!('git', '-C', checkout, 'rev-parse', 'HEAD')
  remote = {
    'packageRef' => { 'identity' => 'dependency', 'kind' => 'remoteSourceControl', 'location' => 'https://example.invalid/dependency.git' },
    'state' => { 'name' => 'sourceControlCheckout', 'checkoutState' => { 'revision' => revision, 'version' => '1.0.0' } },
    'subpath' => 'dependency'
  }
  filesystem = { 'packageRef' => { 'identity' => 'local', 'kind' => 'fileSystem', 'location' => local },
                 'state' => { 'name' => 'fileSystem', 'path' => local } }
  baseline_graph = { 'object' => { 'dependencies' => [remote, filesystem] }, 'version' => 7 }
  baseline_lock = { 'version' => 3, 'pins' => [remote['packageRef'].merge('state' => remote['state']['checkoutState'])] }
  graph_file = File.join(scratch, 'workspace-state.json')
  lock_file = File.join(dir, 'Package.resolved')
  count = 0
  check = lambda do |name, error = nil, &mutate|
    graph = Marshal.load(Marshal.dump(baseline_graph))
    lock = Marshal.load(Marshal.dump(baseline_lock))
    mutate.call(graph, lock) if mutate
    File.write(graph_file, JSON.generate(graph))
    File.write(lock_file, JSON.generate(lock))
    out, status = Open3.capture2e(GitFixture.environment, RbConfig.ruby, script, scratch, lock_file)
    expected = error.nil?
    raise "#{name}: unexpected result: #{out}" unless status.success? == expected && (expected || out.include?(error))
    count += 1
    puts "#{name}: PASS"
  end
  check.call('exact remote plus explicit local graph')
  check.call('version 2 lock') { |_graph, lock| lock['version'] = 2 }
  check.call('branch-based checkout') do |g, l|
    [g['object']['dependencies'][0]['state']['checkoutState'], l['pins'][0]['state']].each do |s|
      s.delete('version')
      s['branch'] = 'main'
    end
  end
  check.call('revision-only checkout') do |g, l|
    g['object']['dependencies'][0]['state']['checkoutState'].delete('version')
    l['pins'][0]['state'].delete('version')
  end
  check.call('wrong lock revision', 'revision mismatch') { |_g, l| l['pins'][0]['state']['revision'] = '0' * 40 }
  check.call('wrong graph and lock revision', 'HEAD differs') do |g, l|
    g['object']['dependencies'][0]['state']['checkoutState']['revision'] = '0' * 40
    l['pins'][0]['state']['revision'] = '0' * 40
  end
  check.call('wrong version', 'version mismatch') { |_g, l| l['pins'][0]['state']['version'] = '2.0.0' }
  check.call('wrong branch', 'branch mismatch') { |_g, l| l['pins'][0]['state']['branch'] = 'main' }
  check.call('wrong location', 'source mismatch') { |_g, l| l['pins'][0]['location'] = 'https://example.invalid/other.git' }
  check.call('missing pin', 'missing lockfile pin') { |_g, l| l['pins'] = [] }
  check.call('missing graph entry', 'pins absent') { |g, _l| g['object']['dependencies'].shift }
  check.call('duplicate graph', 'duplicate graph identity') { |g, _l| g['object']['dependencies'] << g['object']['dependencies'][0] }
  check.call('duplicate pin', 'duplicate lockfile identity') { |_g, l| l['pins'] << l['pins'][0] }
  check.call('local substituted for pin', 'substitutes a locked checkout') do |g, _l|
    g['object']['dependencies'][0] = Marshal.load(Marshal.dump(filesystem))
    g['object']['dependencies'][0]['packageRef']['identity'] = 'dependency'
  end
  check.call('missing local package', 'No such file') { |g, _l| g['object']['dependencies'][1]['state']['path'] += '-missing' }
  check.call('inconsistent local path', 'inconsistent local package') { |g, _l| g['object']['dependencies'][1]['state']['path'] = checkout }
  check.call('edited dependency', 'unsupported dependency state') { |g, _l| g['object']['dependencies'][0]['state']['name'] = 'edited' }
  check.call('edited base metadata', 'edited dependencies') { |g, _l| g['object']['dependencies'][0]['basedOn'] = {} }
  check.call('traversal subpath', 'single directory name') { |g, _l| g['object']['dependencies'][0]['subpath'] = '../dependency' }
  check.call('missing checkout', 'No such file') { |g, _l| g['object']['dependencies'][0]['subpath'] = 'missing' }
  File.symlink(local, File.join(scratch, 'checkouts', 'escaped'))
  check.call('symlink escape', 'escapes or duplicates') { |g, _l| g['object']['dependencies'][0]['subpath'] = 'escaped' }
  check.call('bad JSON root', 'workspace object must be an object') { |g, _l| g.clear }
  check.call('bad dependencies', 'graph must be an array') { |g, _l| g['object']['dependencies'] = nil }
  check.call('bad package ref', 'packageRef must be an object') { |g, _l| g['object']['dependencies'][0]['packageRef'] = [] }
  check.call('bad checkout state', 'checkout state must be an object') { |g, _l| g['object']['dependencies'][0]['state']['checkoutState'] = [] }
  check.call('unsupported lock schema', 'versions 2 and 3') { |_g, l| l['version'] = 99 }
  check.call('short revision', 'full SHA') { |g, _l| g['object']['dependencies'][0]['state']['checkoutState']['revision'] = revision[0, 7] }
  check.call('matching but invalid version types', 'version must be a nonempty string') do |g, l|
    g['object']['dependencies'][0]['state']['checkoutState']['version'] = []
    l['pins'][0]['state']['version'] = []
  end
  check.call('matching but contradictory states', 'cannot both be set') do |g, l|
    g['object']['dependencies'][0]['state']['checkoutState']['branch'] = 'main'
    l['pins'][0]['state']['branch'] = 'main'
  end
  File.write(File.join(checkout, 'Package.swift'), "// changed\n")
  check.call('dirty tracked source', 'local changes')
  File.write(File.join(checkout, 'Package.swift'), "// fixture\n")
  File.write(File.join(checkout, 'Extra.swift'), "// untracked\n")
  check.call('dirty untracked source', 'local changes')
  FileUtils.rm(File.join(checkout, 'Extra.swift'))
  # Missing alternate objects can emit diagnostics even when HEAD itself resolves.
  info = File.join(checkout, '.git', 'objects', 'info')
  FileUtils.mkdir_p(info)
  alternates = File.join(info, 'alternates')
  File.write(alternates, "#{dir}/missing-objects\n")
  check.call('broken alternate object metadata', 'Git inspection failed')
  FileUtils.rm(alternates)
  commit = File.join(checkout, '.git', 'objects', revision[0, 2], revision[2..-1])
  File.rename(commit, "#{commit}.saved")
  check.call('unavailable commit object', 'Git inspection failed')
  File.rename("#{commit}.saved", commit)
  check.call('passing control after all corruptions')
  puts "Dependency integrity fixtures: #{count} passed"
end
