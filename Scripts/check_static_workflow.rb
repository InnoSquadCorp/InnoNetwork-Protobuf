#!/usr/bin/env ruby
require 'yaml'

# Keep docs-only PR feedback independent of unavailable public dependencies and
# heavyweight builds. Existing compiled/public release gates are separate jobs.
begin
  path = ARGV.fetch(0, File.expand_path('../.github/workflows/ci.yml', __dir__))
  workflow = YAML.load_file(path)
  events = workflow.fetch('on', workflow[true]) # Psych's YAML 1.1 parses "on" as true.
  raise 'CI must run on every pull request, including docs-only changes' unless
    events.is_a?(Hash) && events.key?('pull_request') &&
    (events['pull_request'].nil? || events['pull_request'] == {})
  job = workflow.fetch('jobs').fetch('static-contracts')
  raise 'Static contracts must not wait for or skip behind another job' if job.key?('needs') || job.key?('if') || job['continue-on-error']
  raise 'Static contracts require a bounded timeout' unless job['timeout-minutes'].is_a?(Integer) && job['timeout-minutes'].between?(1, 10)
  steps = job.fetch('steps')
  raise 'Static contracts must contain only checkout and the local static script' unless
    steps.is_a?(Array) && steps.length == 2 &&
    steps[0].fetch('uses', '').start_with?('actions/checkout@') &&
    steps[1]['run'] == 'bash Scripts/check_static_contracts.sh' &&
    steps.all? { |step| !step.key?('if') && !step['continue-on-error'] }
  puts 'Static workflow contract: PASS (all PRs; independent, build-free job)'
rescue KeyError, TypeError, NoMethodError, RuntimeError, SystemCallError, Psych::Exception => error
  abort "Static workflow contract: FAIL: #{error.message}"
end
