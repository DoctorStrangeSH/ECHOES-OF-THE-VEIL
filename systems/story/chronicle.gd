class_name Chronicle
extends RefCounted
## The Chronicle (R6a): the story so far, told as a book in the journal.
## Chapters and pages are data (data/story/chronicle.json); each shows once its
## condition holds, so the book follows the player's own choices.

const PATH := "res://data/story/chronicle.json"
const SEEN_FLAG := &"chronicle.pages"

static var _chapters: Array = []


static func chapters() -> Array:
	if _chapters.is_empty():
		var d: Variant = DataFiles.read_json(PATH)
		if d is Dictionary:
			_chapters = d.get("chapters", [])
	return _chapters


## Chapters the player has reached, in book order.
static func open_chapters() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Dictionary in chapters():
		if StoryRules.evaluate(c.get("if", {})):
			out.append(c)
	return out


## The text keys of a chapter's visible pages.
static func pages(chapter: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for p: Dictionary in chapter.get("pages", []):
		if StoryRules.evaluate(p.get("if", {})):
			out.append(String(p["text"]))
	return out


static func finished(chapter: Dictionary) -> bool:
	var done: Dictionary = chapter.get("done_if", {})
	return done.is_empty() or StoryRules.evaluate(done)


static func page_count() -> int:
	var n := 0
	for c in open_chapters():
		n += pages(c).size()
	return n


## True when pages appeared since the last call (and remembers the new count).
static func check_new() -> bool:
	if not GameState.is_playing:
		return false
	var n := page_count()
	var seen := int(GameState.get_flag(SEEN_FLAG, 0))
	if n == seen:
		return false
	GameState.set_flag(SEEN_FLAG, n)
	return n > seen
