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

def _isPage: type == "object" and has("title");
def _isBlock: type == "object" and has("string");
def _pageRef($base): "\\[\\[" + $base + "\\]\\]";
def _tag($base): "#" + _pageRef($base);

# Replaces block refs with text mapping in $blocks
# TODO: test this works with multiple refs
def _replaceBlockRefs($blocks):
  match("\\(\\(([[:alnum:]]*)\\)\\)"; "g") as $mdata
  | gsub(
      "\\(\\(" + $mdata.captures[0].string + "\\)\\)";
      $blocks[$mdata.captures[0].string];
      "g"
    )
;

def slimBlock:
  {
    uid,
    string,
    children: [.children[]? | slimBlock]
  }
;
def slimPage:
  {
    title,
    children: [.children[]? | slimBlock]
  }
;

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

# Simple block finders
def _coreBlockFinder(tester):
  reduce (
    ..
    | select(
        _isBlock
        and (.string | tester)
      )
  ) as $item ([];
    . + [($item | slimBlock)]
  )
;

#TODO add option to only include blocks and not children of blocks

def findBlocksWithTag($tag):
  _coreBlockFinder(test(_tag($tag)))
;

def findBlocksWithPageRef($page):
  _coreBlockFinder(test(_pageRef($page)))
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
  reduce (.. | select(_isBlock)) as $item ({};
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
  | first
  | slimPage
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