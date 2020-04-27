# Utils
def _order($o):
  if o == "desc" then
    reverse
  else # "asc" or default
    .
  end
;

def _isPage: type == "object" and has("title");
def _isBlock: type == "object" and has("string");
def _pageRef($base): "\\[\\[" + $base + "\\]\\]";
def _pageTag($base): "#" + _pageRef($base);
def _baseTag($base): "#" + $base;

# Replaces block refs with text mapping in $dbBlocks
def _replaceBlockRefs($dbBlocks):
  if $dbBlocks != null and test("\\(\\(([[:alnum:]]*)\\)\\)") then
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

def slimBlock($dbBlocks):
  {
    uid,
    string: (.string | _emptyString | _replaceBlockRefs($dbBlocks)),
    heading,
    children: [.children[]? | slimBlock($dbBlocks)]
  }
;
def slimPage($dbBlocks):
  {
    title,
    "create-time": .["create-time"],
    "edit-time": .["edit-time"],
    children: [.children[]? | slimBlock($dbBlocks)]
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
    . + [($item | slimBlock(null))]
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


# Blocks
def blocks:
  reduce (.. | select(_isBlock)) as $item ({};
    .[$item.uid] = $item.string
  )
;

# Pages
def pages:
  {
    "pages": .,
    "blocks": blocks
  } as $data
  | map(
    slimPage($data.blocks)
  )
;

def page($page):
  pages
  | map(select(.title == $page))
  | first
;

# Markdown

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
def _mBlockList:
  reduce (.children[]?) as $listItem ([];
    . + if ($listItem.children? | length) > 0 then
      [
        ($listItem.string),
        {
          "ul": ($listItem | _mBlockList)
        }
      ]
    else
      [$listItem.string]
    end
  )
;
def _mBlockListElem:
  if (.children? | length) > 0 then
    [{
      "ul": _mBlockList
    }]
  else
    null
  end
;
def _mBlock:
  [{
    (.heading? | _blockMarkdownTag): .string
  }] + _mBlockListElem
;
# . is array of pages or page
# TODO handle array
def markdown:
  reduce (.children[]) as $item ([{
    "h1": .title
  }];
    . += ($item | _mBlock)
  )
;

def removeBlocks(filter):
  .children |= map(
    select(filter == false)
  )
  | .children[]? |= removeBlocks(filter)
;
def rb(filter): removeBlocks(filter);

def withTag($tag):
  (.string | test(_baseTag($tag))) or (.string | test(_pageTag($tag)))
;
def wt($tag): withTag($tag);
def withoutTag($tag):
  wt($tag) == false
;
def wot($tag): withoutTag($tag);

def withPageRef($pageRef):
  .string | test(_pageRef($pageRef))
;
def wpr($pageRef): withPageRef($pageRef);
def withoutPageRef($pageRef):
  wpr($pageRef) == false
;
def wopr($pageRef): withoutPageRef($pageRef);
;