#!/usr/bin/env ruby
require 'tmpdir'
require 'fileutils'
require 'open3'
require_relative 'lib/git_fixture'

script = File.expand_path('check_release_gate.sh', __dir__)
Dir.mktmpdir('protobuf-release-gate-') do |dir|
  Dir.chdir(dir) do
    def run!(*args)
      GitFixture.run!(*args)
    end
    GitFixture.create(dir)
    FileUtils.mkdir_p('docs/releases')
    File.write('docs/releases/6.0.0.md', "Release-Status: Draft\n")
    run!('git', 'add', 'docs/releases/6.0.0.md')
    run!('git', 'commit', '-qm', 'fixture')
    run!('git', 'update-ref', 'refs/remotes/origin/main', 'HEAD')
    run!('git', 'tag', '-a', '6.0.0', '-m', 'fixture')
    check = lambda do |mode, version, expected|
      out, status = Open3.capture2e(GitFixture.environment, 'bash', script, mode, version)
      raise "Unexpected result for #{mode} #{version}: #{out}" unless status.success? == expected
    end
    check.call('validate', '6.0.0', true)
    check.call('publish', '6.0.0', false)
    ['main', '06.0.0', '../6.0.0', '6.0.0$(touch injected)', "6.0.0\n"].each { |v| check.call('publish', v, false) }
    raise 'Input executed' if File.exist?('injected')
    check.call('validate', '6.0.1', false)
    File.write('docs/releases/6.0.0.md', "Release-Status: Ready\n")
    check.call('publish', '6.0.0', false) # dirty Ready is not committed Ready
    run!('git', 'add', 'docs/releases/6.0.0.md')
    run!('git', 'commit', '-qm', 'ready')
    check.call('publish', '6.0.0', false) # old tag
    run!('git', 'tag', '-fa', '6.0.0', '-m', 'local fixture replacement')
    check.call('publish', '6.0.0', false) # main ancestry not advanced
    run!('git', 'update-ref', 'refs/remotes/origin/main', 'HEAD')
    check.call('publish', '6.0.0', true)
    run!('git', 'tag', '-d', '6.0.0')
    run!('git', 'tag', '6.0.0')
    check.call('publish', '6.0.0', false) # lightweight with otherwise Ready notes
    run!('git', 'tag', '-fa', '6.0.0', '-m', 'local Ready control')
    check.call('publish', '6.0.0', true)
    File.write('docs/releases/6.0.0.md', "Release-Status: Ready\nRelease-Status: Draft\n")
    run!('git', 'add', 'docs/releases/6.0.0.md')
    run!('git', 'commit', '-qm', 'ambiguous local fixture')
    run!('git', 'tag', '-fa', '6.0.0', '-m', 'local ambiguous fixture')
    run!('git', 'update-ref', 'refs/remotes/origin/main', 'HEAD')
    check.call('publish', '6.0.0', false)
  end
end
puts 'release-gate fixtures: OK (Draft/ref/input/SHA/main/annotated tag/Ready)'
