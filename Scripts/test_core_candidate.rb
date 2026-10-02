#!/usr/bin/env ruby
require 'tmpdir'
require 'fileutils'
require 'json'
require 'open3'
require 'rbconfig'
require_relative 'lib/git_fixture'

Dir.mktmpdir('protobuf-candidate-guard-') do |dir|
  scripts = File.join(dir, 'Scripts')
  FileUtils.mkdir_p([scripts, File.join(dir, '.github')])
  script = File.join(scripts, 'check_core_candidate.rb')
  FileUtils.cp(File.join(__dir__, 'check_core_candidate.rb'), script)
  pin = File.join(dir, '.github/core-candidate.sha')
  core = File.join(dir, 'core')
  GitFixture.create(core)
  run = GitFixture.method(:run!)
  File.write(File.join(core, 'Package.swift'), "// candidate fixture\n")
  run.call('git', '-C', core, 'add', 'Package.swift')
  run.call('git', '-C', core, 'commit', '-qm', 'fixture')
  sha = run.call('git', '-C', core, 'rev-parse', 'HEAD')
  count = 0
  check = lambda do |name, expected, *args|
    out, status = Open3.capture2e(GitFixture.environment, RbConfig.ruby, script, *args)
    raise "#{name}: unexpected result: #{out}" unless status.success? == expected
    count += 1
    puts "#{name}: PASS"
  end
  check.call('missing pin rejected', false)
  File.write(pin, "#{sha}\n")
  check.call('valid pin', true)
  check.call('exact clean checkout', true, core)
  ["main\n", "#{sha[0, 7]}\n", "#{sha}\n#{sha}\n", " #{sha}\n", "#{sha.upcase}\n"].each do |invalid|
    File.write(pin, invalid)
    check.call('malformed pin rejected', false)
  end
  File.write(pin, "#{'0' * 40}\n")
  check.call('wrong checkout SHA rejected', false, core)
  File.write(pin, "#{sha}\n")
  check.call('missing checkout rejected', false, File.join(dir, 'missing'))
  nested = File.join(core, 'nested')
  FileUtils.mkdir_p(nested)
  check.call('nested Git directory rejected', false, nested)
  File.write(File.join(core, 'Package.swift'), "// changed\n")
  check.call('dirty tracked source rejected', false, core)
  File.write(File.join(core, 'Package.swift'), "// candidate fixture\n")
  extra = File.join(core, 'Extra.swift')
  File.write(extra, "// untracked\n")
  check.call('untracked source rejected', false, core)
  FileUtils.rm(extra)
  graph = File.join(dir, 'workspace-state.json')
  entry = { 'packageRef' => { 'name' => 'InnoNetwork', 'location' => core },
            'state' => { 'name' => 'fileSystem', 'path' => core } }
  File.write(graph, JSON.generate('object' => { 'dependencies' => [entry] }))
  check.call('exact active graph', true, core, graph)
  File.write(graph, JSON.generate('object' => { 'dependencies' => [entry, entry] }))
  check.call('duplicate active dependency rejected', false, core, graph)
  entry['state']['name'] = 'sourceControlCheckout'
  File.write(graph, JSON.generate('object' => { 'dependencies' => [entry] }))
  check.call('remote checkout substituted for local pair rejected', false, core, graph)
  entry['state']['name'] = 'fileSystem'
  entry['state']['path'] = dir
  File.write(graph, JSON.generate('object' => { 'dependencies' => [entry] }))
  check.call('stale active graph rejected', false, core, graph)
  File.write(graph, JSON.generate('object' => { 'dependencies' => [] }))
  check.call('missing active dependency rejected', false, core, graph)
  File.write(graph, '{}')
  check.call('malformed active graph rejected', false, core, graph)
  File.write(graph, '[]')
  check.call('wrong graph type rejected', false, core, graph)
  puts "core-candidate fixtures: #{count} passed"
end
