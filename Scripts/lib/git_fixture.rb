# Test-only Git isolation. Never apply this environment/configuration to a real
# repository: signing and hooks remain the user's policy outside private fixtures.
require 'fileutils'
require 'open3'

module GitFixture
  def self.environment
    ENV.keys.grep(/\AGIT_/).to_h { |key| [key, nil] }.merge(
      'GIT_CONFIG_NOSYSTEM' => '1', 'GIT_CONFIG_GLOBAL' => File::NULL,
      'GIT_CONFIG_SYSTEM' => File::NULL
    )
  end

  def self.run!(*args)
    out, status = Open3.capture2e(environment, *args)
    raise "#{args.inspect}: #{out}" unless status.success?
    out.strip
  end

  def self.create(path)
    FileUtils.mkdir_p(path)
    run!('git', '-C', path, 'init', '-q', '--template=', '--initial-branch=main', '--object-format=sha1')
    {
      'user.name' => 'Validation Fixture', 'user.email' => 'fixture@example.invalid',
      'commit.gpgSign' => 'false', 'tag.gpgSign' => 'false',
      'core.hooksPath' => File.join(File.realpath(path), '.git', 'fixture-hooks')
    }.each { |key, value| run!('git', '-C', path, 'config', '--local', key, value) }
  end
end
