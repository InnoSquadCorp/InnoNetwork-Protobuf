#!/usr/bin/env ruby
require 'json'
abort 'Usage: check_public_core.rb PACKAGE_RESOLVED' unless ARGV.length == 1
begin
  root = File.expand_path('..', __dir__)
  expected = File.read(File.join(root, '.github/core-candidate.sha')).strip
  abort 'Invalid expected Core SHA' unless /\A[0-9a-f]{40}\z/.match?(expected)
  lock = JSON.parse(File.read(ARGV[0]))
  abort 'Unsupported lockfile schema' unless lock.is_a?(Hash) && [2, 3].include?(lock['version']) && lock['pins'].is_a?(Array)
  cores = lock['pins'].select { |pin| pin.is_a?(Hash) && pin['identity'] == 'innonetwork' }
  abort 'Expected exactly one published Core pin' unless cores.length == 1
  core = cores.first
  abort 'Published Core must resolve to the reviewed 6.1.1 tag commit' unless
    core['kind'] == 'remoteSourceControl' &&
    core['location'] == 'https://github.com/InnoSquadCorp/InnoNetwork.git' &&
    core['state'].is_a?(Hash) && core['state']['version'] == '6.1.1' &&
    core['state']['revision'] == expected && core['state']['branch'].nil?
  puts "Published Core: PASS 6.1.1 #{expected}"
rescue SystemCallError, JSON::ParserError, TypeError => error
  abort "Published Core: FAIL: #{error.message}"
end
