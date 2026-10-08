#!/usr/bin/env ruby
require 'tmpdir'
require 'fileutils'
require 'open3'
require 'rbconfig'

# Exercise the actual suites with hostile ambient configuration, without ever
# changing the caller's Git settings or placing hooks in a user repository.
Dir.mktmpdir('protobuf-git-isolation-') do |dir|
  hooks = File.join(dir, 'hooks')
  template = File.join(dir, 'template')
  FileUtils.mkdir_p([hooks, File.join(template, 'hooks')])
  hook = "#!/bin/sh\necho 'fixture inherited a hook' >&2\nexit 91\n"
  [File.join(hooks, 'pre-commit'), File.join(template, 'hooks', 'pre-commit')].each do |path|
    File.write(path, hook)
    File.chmod(0o755, path)
  end
  config = File.join(dir, 'gitconfig')
  File.write(config, "[commit]\n gpgSign = true\n[tag]\n gpgSign = true\n[gpg]\n program = /usr/bin/false\n[core]\n hooksPath = #{hooks}\n[init]\n templateDir = #{template}\n defaultObjectFormat = sha256\n")
  index = File.join(dir, 'protected-index')
  File.write(index, 'must not change')
  env = {
    'GIT_CONFIG_GLOBAL' => config, 'GIT_CONFIG_SYSTEM' => config,
    'GIT_CONFIG_COUNT' => '2', 'GIT_CONFIG_KEY_0' => 'commit.gpgSign',
    'GIT_CONFIG_VALUE_0' => 'true', 'GIT_CONFIG_KEY_1' => 'gpg.program',
    'GIT_CONFIG_VALUE_1' => '/usr/bin/false', 'GIT_TEMPLATE_DIR' => template,
    'GIT_INDEX_FILE' => index, 'GIT_DIR' => File.join(dir, 'not-a-repository'),
    'GIT_WORK_TREE' => dir, 'GIT_OBJECT_DIRECTORY' => File.join(dir, 'not-objects')
  }
  before = Dir.glob("#{dir}/**/*", File::FNM_DOTMATCH).select { |p| File.file?(p) }.to_h { |p| [p, File.binread(p)] }
  %w[test_core_candidate.rb test_release_gate.rb test_dependency_integrity.rb].each do |name|
    out, status = Open3.capture2e(env, RbConfig.ruby, File.join(__dir__, name))
    raise "#{name} inherited ambient Git configuration:\n#{out}" unless status.success?
    puts "#{name}: hostile Git environment PASS"
  end
  after = Dir.glob("#{dir}/**/*", File::FNM_DOTMATCH).select { |p| File.file?(p) }.to_h { |p| [p, File.binread(p)] }
  raise 'Fixture suites mutated ambient Git data' unless before == after
  puts 'Git fixture isolation: PASS (signing, hooks, template, object format, repository/index/object redirection; ambient files preserved)'
end
