extends Control
## The Mantel — between-run hub: quest board, the Magpie Exchange (shop),
## achievements. 2-3 taps to be back in a prowl (design rule: never admin).

signal quest_selected(quest_id: String)
signal profile_changed
signal replay_prologue
signal open_journal

const ADD_CARD_COST := 12
const RARE_CARD_COST := 30
const REMOVE_CARD_COST := 15
const TONIC_COST := 25
const MAX_HP_CAP := 30

var catalog: Catalog
var profile: Dictionary
var tracker: AchievementTracker

var gleam_label: Label
var deck_label: Label
var loadout_title: Label
var loadout_flow: HFlowContainer
var achievements_label: Label
var shop_status: Label
var shop_detail: HBoxContainer
var _shop_mode := ""


func setup(p_catalog: Catalog, p_profile: Dictionary, p_tracker: AchievementTracker) -> void:
	catalog = p_catalog
	profile = p_profile
	tracker = p_tracker


func _ready() -> void:
	var margin := UITheme.page_scaffold(self)
	# The Mantel holds more than one screen of things; it scrolls.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(root)

	var title := _label(root, 48)
	title.text = "The Mantel"
	title.add_theme_font_override("font", UITheme.display_font())
	title.add_theme_color_override("font_color", UITheme.INK)
	var subtitle := _label(root, 24)
	subtitle.text = "Her parlor. Cold, but still hers. The thread runs out under the window."
	subtitle.add_theme_color_override("font_color", UITheme.INK_SOFT)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	gleam_label = _label(root, 30)
	gleam_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	deck_label = _label(root, 24)
	deck_label.add_theme_color_override("font_color", UITheme.INK_SOFT)
	deck_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Loadout picker: which 3 skills (plus Scratch, always) go on the prowl.
	# Chips rebuild on refresh so newly-earned skills appear immediately.
	loadout_title = _label(root, 24)
	loadout_title.add_theme_color_override("font_color", UITheme.INK_SOFT)
	loadout_title.text = "On the prowl — Scratch and three others. Tap to swap:"
	loadout_flow = HFlowContainer.new()
	loadout_flow.add_theme_constant_override("h_separation", 8)
	loadout_flow.add_theme_constant_override("v_separation", 6)
	root.add_child(loadout_flow)
	root.add_child(HSeparator.new())

	var board_title := _label(root, 32)
	board_title.text = "Quests on the board"
	for quest_id in catalog.quests:
		var quest: Dictionary = catalog.quests[quest_id]
		var b := Button.new()
		b.text = "%s\n%s" % [quest["name"], quest["board_card"]]
		b.custom_minimum_size = Vector2(0, 112)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(func() -> void: quest_selected.emit(quest_id))
		root.add_child(b)

	root.add_child(HSeparator.new())
	var shop_title := _label(root, 32)
	shop_title.text = "The Magpie Exchange"
	shop_status = _label(root, 24)
	shop_status.add_theme_color_override("font_color", UITheme.INK_SOFT)
	shop_status.text = "Brindle appraises you. 'Everything shines to somebody, pet.'"
	shop_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var shop_row := HBoxContainer.new()
	shop_row.add_theme_constant_override("separation", 8)
	root.add_child(shop_row)
	_shop_button(shop_row, "Add (%d)" % ADD_CARD_COST, "add")
	_shop_button(shop_row, "Rare (%d)" % RARE_CARD_COST, "rare")
	_shop_button(shop_row, "Cut (%d)" % REMOVE_CARD_COST, "remove")
	_shop_button(shop_row, "Tonic (%d)" % TONIC_COST, "tonic")

	shop_detail = HBoxContainer.new()
	shop_detail.add_theme_constant_override("separation", 6)
	root.add_child(shop_detail)

	var casebook := Button.new()
	casebook.text = "The Casebook — deeds & knowledge"
	casebook.custom_minimum_size = Vector2(0, 88)
	casebook.pressed.connect(func() -> void: open_journal.emit())
	root.add_child(casebook)
	var replay := Button.new()
	replay.text = "Relive the worst night (replay prologue)"
	replay.custom_minimum_size = Vector2(0, 84)
	replay.pressed.connect(func() -> void: replay_prologue.emit())
	root.add_child(replay)
	achievements_label = _label(root, 22)
	achievements_label.add_theme_color_override("font_color", UITheme.INK_SOFT)
	achievements_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	refresh()


func refresh() -> void:
	gleam_label.text = "Gleam: %d      HP: %d" % [
		int(profile["gleam"]), int(profile["max_hp"])]
	_clear(loadout_flow)
	var active := SaveService.battle_loadout(profile)
	for skill_id in profile.get("skills", []):
		if skill_id == "scratch":
			continue
		var chip := Button.new()
		chip.toggle_mode = true
		chip.text = String(catalog.skills[skill_id]["name"])
		chip.button_pressed = active.has(skill_id)
		chip.custom_minimum_size = Vector2(0, 48)
		chip.toggled.connect(_on_loadout_toggle.bind(skill_id))
		loadout_flow.add_child(chip)
	var counts := {}
	for card_id in profile["deck"]:
		var humour: String = catalog.energy_cards[card_id]["humour"]
		counts[humour] = int(counts.get(humour, 0)) + 1
	var parts: Array[String] = []
	for humour in ["ferocity", "guile", "shadow", "mysticism"]:
		parts.append("%s %d" % [Catalog.humour_name(humour), int(counts.get(humour, 0))])
	deck_label.text = "Deck (%d): %s" % [profile["deck"].size(), " · ".join(parts)]
	var visible_total := 0
	for id in catalog.achievements:
		if not catalog.achievements[id].get("hidden", false) or tracker.is_unlocked(id):
			visible_total += 1
	achievements_label.text = "Achievements: %d / %d unlocked%s" % [
		tracker.unlocked.size(), visible_total,
		"" if tracker.unlocked.is_empty() else "  ·  latest: " +
			String(catalog.achievements[tracker.unlocked.back()]["name"]),
	]


