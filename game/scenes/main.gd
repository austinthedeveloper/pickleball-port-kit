## Top level: title <-> match, with the save loaded once and written at
## safe points (leaving the title, a match's end).
extends Node

var save := SaveGame.new()
var _screen: Node


func _ready() -> void:
	save.load_game()
	show_title()


func _swap(n: Node) -> void:
	if _screen:
		_screen.queue_free()
	_screen = n
	add_child(n)


func show_title() -> void:
	var t := TitleScreen.new()
	t.save = save
	t.start_match.connect(_on_start)
	_swap(t)


func _on_start(cfg: SimTypes.MatchConfig, venue: String, ladder: bool) -> void:
	save.save_game()
	var m := MatchView.new()
	m.save = save
	m.ladder = ladder
	m.finished.connect(func(_to_title: bool): show_title())
	m.next_rung.connect(_on_next_rung.bind(cfg))
	_swap(m)
	m.camera_percent = TitleScreen.CAMERAS[TitleScreen.camera_i]
	m.court = TitleScreen.court.duplicate()
	m.setup(cfg, venue, false)


## A ladder win: the next opponent, at their home court, with their card.
func _on_next_rung(prev: SimTypes.MatchConfig) -> void:
	var rung: int = save.data["records"]["ladder_rung"]
	var cfg := TitleScreen.config_for(prev.mode == K.MODE_DOUBLES, rung, prev.difficulty,
		prev.points_to_win, TitleScreen.p1_choice)
	cfg.modifiers = prev.modifiers
	_on_start(cfg, TitleScreen.home_venue(rung), true)
