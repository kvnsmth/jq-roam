#!/usr/bin/env bash
# idea taken from https://github.com/joelpurra/jq-counter-buckets/tree/master/tests

fileUnderTest="${BASH_SOURCE%/*}/../jq/main.jq"

read -d '' fourLineTests <<-'EOF' || true
pages: empty page gets defaults set
[{}]
pages
[{"title": null, "create-time": null, "edit-time": null, "children": []}]

page: match
[{"title": "One"}, {"title": "Two"}]
page("One")
{"title": "One", "create-time": null, "edit-time": null, "children": []}

page: no match
[{"title": "One"}, {"title": "Two"}]
page("Not here")
null

page: block ref replacement
[{"title": "One", "children": [{"uid": "id", "string": "string"}, {"uid": "id2", "string": "((id))2"}]}]
page("One")
{"title": "One", "create-time": null, "edit-time": null,\
"children": [\
{"uid": "id", "string": "string", "heading": null, "create-time": null, "edit-time": null, "children": []},\
{"uid": "id2", "string": "string2", "heading": null, "create-time": null, "edit-time": null, "children": []}]}

page: recursive block ref replacement
[{"title": "One", "children": [{"uid": "id", "string": "((id3))"}, {"uid": "id2", "string": "((id))2"}]},\
{"title": "Two", "children": [{"uid": "id3", "string": "string3"}]}]
page("One")
{"title": "One", "create-time": null, "edit-time": null,\
"children": [\
{"uid": "id", "string": "string3", "heading": null, "create-time": null, "edit-time": null, "children": []},\
{"uid": "id2", "string": "string32", "heading": null, "create-time": null, "edit-time": null, "children": []}]}

removePages: simple filter, empty result
[{"title": "One", "children": [\
{"uid": "id", "string": "#tag", "children": [\
{"uid": "cool", "string": "awesome"}\
]\},\
{"uid": "id2", "string": "((id))2","children": [\
{"uid": "cool2", "string": "awesome2"}]}]}\
]
pages | rp(wt("tag"))
[]

removePages: simple filter, result
[{"title": "One", "children": [\
{"uid": "id", "string": "#tag", "children": [\
{"uid": "cool", "string": "awesome"}\
]\},\
{"uid": "id2", "string": "((id))2","children": [\
{"uid": "cool2", "string": "awesome2"}]}]}\
]
pages | rp(wot("tag")) | rpb(wt("tag"))
[{"title": "One", "create-time": null, "edit-time": null, "children": []}]

removePages: complex filter
[{"title": "One", "children": [{"uid": "id", "string": "#tag",\
"children": [\
{"uid": "cool", "string": "awesome"}]},\
{"uid": "id2", "string": "awesome2", "children": []}\
]},\
{"title": "Two", "children": [{"uid": "id3", "string": "#awesome"}, {"uid": "id4", "string": "word"}]}\
]
pages | rp(wot("tag"))
[{"title": "One", "create-time": null, "edit-time": null, \
"children": [{"uid": "id", "string": "#tag", "heading": null, "create-time": null, "edit-time": null,\
"children": [\
{"uid": "cool", "string": "awesome", "heading": null, "create-time": null, "edit-time": null, "children": []}]},\
{"uid": "id2", "string": "awesome2", "heading": null, "create-time": null, "edit-time": null, "children": []}\
]}]

blocks: empty blocks gets default
[]
blocks
[]

blocks: remove with tag
[{"title": "One", "children": [{"uid": "id", "string": "#tag"}, {"uid": "id2", "string": "((id))2"}, {"uid": "id3", "string": "#exclude"}]}]
blocks | rb(wt("tag"))
[{"uid": "id3", "string": "#exclude", "heading": null, "create-time": null, "edit-time": null, "children": []}]

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

removeBlocks: page refs
[{"title": "One", "children": [\
{"uid": "id", "string": "#tag",\
"children": [{"uid": "cool", "string": "#awesome [[Page]]"}]\
},\
{"uid": "id2", "string": "((id))2",\
"children": [{"uid": "cool2", "string": "awesome2 [[Page New]] [[Boop]]"}]\
}]}]
blocks | rb(wpr("Page")) | rb(wopr("Boop"))
[{"uid": "cool2","string": "awesome2 [[Page New]] [[Boop]]","heading": null, "create-time": null, "edit-time": null, "children": []}]

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