# Utils
def _order($o):
  if o == "desc" then
    reverse
  else # "asc" or default
    .
  end
;

def _filterBlocks($f):
  map(
      select(
        .string
        | strings
        | test($f) == false
      )
    )
;

# Replaces block refs with text mapping in $blocks
# TODO: test this works with multiple refs
def _replaceBlockRefs($blocks):
  map(
    select(
      .string
      | test("(\\(\\([[:alnum:]]*\\)\\))")
    )
  )
  | walk(
    if type == "object" then
      .string |= (
        match("\\(\\(([[:alnum:]]*)\\)\\)"; "g") as $mdata
        | gsub(
            "\\(\\(" + $mdata.captures[0].string + "\\)\\)";
            $blocks[$mdata.captures[0].string];
            "g"
          )
      )
    else
      .
    end
  )
;

def _blockObj:
  {
    string,
    uid,
    heading,
    "text-align",
    children: [.children[]? | .. | objects | _blockObj]
  }
;
def _pageObj:
  {title, children: [.children[] | .. | objects | _blockObj]}
;

def _pageRef($base): "\\[\\[" + $base + "\\]\\]";
def _tag($base): "#" + _pageRef($base);

# Page Titles
def pageTitles:
  .[].title
;
def sortedPageTitles(o):
  sort_by(.title)
  | _order(o)
  | pageTitles
;
def sortedPageTitles: sortedPageTitles("asc");

# Simple finders
def _coreFinder(tester):
  recurse
  | arrays
  | map(
      select(
        .string
        | strings
        | tester
      )
    )
  | select(. | length | . != 0)[]
  | _blockObj
;

def findBlocksWithTag($tag):
  _coreFinder(test(_tag($tag)))
;

def findBlocksWithPageRef($page):
  _coreFinder(test(_pageRef($page)))
;

# TODO Other Finders
# - find pages that have refs or tags
# - find pages that do not
# - generalized query?


# Pages
def pages:
  map(
    {title}
  )
;

# Blocks
def blocks:
  reduce (..|select(type=="object" and has("string"))) as $item ({};
    .[$item.uid] = $item.string
  )
;

# Export
def exportRawPage($page):
  map(
    select(
      .title == $page
    )
  )
  | .[0]
  | _pageObj
;


def _exportMarkdownPage($page; filter):
  {
    "page": exportRawPage($page),
    "blocks": blocks
  } as $data 
  | $data.page
  | [
    {
      "h1": .title
    },
    # TODO
    # subheaders
    # unordered lists for children of children
    {
      "p": .children
            | filter
            | _replaceBlockRefs($data.blocks)
            | .[].string
    }
  ]
;
def exportMarkdownPage($page; $tag):
  _exportMarkdownPage($page; _filterBlocks(_tag($tag)))
;
def exportMarkdownPage($page):
  _exportMarkdownPage($page; .)
;