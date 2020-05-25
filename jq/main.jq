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
def _slimBlock($dbBlocks):
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
    children: [.children[]? | _slimBlock($dbBlocks)]
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
    . + [$item | _slimBlock($data.dbBlocks)]
  )
;

def removeBlocks(filter; $recursive):
  # recursive removal is useful if you want to remove
  # a higher order block based on a nested block matching
  # a filter. see tests for example.
  if $recursive == true then
    map(
      select(
        def _checkChildren:
          .children[]?
          | . as $child
          | (filter[0] == false)
          | [., ($child | _checkChildren)]
        ;
        [(filter[0] == false), _checkChildren] | flatten | filter[1]
      )
    )
  else
    map(
      select(
        filter[0] == false
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
def _slimPage($dbBlocks):
  {
    title,
    "create-time": .["create-time"],
    "edit-time": .["edit-time"],
    children: [.children[]? | _slimBlock($dbBlocks)]
  }
;
def pages:
  {
    "pages": .,
    "blocks": blocksLookupTable
  } as $data
  | map(
    _slimPage($data.blocks)
  )
;
def page($page):
  pages
  | map(select(.title == $page))
  | first
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
        | (filter[0] == false)
        | [., ($child | _checkChildren)]
      ;
      [_checkChildren] | flatten | filter[1]
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
  [(try ((.string | test(_baseTag($tag))) or (.string | test(_pageTag($tag)))) catch true), all]
;
def wt($tag): withTag($tag);
def withoutTag($tag):
  [(wt($tag)[0] == false), any]
;
def wot($tag): withoutTag($tag);

def withPageRef($pageRef):
  [(try (.string | test(_pageRef($pageRef))) catch true), all]
;
def wpr($pageRef): withPageRef($pageRef);
def withoutPageRef($pageRef):
  [(wpr($pageRef)[0] == false), any]
;
def wopr($pageRef): withoutPageRef($pageRef);