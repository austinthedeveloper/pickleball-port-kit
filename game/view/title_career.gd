## The title's CAREER pages (ADR-047): the slots, a player's card, the
## editor (and its keyboard), drawn as MenuPages over CareerPage's logic.
## A component of TitleScreen (`t`), split out to keep the title small.
class_name TitleCareer
extends RefCounted

var t: TitleScreen
var delete_armed := false


func _init(title: TitleScreen) -> void:
	t = title


func career() -> Career:
	return t.save.career if t.save else t._spare_career


## The player on the card and the editor.
func cp() -> Career.Player:
	return career().players[t.career_page.slot]


func label() -> String:
	var me := career().active_player()
	return me.shown_name() if me else "NO PLAYER"


func build_pages() -> void:
	var slot_rows := []
	for i in Career.SLOTS:
		var slot := i
		slot_rows.append({"id": "slot%d" % slot,
			"label": func(): return career().players[slot].shown_name() if career().players[slot].used else "NEW PLAYER",
			"value": func(): return slot_value(slot), "press": func(): row(slot)})
	slot_rows.append({"id": "nobody", "label": "NO PLAYER",
		"value": func(): return "ACTIVE" if career().active_player() == null else "",
		"press": func(): row(CareerPage.ROW_NOBODY)})
	slot_rows.append({"id": "records", "label": "RECORDS", "press": func(): row(CareerPage.ROW_RECORDS)})
	t._add_page("career", "CAREER", slot_rows, [["hit", "OPEN"], ["back", "BACK"]], Rect2(240, 140, 480, 0))
	t._add_page("career_card", "PLAYER", [
		{"id": "singles", "label": "SINGLES", "value": func(): return "%d-%d" % [cp().wins[0], cp().losses[0]]},
		{"id": "doubles", "label": "DOUBLES", "value": func(): return "%d-%d" % [cp().wins[1], cp().losses[1]]},
		{"id": "aces", "label": "ACES", "value": func(): return str(cp().aces)},
		{"id": "shutouts", "label": "SHUTOUTS", "value": func(): return str(cp().shutouts)},
		{"id": "streak", "label": "BEST STREAK", "value": func(): return str(cp().best_streak)},
		{"id": "rally", "label": "LONGEST RALLY", "value": func(): return str(cp().longest_rally)},
		{"id": "unlocks", "label": "UNLOCKS",
			"value": func(): return "%d/%d" % [Career.unlock_count(cp()), Career.unlocks()]},
		{"id": "next", "label": func(): return "NEXT UNLOCK" if next_unlock() < Career.unlocks() else "ALL UNLOCKED!",
			"value": func(): return Career.unlock_names[next_unlock()] if next_unlock() < Career.unlocks() else ""},
		{"id": "how", "label": func(): return "  " + Career.unlock_how[next_unlock()] if next_unlock() < Career.unlocks() else ""},
		{"id": "hats", "label": "HAT MUSEUM",
			"value": func(): return "%d OF %d" % [Career.hats_held(cp()), Museum.hats()],
			"press": func(): t.open_museum()},
		{"id": "edit", "label": "EDIT", "press": func(): input(CareerPage.PAD_B)},
		{"id": "delete", "label": "DELETE PLAYER", "value": func(): return "B AGAIN" if delete_armed else "",
			"press": delete},
	], [["hit", "SELECT"], ["back", "BACK"]], Rect2(380, 46, 500, 0))
	var edit_rows := [{"id": "name", "label": "NAME", "value": func(): return cp().shown_name(),
		"press": func(): edit_row(CareerPage.EDIT_NAME, CareerPage.PAD_B)}]
	var looks := [["body", "BODY", CareerPage.EDIT_BODY], ["skin", "SKIN", CareerPage.EDIT_SKIN],
		["hair", "HAIR", CareerPage.EDIT_HAIR], ["shirt", "SHIRT", CareerPage.EDIT_SHIRT],
		["hat", "HAT", CareerPage.EDIT_HAT], ["paddle", "PADDLE", CareerPage.EDIT_PADDLE]]
	for l in looks:
		var r: int = l[2]
		edit_rows.append({"id": l[0], "label": l[1], "value": func(): return look_name(r),
			"change": func(d): edit_row(r, CareerPage.PAD_RIGHT if d > 0 else CareerPage.PAD_LEFT)})
	edit_rows.append({"id": "gear", "label": "GEAR", "value": gear_text})
	edit_rows.append({"id": "keep", "label": "KEEP", "press": func(): input(CareerPage.PAD_START)})
	t._add_page("career_edit", "EDIT PLAYER", edit_rows, [["start", "KEEP"], ["back", "CANCEL"]],
		Rect2(380, 46, 500, 0))


