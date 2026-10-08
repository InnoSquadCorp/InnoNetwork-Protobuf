#!/usr/bin/env ruby
require 'yaml'
require 'tmpdir'
require 'open3'
require 'rbconfig'

source = YAML.load_file(File.expand_path('../.github/workflows/ci.yml', __dir__))
script = File.join(__dir__, 'check_static_workflow.rb')
Dir.mktmpdir('protobuf-static-workflow-') do |dir|
  path = File.join(dir, 'ci.yml')
  count = 0
  check = lambda do |name, expected, &mutate|
    workflow = Marshal.load(Marshal.dump(source))
    mutate.call(workflow) if mutate
    File.write(path, YAML.dump(workflow))
    out, status = Open3.capture2e(RbConfig.ruby, script, path)
    raise "#{name}: unexpected result #{out}" unless status.success? == expected
    count += 1
    puts "#{name}: PASS"
  end
  check.call('docs-only positive control', true)
  check.call('source-only path filter rejected', false) do |workflow|
    workflow.fetch('on', workflow[true])['pull_request'] = { 'paths' => ['Sources/**'] }
  end
  check.call('docs-ignore filter rejected', false) do |workflow|
    workflow.fetch('on', workflow[true])['pull_request'] = { 'paths-ignore' => ['docs/**', 'README.md'] }
  end
  check.call('build prerequisite rejected', false) { |w| w['jobs']['static-contracts']['needs'] = 'build-and-test' }
  check.call('conditional job rejected', false) { |w| w['jobs']['static-contracts']['if'] = 'false' }
  check.call('ignored failure rejected', false) { |w| w['jobs']['static-contracts']['continue-on-error'] = true }
  check.call('conditional check rejected', false) { |w| w['jobs']['static-contracts']['steps'][1]['if'] = 'false' }
  check.call('ignored step failure rejected', false) { |w| w['jobs']['static-contracts']['steps'][1]['continue-on-error'] = true }
  check.call('dependency resolution rejected', false) { |w| w['jobs']['static-contracts']['steps'].insert(1, { 'run' => 'swift package resolve' }) }
  check.call('hidden build command rejected', false) { |w| w['jobs']['static-contracts']['steps'][1]['run'] += "\nswift build" }
  check.call('missing timeout rejected', false) { |w| w['jobs']['static-contracts'].delete('timeout-minutes') }
  check.call('final positive control', true)
  puts "Static workflow fixtures: #{count} passed"
end
