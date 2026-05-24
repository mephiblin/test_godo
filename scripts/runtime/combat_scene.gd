extends Control

var info_label: RichTextLabel
var enemy_stage: PanelContainer
var enemy_name_label: Label
var enemy_status_label: Label
var enemy_hp_bar: ProgressBar
var enemy_guard_bar: ProgressBar
var party_hp_bar: ProgressBar
var combat_intent_label: RichTextLabel
var roll_container: HBoxContainer
var runtime := preload("res://scripts/runtime/combat_runtime.gd").new()
const CombatHudPresenter = preload("res://scripts/runtime/combat_hud_presenter.gd")
var defeat_overlay: Control
var victory_overlay: Control

func setup(payload: Dictionary) -> void:
	runtime.setup(payload)

func _ready() -> void:
	if runtime.monster_id == "" and not GameApp.pending_combat_context.is_empty():
		setup(GameApp.pending_combat_context)
	anchor_right = 1.0
	anchor_bottom = 1.0
	var bg := ColorRect.new()
	bg.color = Color("110f14")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var panel := PanelContainer.new()
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 60
	panel.offset_top = 40
	panel.offset_right = -60
	panel.offset_bottom = -40
	add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)

	var title := Label.new()
	title.text = "Combat: %s" % runtime.enemy_name
	title.add_theme_font_size_override("font_size", 28)
	layout.add_child(title)

	enemy_stage = PanelContainer.new()
	enemy_stage.custom_minimum_size = Vector2(760, 170)
	layout.add_child(enemy_stage)
	var stage_layout := HBoxContainer.new()
	stage_layout.add_theme_constant_override("separation", 14)
	enemy_stage.add_child(stage_layout)

	var enemy_silhouette := PanelContainer.new()
	enemy_silhouette.custom_minimum_size = Vector2(140, 140)
	stage_layout.add_child(enemy_silhouette)
	var enemy_symbol := Label.new()
	enemy_symbol.text = "ENEMY"
	enemy_symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_symbol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	enemy_symbol.add_theme_font_size_override("font_size", 24)
	enemy_silhouette.add_child(enemy_symbol)

	var stage_stats := VBoxContainer.new()
	stage_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_layout.add_child(stage_stats)
	enemy_name_label = Label.new()
	enemy_name_label.add_theme_font_size_override("font_size", 22)
	stage_stats.add_child(enemy_name_label)
	enemy_hp_bar = ProgressBar.new()
	enemy_hp_bar.custom_minimum_size = Vector2(520, 24)
	enemy_hp_bar.show_percentage = false
	stage_stats.add_child(enemy_hp_bar)
	enemy_guard_bar = ProgressBar.new()
	enemy_guard_bar.custom_minimum_size = Vector2(520, 18)
	enemy_guard_bar.show_percentage = false
	stage_stats.add_child(enemy_guard_bar)
	party_hp_bar = ProgressBar.new()
	party_hp_bar.custom_minimum_size = Vector2(520, 20)
	party_hp_bar.show_percentage = false
	stage_stats.add_child(party_hp_bar)
	enemy_status_label = Label.new()
	stage_stats.add_child(enemy_status_label)
	combat_intent_label = RichTextLabel.new()
	combat_intent_label.bbcode_enabled = true
	combat_intent_label.fit_content = true
	combat_intent_label.custom_minimum_size = Vector2(520, 46)
	stage_stats.add_child(combat_intent_label)

	info_label = RichTextLabel.new()
	info_label.custom_minimum_size = Vector2(640, 140)
	info_label.bbcode_enabled = true
	layout.add_child(info_label)

	roll_container = HBoxContainer.new()
	roll_container.add_theme_constant_override("separation", 10)
	layout.add_child(roll_container)

	var controls := HBoxContainer.new()
	layout.add_child(controls)
	for spec in [
		{"label": "Stop Dice", "action": Callable(self, "_stop_dice")},
		{"label": "Confirm Selection", "action": Callable(self, "_confirm_selection")},
		{"label": "Target Enemy", "action": Callable(self, "_select_enemy_target")},
		{"label": "Clear Selection", "action": Callable(self, "_clear_selection")},
		{"label": "Swap", "action": Callable(self, "_swap_selected_rolls")},
		{"label": "Use Item", "action": Callable(self, "_use_item")},
		{"label": "Tonic", "action": Callable(self, "_queue_tonic")},
		{"label": "Bandage", "action": Callable(self, "_queue_bandage")},
		{"label": "Antivenom", "action": Callable(self, "_queue_antivenom")},
		{"label": "Knife", "action": Callable(self, "_queue_throwing_knife")},
		{"label": "Firebomb", "action": Callable(self, "_queue_firebomb")},
		{"label": "Flee", "action": Callable(self, "_flee")}
	]:
		var button := Button.new()
		button.text = spec["label"]
		button.pressed.connect(spec["action"])
		controls.add_child(button)
	_refresh()

