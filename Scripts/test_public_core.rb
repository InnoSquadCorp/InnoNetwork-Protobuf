#!/usr/bin/env ruby
require 'json'
require 'tmpdir'
require 'open3'
require 'rbconfig'
sha = File.read(File.expand_path('../.github/core-candidate.sha', __dir__)).strip
pin = { 'identity' => 'innonetwork', 'kind' => 'remoteSourceControl',
        'location' => 'https://github.com/InnoSquadCorp/InnoNetwork.git',
        'state' => { 'version' => '6.1.1', 'revision' => sha } }
Dir.mktmpdir('protobuf-public-core-') do |dir|
  path = File.join(dir, 'Package.resolved')
  check = lambda do |label, pins, expected|
    File.write(path, JSON.generate('version' => 3, 'pins' => pins))
    out, status = Open3.capture2e(RbConfig.ruby, File.join(__dir__, 'check_public_core.rb'), path)
    raise "#{label}: #{out}" unless status.success? == expected
    puts "#{label}: PASS"
  end
  check.call('exact released version/revision', [pin], true)
  check.call('missing public core', [], false)
  check.call('duplicate public core', [pin, pin], false)
  %w[version revision branch].each do |key|
    other = Marshal.load(Marshal.dump(pin))
    other['state'][key] = key == 'revision' ? '0' * 40 : 'main'
    check.call("wrong #{key}", [other], false)
  end
  other = Marshal.load(Marshal.dump(pin)); other['location'] = 'https://example.com/fork.git'
  check.call('wrong source', [other], false)
  check.call('final positive', [pin], true)
end
puts 'Published Core fixtures: 8 passed'
