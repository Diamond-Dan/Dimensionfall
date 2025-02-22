extends Control

# This scene is intended to be used inside the content editor
# It is supposed to edit exactly one mob (friend and foe)
# It expects to save the data to a DMob instance that contains all data from a mob
# To load data, provide the DMob to edit

@export var mobImageDisplay: TextureRect = null
@export var IDTextLabel: Label = null
@export var PathTextLabel: Label = null
@export var NameTextEdit: TextEdit = null
@export var faction_option_button: OptionButton = null
@export var DescriptionTextEdit: TextEdit = null
@export var mobSelector: Popup = null
@export var health_numedit: SpinBox
@export var moveSpeed_numedit: SpinBox
@export var idle_move_speed_numedit: SpinBox
@export var sightRange_numedit: SpinBox
@export var senseRange_numedit: SpinBox
@export var hearingRange_numedit: SpinBox
@export var ItemGroupTextEdit: TextEdit = null
@export var dash_check_box: CheckBox = null
@export var dash_speed_multiplier_spin_box: SpinBox = null
@export var dash_duration_spin_box: SpinBox = null
@export var dash_cooldown_spin_box: SpinBox = null

# Combat properties:
@export var attack_type_option_button: OptionButton = null

@export var melee_h_box_container: HBoxContainer = null
@export var melee_range_numedit: SpinBox
@export var melee_cooldown_spinbox: SpinBox = null
@export var melee_knockback_spinbox: SpinBox = null

@export var ranged_h_box_container: HBoxContainer = null
@export var ranged_range_spin_box: SpinBox = null
@export var ranged_cooldown_spin_box: SpinBox = null
@export var projectile_texture_rect: TextureRect = null

@export var any_of_attributes_grid_container: GridContainer = null
@export var all_of_attributes_grid_container: GridContainer = null

# Track which TextureRect triggered the mobSelector
var selected_texture_rect: TextureRect = null

signal data_changed()
var olddata: DMob # Remember what the value of the data was before editing
# The data that represents this mob
# The data is selected from dmob.parent
# based on the ID that the user has selected in the content editor
var dmob: DMob:
	set(value):
		dmob = value
		load_mob_data()
		mobSelector.sprites_collection = dmob.parent.sprites
		olddata = DMob.new(dmob.get_data().duplicate(true), null)



# Forward drag-and-drop functionality to the attributesGridContainer
func _ready() -> void:
	any_of_attributes_grid_container.set_drag_forwarding(Callable(), _can_drop_attribute_data, _drop_any_of_attribute_data)
	all_of_attributes_grid_container.set_drag_forwarding(Callable(), _can_drop_attribute_data, _drop_all_of_attribute_data)

	attack_type_option_button.item_selected.connect(_on_attack_type_option_button_item_selected)


# This function update the form based on the DMob data that has been loaded
func load_mob_data() -> void:
	if mobImageDisplay != null:
		mobImageDisplay.texture = dmob.sprite
		PathTextLabel.text = dmob.spriteid
	if IDTextLabel != null:
		IDTextLabel.text = str(dmob.id)
	if NameTextEdit != null:
		NameTextEdit.text = dmob.name
	if DescriptionTextEdit != null:
		DescriptionTextEdit.text = dmob.description
	if melee_range_numedit != null:
		melee_range_numedit.value = dmob.melee_range
	if melee_cooldown_spinbox != null:
		melee_cooldown_spinbox.value = dmob.melee_cooldown
	if melee_knockback_spinbox != null:
		melee_knockback_spinbox.value = dmob.melee_knockback
	if ranged_range_spin_box != null:
		ranged_range_spin_box.value = max(dmob.ranged_range, 0)
	if ranged_cooldown_spin_box != null:
		ranged_cooldown_spin_box.value = max(dmob.ranged_cooldown, 0)
	if projectile_texture_rect != null:
		projectile_texture_rect.texture = dmob.projectile_sprite if dmob.projectile_sprite else preload("res://Textures/bullet.png")
	if health_numedit != null:
		health_numedit.value = dmob.health
	if moveSpeed_numedit != null:
		moveSpeed_numedit.value = dmob.move_speed
	if idle_move_speed_numedit != null:
		idle_move_speed_numedit.value = dmob.idle_move_speed
	if sightRange_numedit != null:
		sightRange_numedit.value = dmob.sight_range
	if senseRange_numedit != null:
		senseRange_numedit.value = dmob.sense_range
	if hearingRange_numedit != null:
		hearingRange_numedit.value = dmob.hearing_range
	if ItemGroupTextEdit != null:
		ItemGroupTextEdit.text = dmob.loot_group

	# Load dash data if available in special_moves
	var dash_data = dmob.special_moves.get("dash", {})
	dash_check_box.set_pressed(not dash_data.is_empty())
	dash_speed_multiplier_spin_box.value = dash_data.get("speed_multiplier", 2)
	dash_duration_spin_box.value = dash_data.get("duration", 0.5)
	dash_cooldown_spin_box.value = dash_data.get("cooldown", 5)
	# Enable or disable dash controls based on checkbox state
	_on_dash_check_box_toggled(dash_check_box.is_pressed())
	
	# Load 'any_of' and 'all_of' attributes into their respective grids
	if dmob.targetattributes.has("any_of"):
		_load_attributes_into_grid(any_of_attributes_grid_container, dmob.targetattributes["any_of"])
	if dmob.targetattributes.has("all_of"):
		_load_attributes_into_grid(all_of_attributes_grid_container, dmob.targetattributes["all_of"])
	
	# Call the new function to populate and refresh the faction_option_button
	refresh_faction_option_button()
	update_attack_type_selection() # Set attack type UI state