func _process(_delta: float) -> void:
	runtime.tick_spinning()
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_2, KEY_3:
				runtime.toggle_roll(int(event.keycode - KEY_1))
				_refresh()
			KEY_SPACE:
				_stop_dice()
			KEY_ENTER:
				_confirm_selection()
			KEY_C:
				_clear_selection()
			KEY_X:
				_swap_selected_rolls()

func _refresh() -> void:
	var vm := runtime.build_view_model()
	for child in roll_container.get_children():
		child.queue_free()
	for row_variant in vm.get("rolls", []):
		var row: Dictionary = row_variant
		var button := Button.new()
		var selected: bool = runtime.selected_roll_ids.has(int(row.get("id", 0)))
		button.text = CombatHudPresenter.build_roll_button_text(row, selected)
		button.custom_minimum_size = Vector2(140, 92)
		var roll_id := int(row.get("id", 0))
		button.pressed.connect(func() -> void:
			runtime.toggle_roll(roll_id)
			_refresh()
		)
		roll_container.add_child(button)
	info_label.text = CombatHudPresenter.build_info_text(vm)
	_refresh_stage(vm)

func _refresh_stage(vm: Dictionary) -> void:
	var enemy_hp := int(vm.get("enemyHp", 0))
	var enemy_max_hp := maxi(int(vm.get("enemyMaxHp", 1)), 1)
	var party_hp := int(vm.get("partyHp", 0))
	var party_max_hp := maxi(int(vm.get("partyMaxHp", 1)), 1)
	var enemy_guard := int(vm.get("enemyGuardPoints", 0))
	enemy_name_label.text = "%s  HP %d/%d" % [String(vm.get("enemyName", runtime.enemy_name)), enemy_hp, enemy_max_hp]
	enemy_hp_bar.max_value = enemy_max_hp
	enemy_hp_bar.value = clampi(enemy_hp, 0, enemy_max_hp)
	enemy_guard_bar.max_value = maxi(enemy_guard, 8)
	enemy_guard_bar.value = enemy_guard
	enemy_guard_bar.tooltip_text = "Enemy Guard %d" % enemy_guard
	party_hp_bar.max_value = party_max_hp
	party_hp_bar.value = clampi(party_hp, 0, party_max_hp)
	party_hp_bar.tooltip_text = "Party HP %d/%d" % [party_hp, party_max_hp]
	var enemy_status := ", ".join(vm.get("enemyStatuses", [])) if not vm.get("enemyStatuses", []).is_empty() else "-"
	var front_status := ", ".join(vm.get("frontStatuses", [])) if not vm.get("frontStatuses", []).is_empty() else "-"
	enemy_status_label.text = "Enemy status: %s     Front status: %s" % [enemy_status, front_status]
	combat_intent_label.text = CombatHudPresenter.build_intent_text(vm)

func _handle_outcome(outcome: Dictionary) -> void:
	if bool(outcome.get("exit", false)):
		if not bool(outcome.get("victory", false)):
			_show_defeat_overlay(outcome.get("summary", runtime.build_defeat_summary()))
			return
		_show_victory_overlay(outcome.get("summary", runtime.build_victory_summary()))
		return
	_refresh()

func _stop_dice() -> void:
	runtime.stop_dice()
	_refresh()

func _confirm_selection() -> void:
	_handle_outcome(runtime.confirm_selection())

func _select_enemy_target() -> void:
	_handle_outcome(runtime.select_target("enemy_0"))

func _clear_selection() -> void:
	runtime.clear_selection()
	_refresh()

func _swap_selected_rolls() -> void:
	runtime.swap_selected_rolls()
	_refresh()

func _flee() -> void:
	_handle_outcome(runtime.flee())

func _use_item() -> void:
	_handle_outcome(runtime.use_item())

func _queue_tonic() -> void:
	_handle_outcome(runtime.pick_item("healing_tonic"))

func _queue_bandage() -> void:
	_handle_outcome(runtime.pick_item("bandage"))

func _queue_antivenom() -> void:
	_handle_outcome(runtime.pick_item("antivenom"))

