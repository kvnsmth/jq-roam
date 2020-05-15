#!/usr/bin/env bash

fileUnderTest="${BASH_SOURCE%/*}/../jq/main.jq"

read -d '' fourLineTests <<-'EOF' || true
pages: empty page gets defaults set
[{}]
pages
[{"title": null, "create-time": null, "edit-time": null, "children": []}]

page("Title"): match
[{"title": "One"}, {"title": "Two"}]
page("One")
[{"title": "One"}]

page("Title"): no match
[{"title": "One"}, {"title": "Two"}]
page("Not here")
[]
EOF

function testAllFourLineTests () {
	echo "$fourLineTests" | runAllFourLineTests
}


# Run tests above automatically.
# Custom tests can be added by adding new function with a name that starts with "test": function testSomething () { some test code; }
source "${BASH_SOURCE%/*}/test-runner.sh"