func slot_value(slot: int) -> String:
	var p: Career.Player = career().players[slot]
	if not p.used:
		return ""
	return ("ACTIVE  " if career().active == slot else "") + "%d WINS" % (p.wins[0] + p.wins[1])


func next_unlock() -> int:
	return Career.next_unlock(cp())


## A look row's value as a name (hud_career_look_name).
func look_name(r: int) -> String:
	var v := CareerPage.look_value(cp(), r)
	match r:
		CareerPage.EDIT_BODY:
			return Career.body_name(v)
		CareerPage.EDIT_SKIN:
			return Career.skin_names[v % Career.skins()]
		CareerPage.EDIT_HAIR:
			return Career.hair_names[v % Career.hairs()]
		CareerPage.EDIT_SHIRT:
			return Career.shirt_name(v)
		CareerPage.EDIT_HAT:
			return Career.hat_names[v % Career.hats()]
	return Career.paddle_name(v)


## The editor's gear line (stage 4): the paddle's stats with the hat.
func gear_text() -> String:
	var st := Paddles.stats(Paddles.profile(cp().paddle, cp().hat))
	return "PWR %d  CTL %d  SPD %d" % [st[0], st[1], st[2]]


## The title's CAREER entry: the page opens on the active player (or NO
## PLAYER).
func open() -> void:
	t.career_page.begin(career())
	t.main_cursor = t.pages["main"].cursor
	sync(true)


## A SLOTS row pressed (keys or the mouse).
func row(r: int) -> void:
	t.career_page.row = r
	input(CareerPage.PAD_B)


## An EDIT row's Left/Right or B.
func edit_row(r: int, bits: int) -> void:
	t.career_page.row = r
	input(bits)


## DELETE PLAYER on the card: the first press arms, the second deletes
## (for the SNES's L+R+X).
func delete() -> void:
	if not delete_armed:
		delete_armed = true
		return
	delete_armed = false
	if t.career_page.delete_player() == CareerPage.SAVE and t.save:
		t.save.save_game()
	sync(true, -1)


## One press into the CAREER page's logic; SAVE writes, CLOSE goes back
## to MAIN, and a new view shows its page.
func input(bits: int) -> void:
	var was := page_id()
	var result := t.career_page.input(bits)
	if result == CareerPage.SAVE and t.save:
		t.save.save_game()
	if result == CareerPage.CLOSE:
		back_to_player()
		return
	var now := page_id()
	sync(now != was, 1 if depth(now) > depth(was) else -1)


func page_id() -> String:
	match t.career_page.view:
		CareerPage.VIEW_CARD:
			return "career_card"
		CareerPage.VIEW_EDIT:
			return "career_name" if t.career_page.naming else "career_edit"
		CareerPage.VIEW_RECORDS:
			return "records"
	return "career"


static func depth(id: String) -> int:
	return ["career", "career_card", "career_edit", "career_name"].find(id) if id != "records" else 1


## Shows the page for the CAREER view (sliding in when it changed) with
## the logic's row selected, and the portrait and keyboard up to date.
func sync(changed: bool, dir := 1) -> void:
	var id := page_id()
	if changed:
		t._show(id)
		if t.pages.has(id):
			t.pages[id].appear(dir)
		t._lock = t.SWITCH_LOCK
		GameControls.clear_latch()
	match t.career_page.view:
		CareerPage.VIEW_SLOTS:
			var r := t.career_page.row
			t.pages["career"].select("slot%d" % r if r < Career.SLOTS else
				("nobody" if r == CareerPage.ROW_NOBODY else "records"))
		CareerPage.VIEW_CARD:
			t.pages["career_card"].set_title(cp().shown_name())
			if changed:
				t.pages["career_card"].select("edit")
		CareerPage.VIEW_EDIT:
			t.pages["career_edit"].select(["name", "body", "skin", "hair", "shirt", "hat", "paddle"][t.career_page.row])
		CareerPage.VIEW_RECORDS:
			if changed:
				t.pages["records"].select("singles")
	t.career_preview.show_player(cp() if id != "career" and id != "records" else null)
	t.career_page.look_changed = false
	t.career_keyboard.refresh()
	if t.pages.has(id):
		t.pages[id].refresh()
	t.pages["main"].refresh()


## Back to PLAYER with the cursor on PLAYERS (Y from CAREER's slots).
func back_to_player() -> void:
	t._show("player")
	t.pages["player"].select("career")
	t.pages["player"].appear(-1)
	t._lock = t.SWITCH_LOCK
	GameControls.clear_latch()


## After a row was pressed (keys or the mouse): its sound, and the record line.