# Updates the attack type selection based on the current mob data
func update_attack_type_selection() -> String:
	if attack_type_option_button == null or dmob == null:
		return ""
	
	var selected_attack_type := "Melee"
	if dmob.get("ranged_range") and dmob.ranged_range > 0:
		selected_attack_type = "Ranged"
	
	for i in range(attack_type_option_button.item_count):
		if attack_type_option_button.get_item_text(i) == selected_attack_type:
			attack_type_option_button.select(i)
			_on_attack_type_option_button_item_selected(i)
			return attack_type_option_button.get_item_text(i)
	return ""


# The editor is closed, destroy the instance
# TODO: Check for unsaved changes
func _on_close_button_button_up() -> void:
	queue_free()

# This function takes all data from the form elements and stores them in the DMob instance
# The function will signal to Gamedata that the data has changed and needs to be saved
func _on_save_button_button_up() -> void:
	dmob.spriteid = PathTextLabel.text
	dmob.sprite = mobImageDisplay.texture
	dmob.name = NameTextEdit.text
	dmob.description = DescriptionTextEdit.text
	dmob.health = int(health_numedit.value)
	dmob.move_speed = moveSpeed_numedit.value
	dmob.idle_move_speed = idle_move_speed_numedit.value
	dmob.sight_range = int(sightRange_numedit.value)
	dmob.sense_range = int(senseRange_numedit.value)
	dmob.hearing_range = int(hearingRange_numedit.value)
	dmob.loot_group = ItemGroupTextEdit.text if ItemGroupTextEdit.text else ""

	_save_combat_properties()

	if dash_check_box.button_pressed:
		dmob.special_moves["dash"] = {
			"speed_multiplier": dash_speed_multiplier_spin_box.value,
			"cooldown": dash_cooldown_spin_box.value,
			"duration": dash_duration_spin_box.value
		}
	else:
		dmob.special_moves.erase("dash")

	if faction_option_button != null:
		dmob.faction_id = faction_option_button.get_item_text(faction_option_button.selected)

	dmob.changed(olddata)
	data_changed.emit()
	olddata = DMob.new(dmob.get_data().duplicate(true), null)


# Saves melee and ranged properties based on the selected attack type.
func _save_combat_properties() -> void:
	var selected_attack_type := attack_type_option_button.get_item_text(attack_type_option_button.selected)

	if selected_attack_type == "Melee":
		dmob.melee_range = melee_range_numedit.value
		dmob.melee_cooldown = melee_cooldown_spinbox.value
		dmob.melee_knockback = melee_knockback_spinbox.value

		dmob.ranged_range = -1
		dmob.ranged_cooldown = -1
		dmob.projectile_sprite_id = ""
		dmob.projectile_sprite = null

	elif selected_attack_type == "Ranged":
		dmob.ranged_range = ranged_range_spin_box.value
		dmob.ranged_cooldown = ranged_cooldown_spin_box.value

		dmob.melee_range = -1
		dmob.melee_cooldown = -1
		dmob.melee_knockback = -1
		if projectile_texture_rect.texture:
			var texture_path: String = projectile_texture_rect.texture.resource_path
			if not texture_path == "res://Textures/bullet.png":
				dmob.projectile_sprite_id = projectile_texture_rect.texture.resource_path.get_file()
				dmob.projectile_sprite = projectile_texture_rect.texture


