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

# Replaces block refs with text mapping in $dbBlocks
def _replaceBlockRefs($dbBlocks):
  if test("\\(\\(([[:alnum:]]*)\\)\\)") then
    # wrap the match call in brackets to put outputs
    # in a single array
    [match("\\(\\(([[:alnum:]]*)\\)\\)"; "g")] as $matches
    | reduce $matches[] as $match (.;
      . |= gsub(
        "\\(\\(" + $match.captures[0].string + "\\)\\)";
        $dbBlocks[$match.captures[0].string];
        "g"
      )
    )
  else
    .
  end
;

def _emptyString:
  . // ""
;

def slimBlock:
  {
    uid,
    string,
    heading,
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

# . is a heading from a block
def _blockMarkdownTag:
  if . == 1 then
    "h1"
  elif . == 2 then
    "h2"
  elif . == 3 then
    "h3"
  else
    "p"
  end
;
# . is a string
def _mString($dbBlocks):
  _emptyString  | _replaceBlockRefs($dbBlocks)
;
def _mBlockList($dbBlocks):
  reduce .children[]? as $listItem ([];
    . + if ($listItem.children? | length) > 0 then
      [
        ($listItem.string | _mString($dbBlocks)),
        {
          "ul": ($listItem | _mBlockList($dbBlocks))
        }
      ]
    else
      [($listItem.string | _mString($dbBlocks))]
    end
  )
;
def _mBlockListElem($item; $dbBlocks):
  if ($item.children? | length) > 0 then
    [{
      "ul": ($item | _mBlockList($dbBlocks))
    }]
  else
    null
  end
;
def _mBlock($item; $dbBlocks):
  [{
    ($item.heading? | _blockMarkdownTag): (
      $item.string | _mString($dbBlocks)
    )
  }]
  | (. + _mBlockListElem($item; $dbBlocks))
;

def _exportMarkdownPage($page; blockFilter):
  {
    "page": exportRawPage($page),
    "blocks": blocks
  } as $data
  | $data.blocks as $dbBlocks
  | reduce $data.page.children[] as $item ([{
      "h1": $data.page.title
    }];
    . += ($item | _mBlock($item; $dbBlocks))
  )
;
def exportMarkdownPage($page; $tag):
  _exportMarkdownPage($page; _filterBlocks(_tag($tag)))
;
def exportMarkdownPage($page):
  _exportMarkdownPage($page; .)
;