func _queue_throwing_knife() -> void:
	_handle_outcome(runtime.pick_item("throwing_knife"))

func _queue_firebomb() -> void:
	_handle_outcome(runtime.pick_item("firebomb"))

func smoke_win() -> void:
	var outcome := runtime.smoke_win()
	if bool(outcome.get("exit", false)) and bool(outcome.get("victory", false)):
		GameApp.exit_combat(true)
		return
	_handle_outcome(outcome)

func smoke_use_item(item_id: String) -> void:
	_handle_outcome(runtime.smoke_use_item(item_id))

func smoke_probe_target_and_cooldown() -> Dictionary:
	return runtime.smoke_probe_target_and_cooldown()

func smoke_probe_item_commands(item_id: String) -> Dictionary:
	return runtime.smoke_probe_item_commands(item_id)

func smoke_probe_selection_commands() -> Dictionary:
	return runtime.smoke_probe_selection_commands()

func smoke_probe_enemy_turn() -> Dictionary:
	return runtime.smoke_probe_enemy_turn()

func debug_combat_state() -> Dictionary:
	return runtime.debug_combat_state()

func debug_skill_ids() -> Array[String]:
	return runtime.debug_skill_ids()

func debug_roll_rows() -> Array[Dictionary]:
	return runtime.debug_roll_rows()

func smoke_lose() -> void:
	_handle_outcome(runtime.smoke_lose())

func smoke_recover_in_town() -> void:
	SaveService.record_defeat(runtime.slot, runtime.build_defeat_summary(), false)
	SceneRouter.change_route(GameApp.MODE_TOWN, {
		"slot": runtime.slot,
		"map_id": "town_square",
		"dungeon_source": GameApp.dungeon_runtime_source
	})

func smoke_return_title_after_defeat() -> void:
	SaveService.record_defeat(runtime.slot, runtime.build_defeat_summary(), true)
	SceneRouter.change_route(GameApp.MODE_TITLE, {})

func _show_defeat_overlay(summary: Dictionary) -> void:
	if defeat_overlay != null:
		defeat_overlay.queue_free()
	var overlay := PanelContainer.new()
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.offset_left = 180
	overlay.offset_top = 120
	overlay.offset_right = -180
	overlay.offset_bottom = -120
	add_child(overlay)
	defeat_overlay = overlay
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	overlay.add_child(box)
	var title := Label.new()
	title.text = "Defeat"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.custom_minimum_size = Vector2(520, 180)
	body.text = "[b]Enemy[/b] %s\n[b]Next[/b] Recover in town or return to title\n[b]Penalty[/b] 20%% gold, minimum 10 if possible\n[b]Current Gold[/b] %d\n[b]Statuses[/b] %s\n[b]Log[/b]\n%s" % [
		String(summary.get("enemyName", "Unknown Enemy")),
		int(summary.get("gold", 0)),
		str(summary.get("statuses", [])),
		"\n".join(summary.get("logTail", []))
	]
	box.add_child(body)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	var town_button := Button.new()
	town_button.text = "Recover In Town"
	town_button.pressed.connect(func() -> void:
		GameApp.handle_combat_defeat(summary, false)
	)
	buttons.add_child(town_button)
	var title_button := Button.new()
	title_button.text = "Return To Title"
	title_button.pressed.connect(func() -> void:
		GameApp.handle_combat_defeat(summary, true)
	)
	buttons.add_child(title_button)

func _show_victory_overlay(summary: Dictionary) -> void:
	if victory_overlay != null:
		victory_overlay.queue_free()
	var overlay := PanelContainer.new()
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.offset_left = 160
	overlay.offset_top = 110
	overlay.offset_right = -160
	overlay.offset_bottom = -110
	add_child(overlay)
	victory_overlay = overlay
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	overlay.add_child(box)
	var title := Label.new()
	title.text = "Victory"
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.custom_minimum_size = Vector2(560, 190)
	body.text = CombatHudPresenter.build_victory_text(summary)
	box.add_child(body)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	var continue_button := Button.new()
	continue_button.text = "Return To Dungeon"
	continue_button.pressed.connect(func() -> void:
		GameApp.exit_combat(true)
	)
	buttons.add_child(continue_button)
	var inventory_button := Button.new()
	inventory_button.text = "Continue And Review Later"
	inventory_button.pressed.connect(func() -> void:
		GameApp.exit_combat(true)
	)
	buttons.add_child(inventory_button)
