# A few utility functions to clean up code
def _isPage: type == "object" and has("title");
def _isBlock: type == "object" and has("string");
def _pageRef($base): "\\[\\[" + $base + "\\]\\]";
def _pageTag($base): "#" + _pageRef($base);
def _baseTag($base): "#" + $base;
# regex based on nanoid.js's character class
def _blockRefRegex: "\\(\\(([A-Za-z0-9\\-\\_]*)\\)\\)";

# Replaces block refs with text mapping in $dbBlocks
def _replaceBlockRefs($dbBlocks):
  if $dbBlocks != null and test(_blockRefRegex) then
    # wrap the match call in brackets to put outputs
    # in a single array
    [match(_blockRefRegex; "g")] as $matches
    | if $matches | length > 0 then
      reduce $matches[] as $match (.;
        . |= gsub(
          "\\(\\(" + $match.captures[0].string + "\\)\\)";
          $dbBlocks[$match.captures[0].string];
          "g"
        )
      )
    | _replaceBlockRefs($dbBlocks)
    else
      .
    end 
  else
    .
  end
;

# --------------
# Blocks
# --------------
def slimBlock($dbBlocks):
  def _rbr:
    if $dbBlocks != null then
      _replaceBlockRefs($dbBlocks)
    else
      .
    end
  ;
  {
    uid,
    string: ((.string // "") | _rbr),
    heading,
    "create-time": .["create-time"],
    "edit-time": .["edit-time"],
    children: [.children[]? | slimBlock($dbBlocks)]
  }
;

def _basicBlocks:
  reduce (.. | select(_isBlock)) as $item ([];
    . + [$item]
  )
;

# creates a key-value data structure that is useful
# for looking blocks up by their uid
def blocksLookupTable:
  _basicBlocks
  | reduce .[] as $item ({};
    .[$item.uid] = $item.string
  )
;

def blocks:
  {
    "blocks": _basicBlocks,
    "dbBlocks": blocksLookupTable
  } as $data
  | reduce $data.blocks[] as $item ([];
    . + [$item | slimBlock($data.dbBlocks)]
  )
;

def removeBlocks(filter; $recursive):
  if $recursive == true then
    map(
      select(
        def _checkChildren:
          .children[]?
          | . as $child
          | (filter == false)
          | (. or ($child | _checkChildren))
        ;
        [filter == false, _checkChildren] | any
      )
    )
  else
    map(
      select(
        filter == false
      )
    )
  end
;
def rb(filter): removeBlocks(filter; false);

def children:
  map(
    .children[]?
  )
;

# --------------
# Pages
# --------------

# returns page object with every key
def slimPage($dbBlocks):
  {
    title,
    "create-time": .["create-time"],
    "edit-time": .["edit-time"],
    children: [.children[]? | slimBlock($dbBlocks)]
  }
;
def pages:
  {
    "pages": .,
    "blocks": blocksLookupTable
  } as $data
  | map(
    slimPage($data.blocks)
  )
;
def page($page):
  pages
  | map(select(.title == $page))
  | first // []
;

# --------------
# Markdown
# --------------
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
def markdown:
  if type == "array" then
    map(markdown)
  else
    if _isBlock then
      _mBlock
    else
      reduce (.children[]) as $item ([{
        "h1": .title
      }];
        . += ($item | _mBlock)
      )
    end
  end
;

# --------------
# Filering
# --------------

# TODO
# - make tags exact match, right now it will do prefix matching (eg "Person" matches #Personal)
# - filter for page titles
# - filter out daily notes pages
# - generic filter that handles page refs and tags
# - prefix filters (eg withPrefix("App") to match [[App/Roam]])
# - generic filter that does string contains on strings
# - inverse ops from remove, keepPages / keepBlocks

def removePages(filter):
  map(
    select(
      # recursively check children and accumulate filter responses
      def _checkChildren:
        .children[]?
        | . as $child
        | (filter == false)
        | (. or ($child | _checkChildren))
      ;
      [_checkChildren] | any
    )
  )
;
def rp(filter): removePages(filter);

def removePageBlocks(filter):
  if type == "array" then
    map(removePageBlocks(filter))
  else
    .children |= map(
      select(filter == false)
    )
    | .children[]? |= removePageBlocks(filter)
  end
;
def rpb(filter): removePageBlocks(filter);

# --------------
# Filter helpers
# --------------
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