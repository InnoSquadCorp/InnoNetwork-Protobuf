#!/usr/bin/env bash
# No Swift resolution/build, network, or published Core tag is needed here.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
ruby Scripts/check_core_candidate.rb
ruby Scripts/test_core_candidate.rb
ruby Scripts/test_dependency_integrity.rb
ruby Scripts/test_public_core.rb
ruby Scripts/test_release_gate.rb
ruby Scripts/test_git_fixture.rb
ruby Scripts/check_static_workflow.rb
ruby Scripts/test_static_workflow.rb
bash Scripts/check_docs_contract_sync.sh
