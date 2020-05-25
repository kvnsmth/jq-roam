#!/usr/bin/env bash
# idea taken from https://github.com/joelpurra/jq-counter-buckets/tree/master/tests
# 
# tip if adding tests: use a separate file where you can pretty print json and then minify to copy back in

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
{"title":"One","create-time":null,"edit-time":null,"children":[{"uid":"id","string":"string","heading":null,"create-time":null,"edit-time":null,"children":[]},{"uid":"id2","string":"string2","heading":null,"create-time":null,"edit-time":null,"children":[]}]}

page: recursive block ref replacement
[{"title":"One","children":[{"uid":"id","string":"((id3))"},{"uid":"id2","string":"((id))2"}]},{"title":"Two","children":[{"uid":"id3","string":"string3"}]}]
page("One")
{"title":"One","create-time":null,"edit-time":null,"children":[{"uid":"id","string":"string3","heading":null,"create-time":null,"edit-time":null,"children":[]},{"uid":"id2","string":"string32","heading":null,"create-time":null,"edit-time":null,"children":[]}]}

removePages: simple filter (withTag), empty result
[{"title":"One","children":[{"uid":"id","string":"#tag","children":[{"uid":"cool","string":"awesome"}]},{"uid":"id2","string":"((id))2","children":[{"uid":"cool2","string":"awesome2"}]}]}]
pages | removePages(wt("tag"))
[]

removePages: complex filter
[{"title":"One","children":[{"uid":"id","string":"great","children":[{"uid":"cool","string":"#tag"}]},{"uid":"id2","string":"awesome2","children":[]}]},{"title":"Two","children":[{"uid":"id5","string":"#awesome"},{"uid":"id6","string":"word"}]},{"title":"Two","children":[{"uid":"id3","string":"#awesome"},{"uid":"id4","string":"word"}]}]
pages | rp(wot("tag"))
[{"title":"One","create-time":null,"edit-time":null,"children":[{"uid":"id","string":"great","heading":null,"create-time":null,"edit-time":null,"children":[{"uid":"cool","string":"#tag","heading":null,"create-time":null,"edit-time":null,"children":[]}]},{"uid":"id2","string":"awesome2","heading":null,"create-time":null,"edit-time":null,"children":[]}]}]

removePageBlocks: simple filter (withTag)
[{"title":"One","children":[{"uid":"id","string":"#tag","children":[{"uid":"cool","string":"awesome"}]},{"uid":"id2","string":"cool section","children":[{"uid":"cool2","string":"awesome2"}]},{"uid":"id3","string":"hello","children":[{"uid":"id3.1","string":"#tag"}]}]}]
pages | rpb(wt("tag"))
[{"title":"One","create-time":null,"edit-time":null,"children":[{"uid":"id2","string":"cool section","heading":null,"create-time":null,"edit-time":null,"children":[{"uid":"cool2","string":"awesome2","heading":null,"create-time":null,"edit-time":null,"children":[]}]},{"uid":"id3","string":"hello","heading":null,"create-time":null,"edit-time":null,"children":[]}]}]

removePageBlocks: simple filter (witoutTag)
[{"title":"One","children":[{"uid":"id","string":"#tag","children":[{"uid":"cool","string":"awesome"}]},{"uid":"id2","string":"cool section","children":[{"uid":"cool2","string":"awesome2"}]},{"uid":"id3","string":"hello","children":[{"uid":"id3.1","string":"#tag"}]}]}]
pages | rpb(wot("tag"))
[{"title":"One","create-time":null,"edit-time":null,"children":[{"uid":"id","string":"#tag","heading":null,"create-time":null,"edit-time":null,"children":[]}]}]

blocks: empty blocks gets default
[]
blocks
[]

blocks: removeBlocks + withTag; rb(wt)
[{"title": "One", "children": [{"uid": "id", "string": "#tag"}, {"uid": "id2", "string": "((id))2"}, {"uid": "id3", "string": "#exclude"}]}]
blocks | rb(wt("tag"))
[{"uid": "id3", "string": "#exclude", "heading": null, "create-time": null, "edit-time": null, "children": []}]

blocks: removeBlocks + withoutTag; rb(wot)
[{"title": "One", "children": [{"uid": "id", "string": "#tag"}, {"uid": "id2", "string": "((id))2"},{"uid": "id3", "string": "#exclude"}]}]
blocks | rb(wot("tag"))
[{"uid": "id", "string": "#tag", "heading": null, "create-time": null, "edit-time": null, "children": []},{"uid": "id2", "string": "#tag2", "heading": null, "create-time": null, "edit-time": null, "children": []}]

blocks: removeBlockBlocks (rbb)
[{"title":"One","children":[{"uid":"id","string":"#tag","children":[{"uid":"cool","string":"awesome"}]},{"uid":"id2","string":"#boop","children":[{"uid":"cool2","string":"awesome2"},{"uid":"cool3","string":"#exclude we do not want"}]}]}]
blocks | rb(wot("boop")) | rbb(wt("exclude"))
[{"uid":"id2","string":"#boop","heading":null,"create-time":null,"edit-time":null,"children":[{"uid":"cool2","string":"awesome2","heading":null,"create-time":null,"edit-time":null,"children":[]}]}]

removeBlocks: recursive
[{"title": "One", "children": [{"uid": "id", "string": "#tag","children": [{"uid": "cool", "string": "#awesome"}]},{"uid": "id2", "string": "((id))2","children": [{"uid": "cool2", "string": "awesome2"}]}]}]
blocks | removeBlocks(withTag("awesome"); true) | rb(wt("tag2"))
[{"uid": "cool2", "string": "awesome2", "heading": null, "create-time": null, "edit-time": null, "children": []}]

removeBlocks: withPageRef (wpr), withoutPageRef (wopr)
[{"title": "One", "children": [{"uid": "id", "string": "#tag","children": [{"uid": "cool", "string": "#awesome [[Page]]"}]},{"uid": "id2", "string": "((id))2",\
"children": [{"uid": "cool2", "string": "awesome2 [[Page New]] [[Boop]]"}]}]}]
blocks | rb(wpr("Page")) | rb(wopr("Boop"))
[{"uid": "cool2","string": "awesome2 [[Page New]] [[Boop]]","heading": null, "create-time": null, "edit-time": null, "children": []}]

children: all of blocks
[{"title": "One", "children": [{"uid": "id", "string": "#tag","children": [{"uid": "cool", "string": "awesome"}]}, {"uid": "id2", "string": "((id))2","children": [{"uid": "cool2", "string": "awesome2"}]}]}]
blocks | children
[{"uid": "cool", "string": "awesome", "heading": null, "create-time": null, "edit-time": null, "children": []},{"uid": "cool2", "string": "awesome2", "heading": null, "create-time": null, "edit-time": null, "children": []}]

children: after removeBlocks filter
[{"title": "One", "children": [{"uid": "id", "string": "#tag","children": [{"uid": "cool", "string": "awesome"}]}, {"uid": "id2", "string": "((id))2","children": [{"uid": "cool2", "string": "awesome2"}]}]}]
blocks | removeBlocks(withTag("tag"); true) | children
[]

EOF

function testAllFourLineTests () {
	echo "$fourLineTests" | runAllFourLineTests
}


# Run tests above automatically.
# Custom tests can be added by adding new function with a name that starts with "test": function testSomething () { some test code; }
source "${BASH_SOURCE%/*}/test-runner.sh"