# When the mobImageDisplay is clicked, the user will be prompted to select an image from 
# "res://Mods/Core/mobs/". The texture of the mobImageDisplay will change to the selected image
func _on_mob_image_display_gui_input(event) -> void:
	if event is InputEventMouseButton and event.pressed:
		selected_texture_rect = mobImageDisplay
		mobSelector.show()

# Assign the selected sprite to the appropriate TextureRect
func _on_sprite_selector_sprite_selected_ok(clicked_sprite) -> void:
	if selected_texture_rect:
		var sprite_texture: Texture2D = clicked_sprite.get_texture()
		selected_texture_rect.texture = sprite_texture
		
		# Update PathTextLabel only if the mob sprite was changed
		if selected_texture_rect == mobImageDisplay:
			PathTextLabel.text = sprite_texture.resource_path.get_file()
	else:
		push_warning("No TextureRect was selected before choosing a sprite.")

# This function should return true if the dragged data can be dropped here
# We are expecting a dictionary like this:
#	{
#		"id": selected_item_id,
#		"text": selected_item_text,
#		"mod_id": mod_id,
#		"contentType": contentType
#	}
func _can_drop_data(_newpos, data) -> bool:
	# Check if the data dictionary has the 'id' property
	if not data or not data.has("id"):
		return false
	
	# Fetch itemgroup data by ID from the Gamedata to ensure it exists and is valid
	if not Gamedata.mods.by_id(data["mod_id"]).itemgroups.has_id(data["id"]):
		return false

	# If all checks pass, return true
	return true

# This function handles the data being dropped
func _drop_data(newpos, data) -> void:
	if _can_drop_data(newpos, data):
		_handle_item_drop(data, newpos)

# Called when the user has successfully dropped data onto the ItemGroupTextEdit
# We have to check the dropped_data for the id property
# We are expecting a dictionary like this:
#	{
#		"id": selected_item_id,
#		"text": selected_item_text,
#		"mod_id": mod_id,
#		"contentType": contentType
#	}
func _handle_item_drop(dropped_data, _newpos) -> void:
	# Assuming dropped_data is a Dictionary that includes an 'id'
	if dropped_data and "id" in dropped_data:
		var item_id = dropped_data["id"]
		if not Gamedata.mods.by_id(dropped_data["mod_id"]).itemgroups.has_id(item_id):
			print_debug("No item data found for ID: " + item_id)
			return
		ItemGroupTextEdit.text = item_id
	else:
		print_debug("Dropped data does not contain an 'id' key.")

func _on_item_group_clear_button_button_up():
	ItemGroupTextEdit.clear()


# Toggle the state of dash controls based on dash checkbox status
func _on_dash_check_box_toggled(pressed: bool) -> void:
	dash_speed_multiplier_spin_box.editable = pressed
	dash_duration_spin_box.editable = pressed
	dash_cooldown_spin_box.editable = pressed


# Gets the list of factions from the mod that this entity belongs to
# and fills the faction option button
func refresh_faction_option_button() -> void:
	if faction_option_button == null or dmob == null or dmob.parent == null:
		print_debug("Cannot refresh factions: faction_option_button or dmob is null.")
		return
	
	faction_option_button.clear()  # Clear existing items
	
	var mod_id = dmob.parent.mod_id
	var faction_dict = Gamedata.mods.by_id(mod_id).mobfactions.get_all()
	
	# Populate the OptionButton with faction keys
	for faction_key in faction_dict.keys():
		faction_option_button.add_item(faction_key)
	
	# Select the current faction_id in the OptionButton if it exists
	for i in range(faction_option_button.get_item_count()):
		if faction_option_button.get_item_text(i) == dmob.faction_id:
			faction_option_button.select(i)
			break

# The user selects an attack type option
func _on_attack_type_option_button_item_selected(index: int) -> void:
	var selected_text: String = attack_type_option_button.get_item_text(index)
	if selected_text == "Ranged":
		ranged_h_box_container.visible = true
		melee_h_box_container.visible = false
	elif selected_text == "Melee":
		ranged_h_box_container.visible = false
		melee_h_box_container.visible = true


func _on_projectile_texture_rect_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		selected_texture_rect = projectile_texture_rect
		mobSelector.show()
