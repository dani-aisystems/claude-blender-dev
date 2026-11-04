extends Node
## Autoload "SaveSystem": JSON save slots in user://saves/. Slot "auto" is written at chapter starts and
## after major beats; slots 1-3 are manual. Saves are taken only between story beats (never mid-dialogue),
## so loading can never replay half a scene or duplicate an event.

const DIR := "user://saves"
const VERSION := 1
const SLOTS := ["auto", "1", "2", "3"]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


func path(slot: String) -> String:
	return DIR.path_join("slot_%s.json" % slot)


func write(slot: String, data: Dictionary) -> bool:
	data["version"] = VERSION
	data["saved_at"] = Time.get_datetime_string_from_system(false, true)
	data["unix"] = Time.get_unix_time_from_system()
	var tmp := path(slot) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	# atomic-ish replace (the old file stays intact if the write failed)
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path(slot)))
	return true


## Returns {} for missing or corrupted saves (never crashes the menu).
func read(slot: String) -> Dictionary:
	if not FileAccess.file_exists(path(slot)):
		return {}
	var txt := FileAccess.get_file_as_string(path(slot))
	var d = JSON.parse_string(txt)
	if typeof(d) != TYPE_DICTIONARY or int(d.get("version", 0)) != VERSION or not d.has("story") or not d.has("sim"):
		return {"corrupt": true}
	return d


func exists(slot: String) -> bool:
	var d := read(slot)
	return not d.is_empty() and not d.has("corrupt")


## The most recent valid save (for Continue), or "" if none.
func latest() -> String:
	var best := ""
	var best_t := -1.0
	for s in SLOTS:
		var d := read(s)
		if d.is_empty() or d.has("corrupt"):
			continue
		if float(d.get("unix", 0)) > best_t:
			best_t = float(d["unix"])
			best = s
	return best


func summary(slot: String) -> String:
	var d := read(slot)
	if d.is_empty():
		return "— empty —"
	if d.has("corrupt"):
		return "— unreadable save —"
	var mins := int(float(d["story"].get("play_seconds", 0)) / 60.0)
	return "Ch. %d · %s · %s · played %d min · %s" % [int(d["story"].get("chapter", 1)), d.get("chapter_title", ""),
		d.get("clock", ""), mins, String(d.get("saved_at", "")).replace("T", " ").substr(0, 16)]


func delete(slot: String) -> void:
	if FileAccess.file_exists(path(slot)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path(slot)))
