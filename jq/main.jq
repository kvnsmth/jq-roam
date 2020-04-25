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

# Reducers
def _coreReduce(tester):
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

def blockReduceTag($tag):
  _coreReduce(test(_tag($tag)))
;

def blockReducePageRef($page):
  _coreReduce(test(_pageRef($page)))
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
  exportRawPage($page)
  | [
    {
      "h1": .title
    },
    {
      "p": .children | filter | .[].string
    }
  ]
;
def exportMarkdownPage($page; $tag):
  _exportMarkdownPage($page; _filterBlocks(_tag($tag)))
;
def exportMarkdownPage($page):
  _exportMarkdownPage($page; .)
;