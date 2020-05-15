#!/usr/bin/env bash
# idea taken from https://github.com/joelpurra/jq-counter-buckets/tree/master/tests

fileUnderTest="${BASH_SOURCE%/*}/../jq/main.jq"

read -d '' fourLineTests <<-'EOF' || true
pages: empty page gets defaults set
[{}]
pages
[{"title": null, "create-time": null, "edit-time": null, "children": []}]

page("Title"): match
[{"title": "One"}, {"title": "Two"}]
page("One")
{"title": "One", "create-time": null, "edit-time": null, "children": []}

page("Title"): no match
[{"title": "One"}, {"title": "Two"}]
page("Not here")
null

page("Title"): block ref replacement
[{"title": "One", "children": [{"uid": "id", "string": "string"}, {"uid": "id2", "string": "((id))2"}]}]
page("One")
{"title": "One", "create-time": null, "edit-time": null,\
"children": [\
{"uid": "id", "string": "string", "heading": null, "create-time": null, "edit-time": null, "children": []},\
{"uid": "id2", "string": "string2", "heading": null, "create-time": null, "edit-time": null, "children": []}]}

page("Title"): recursive block ref replacement
[{"title": "One", "children": [{"uid": "id", "string": "((id3))"}, {"uid": "id2", "string": "((id))2"}]},\
{"title": "Two", "children": [{"uid": "id3", "string": "string3"}]}]
page("One")
{"title": "One", "create-time": null, "edit-time": null,\
"children": [\
{"uid": "id", "string": "string3", "heading": null, "create-time": null, "edit-time": null, "children": []},\
{"uid": "id2", "string": "string32", "heading": null, "create-time": null, "edit-time": null, "children": []}]}

blocks: empty blocks gets default
[]
blocks
[]

blocks: remove with tag
[{"title": "One", "children": [{"uid": "id", "string": "#tag"}, {"uid": "id2", "string": "((id))2"}]}]
blocks | rb(wt("tag"))
[]

blocks: remove without tag
[{"title": "One", "children": [{"uid": "id", "string": "#tag"}, {"uid": "id2", "string": "((id))2"},\
{"uid": "id3", "string": "#exclude"}]}]
blocks | rb(wot("tag"))
[\
{"uid": "id", "string": "#tag", "heading": null, "create-time": null, "edit-time": null, "children": []},\
{"uid": "id2", "string": "#tag2", "heading": null, "create-time": null, "edit-time": null, "children": []}]

removeBlocks: recursive
[{"title": "One", "children": [\
{"uid": "id", "string": "#tag",\
"children": [{"uid": "cool", "string": "#awesome"}]\
},\
{"uid": "id2", "string": "((id))2",\
"children": [{"uid": "cool2", "string": "awesome2"}]\
}]}]
blocks | removeBlocks(withTag("awesome"); true) | rb(wt("tag2"))
[{"uid": "cool2", "string": "awesome2", "heading": null, "create-time": null, "edit-time": null, "children": []}]

children: all of blocks
[{"title": "One", "children": [{"uid": "id", "string": "#tag",\
"children": [{"uid": "cool", "string": "awesome"}]\
}, {"uid": "id2", "string": "((id))2",\
"children": [{"uid": "cool2", "string": "awesome2"}]}]}]
blocks | children
[{"uid": "cool", "string": "awesome", "heading": null, "create-time": null, "edit-time": null, "children": []},\
{"uid": "cool2", "string": "awesome2", "heading": null, "create-time": null, "edit-time": null, "children": []}]

children: after filter
[{"title": "One", "children": [{"uid": "id", "string": "#tag",\
"children": [{"uid": "cool", "string": "awesome"}]\
}, {"uid": "id2", "string": "((id))2",\
"children": [{"uid": "cool2", "string": "awesome2"}]}]}]
blocks | removeBlocks(withTag("tag"); true) | children
[]

EOF

function testAllFourLineTests () {
	echo "$fourLineTests" | runAllFourLineTests
}


# Run tests above automatically.
# Custom tests can be added by adding new function with a name that starts with "test": function testSomething () { some test code; }
source "${BASH_SOURCE%/*}/test-runner.sh"