# ------------------------------------------------------------------ shop

func _shop_button(parent: Container, text: String, mode: String) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 56)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 22)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(_on_shop_mode.bind(mode))
	parent.add_child(b)


func _on_shop_mode(mode: String) -> void:
	_clear(shop_detail)
	_shop_mode = mode
	match mode:
		"add":
			if int(profile["gleam"]) < ADD_CARD_COST:
				return _say_broke()
			shop_status.text = "'An appetite for what, exactly?'"
			for humour in ["ferocity", "guile", "shadow", "mysticism"]:
				var b := Button.new()
				b.text = Catalog.humour_name(humour) + " 2"
				b.custom_minimum_size = Vector2(0, 48)
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				b.pressed.connect(_on_add_card.bind(humour))
				shop_detail.add_child(b)
		"rare":
			# The good shelf: value-3 cards, one price tier up. This is the
			# only acquisition route for the _3s (they are NOT starter kit —
			# owner rarity rule).
			if int(profile["gleam"]) < RARE_CARD_COST:
				return _say_broke()
			shop_status.text = "'Ah. The good shelf. For a discerning paw.'"
			for humour in Catalog.HUMOURS:
				var card_id := humour + "_3"
				var b := Button.new()
				b.text = "%s (%s)" % [String(catalog.energy_cards[card_id]["name"]),
					Catalog.humour_name(humour)]
				b.custom_minimum_size = Vector2(0, 48)
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				b.pressed.connect(_on_add_rare_card.bind(card_id))
				shop_detail.add_child(b)
		"remove":
			if int(profile["gleam"]) < REMOVE_CARD_COST:
				return _say_broke()
			if profile["deck"].size() <= 10:
				shop_status.text = "'Any thinner and you'll be running on spite alone. No.'"
				return
			shop_status.text = "'Letting go. The rarest purchase. Which one?'"
			var seen := {}
			for card_id in profile["deck"]:
				if seen.has(card_id):
					continue
				seen[card_id] = true
				var b := Button.new()
				b.text = String(catalog.energy_cards[card_id]["name"])
				b.custom_minimum_size = Vector2(0, 48)
				b.pressed.connect(_on_remove_card.bind(card_id))
				shop_detail.add_child(b)
		"tonic":
			if int(profile["gleam"]) < TONIC_COST:
				return _say_broke()
			if int(profile["max_hp"]) >= MAX_HP_CAP:
				shop_status.text = "'You are one cat. There are limits. That was the last one.'"
				return
			profile["gleam"] = int(profile["gleam"]) - TONIC_COST
			profile["max_hp"] = int(profile["max_hp"]) + 2
			shop_status.text = "'Drink it all. Yes, it tastes like pond. Medicinal pond.'"
			profile_changed.emit()
			refresh()


func _on_add_card(humour: String) -> void:
	profile["gleam"] = int(profile["gleam"]) - ADD_CARD_COST
	profile["deck"].append(humour + "_2")
	shop_status.text = "'A fine choice. It fell off a windowsill, if anyone asks.'"
	_clear(shop_detail)
	profile_changed.emit()
	refresh()


func _on_add_rare_card(card_id: String) -> void:
	profile["gleam"] = int(profile["gleam"]) - RARE_CARD_COST
	profile["deck"].append(card_id)
	shop_status.text = "'Wrapped in yesterday's obituaries. For dignity.'"
	_clear(shop_detail)
	profile_changed.emit()
	refresh()


func _on_remove_card(card_id: String) -> void:
	profile["gleam"] = int(profile["gleam"]) - REMOVE_CARD_COST
	profile["deck"].erase(card_id)
	shop_status.text = "'Gone. You'll feel lighter on the stairs.'"
	_clear(shop_detail)
	profile_changed.emit()
	refresh()


func _on_loadout_toggle(pressed: bool, skill_id: String) -> void:
	# Materialize the current (possibly auto-derived) loadout, then apply.
	var picked: Array = SaveService.battle_loadout(profile)
	picked.erase("scratch")
	if pressed and not picked.has(skill_id):
		picked.append(skill_id)
		while picked.size() > 3:
			picked.pop_front()  # the oldest pick steps aside
	elif not pressed:
		picked.erase(skill_id)
	profile["loadout"] = picked
	profile_changed.emit()
	refresh()


func _say_broke() -> void:
	shop_status.text = "'Sentiment is lovely. Gleam is lovelier. Come back shinier.'"


func _label(parent: Container, size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label


func _clear(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
