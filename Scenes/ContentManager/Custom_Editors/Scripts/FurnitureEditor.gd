extends Control

#This scene is intended to be used inside the content editor
#It is supposed to edit exactly one piece of furniture
#It expects to save the data to a JSON file that contains all furniture data from a mod
#To load data, provide the name of the furniture data file and an ID

@export var tab_container: TabContainer

@export var furnitureImageDisplay: TextureRect = null
@export var IDTextLabel: Label = null
@export var NameTextEdit: TextEdit = null
@export var DescriptionTextEdit: TextEdit = null
@export var CategoriesList: Control = null
@export var furnitureSelector: Popup = null
@export var imageNameStringLabel: Label = null
@export var moveableCheckboxButton: CheckBox = null # The player can push it if selected
@export var weightLabel: Label = null
@export var weightSpinBox: SpinBox = null # The wight considered when pushing
@export var edgeSnappingOptionButton: OptionButton = null # Apply edge snapping if selected
@export var doorOptionButton: OptionButton = null # Maks the furniture as a door
@export var containerCheckBox: CheckBox = null # Marks the furniture as a container
@export var containerTextEdit: HBoxContainer = null # Might contain the id of a loot group

@export var destroyHboxContainer: HBoxContainer = null # contains destroy controls
@export var canDestroyCheckbox: CheckBox = null # If the furniture can be destroyed or not
@export var destructionTextEdit: HBoxContainer = null # Might contain the id of a loot group
@export var destructionImageDisplay: TextureRect = null # What it looks like when destroyed
@export var destructionSpriteNameLabel: Label = null # The name of the destroyed sprite

@export var disassemblyHboxContainer: HBoxContainer = null # contains destroy controls
@export var canDisassembleCheckbox: CheckBox = null # If the furniture can be disassembled or not
@export var disassemblyTextEdit: HBoxContainer = null # Might contain the id of a loot group
@export var disassemblyImageDisplay: TextureRect = null # What it looks like when disassembled
@export var disassemblySpriteNameLabel: Label = null # The name of the disassembly sprite

# Controls for the shape:
@export var support_shape_option_button: OptionButton
@export var width_scale_label: Label = null
@export var depth_scale_label: Label = null
@export var radius_scale_label: Label = null
@export var width_scale_spin_box: SpinBox
@export var depth_scale_spin_box: SpinBox
@export var radius_scale_spin_box: SpinBox
@export var heigth_spin_box: SpinBox
@export var color_picker: ColorPicker
@export var sprite_texture_rect: TextureRect
@export var transparent_check_box: CheckBox


# For controlling the focus when the tab button is pressed
var control_elements: Array = []
# Tracks which image display control is currently being updated
var current_image_display: String = ""


# This signal will be emitted when the user presses the save button
# This signal should alert Gamedata that the mob data array should be saved to disk
signal data_changed(game_data: Dictionary, new_data: Dictionary, old_data: Dictionary)


var olddata: Dictionary # Remember what the value of the data was before editing
# The data that represents this furniture
# The data is selected from the Gamedata.data.furniture.data array
# based on the ID that the user has selected in the content editor
var contentData: Dictionary = {}:
	set(value):
		contentData = value
		load_furniture_data()
		furnitureSelector.sprites_collection = Gamedata.data.furniture.sprites
		olddata = contentData.duplicate(true)


func _ready():
	# For properly using the tab key to switch elements
	control_elements = [furnitureImageDisplay,NameTextEdit,DescriptionTextEdit]
	data_changed.connect(Gamedata.on_data_changed)
	set_drop_functions()
	
	# Connect the toggle signal to the function
	moveableCheckboxButton.toggled.connect(_on_moveable_checkbox_toggled)


func load_furniture_data():
	if furnitureImageDisplay and contentData.has("sprite"):
		furnitureImageDisplay.texture = Gamedata.data.furniture.sprites[contentData["sprite"]]
		imageNameStringLabel.text = contentData["sprite"]
		update_sprite_texture_rect(furnitureImageDisplay.texture)
	if IDTextLabel:
		IDTextLabel.text = str(contentData["id"])
	if NameTextEdit and contentData.has("name"):
		NameTextEdit.text = contentData["name"]
	if DescriptionTextEdit and contentData.has("description"):
		DescriptionTextEdit.text = contentData["description"]
	if CategoriesList and contentData.has("categories"):
		CategoriesList.clear_list()
		for category in contentData["categories"]:
			CategoriesList.add_item_to_list(category)
	if moveableCheckboxButton and contentData.has("moveable"):
		moveableCheckboxButton.button_pressed = contentData["moveable"]
		_on_moveable_checkbox_toggled(contentData["moveable"])
	if weightSpinBox and contentData.has("weight"):
		weightSpinBox.value = contentData["weight"]
	if edgeSnappingOptionButton and contentData.has("edgesnapping"):
		select_option_by_string(edgeSnappingOptionButton, contentData["edgesnapping"])
	if doorOptionButton:
		update_door_option(contentData.get("Function", {}).get("door", "None"))

	if "destruction" in contentData:
		canDestroyCheckbox.button_pressed = true
		var destruction_data = contentData["destruction"]
		destructionTextEdit.set_text(destruction_data.get("group", ""))
		if destruction_data.has("sprite"):
			destructionImageDisplay.texture = Gamedata.data.furniture.sprites[destruction_data["sprite"]]
			destructionSpriteNameLabel.text = destruction_data["sprite"]
		else:
			destructionImageDisplay.texture = null
			destructionSpriteNameLabel.text = ""
		set_visibility_for_children(destructionTextEdit, true)
	else:
		canDestroyCheckbox.button_pressed = false
		set_visibility_for_children(destructionTextEdit, false)

	if "disassembly" in contentData:
		canDisassembleCheckbox.button_pressed = true
		var disassembly_data = contentData["disassembly"]
		disassemblyTextEdit.set_text(disassembly_data.get("group", ""))
		if disassembly_data.has("sprite"):
			disassemblyImageDisplay.texture = Gamedata.data.furniture.sprites[disassembly_data["sprite"]]
			disassemblySpriteNameLabel.text = disassembly_data["sprite"]
		else:
			disassemblyImageDisplay.texture = null
			disassemblySpriteNameLabel.text = ""
		set_visibility_for_children(disassemblyHboxContainer, true)
	else:
		canDisassembleCheckbox.button_pressed = false
		set_visibility_for_children(disassemblyHboxContainer, false)

	# Load container data if it exists within the 'Function' property
	var function_data = contentData.get("Function", {})
	if "container" in function_data:
		containerCheckBox.button_pressed = true  # Check the container checkbox
		var container_data = function_data["container"]
		if "itemgroup" in container_data:
			containerTextEdit.set_text(container_data["itemgroup"])  # Set text edit with the itemgroup ID
		else:
			containerTextEdit.mytextedit.clear()  # Clear the text edit if no itemgroup is specified
	else:
		containerCheckBox.button_pressed = false  # Uncheck the container checkbox
		containerTextEdit.mytextedit.clear()  # Clear the text edit as no container data is present

	# Call the function to load the support shape data
	load_support_shape_option()



# Function to load support shape data into the form
func load_support_shape_option():
	if contentData.has("support_shape"):
		var shape_data = contentData["support_shape"]
		var shape = shape_data["shape"]

		# Select the appropriate shape in the option button
		for i in range(support_shape_option_button.get_item_count()):
			if support_shape_option_button.get_item_text(i) == shape:
				support_shape_option_button.selected = i
				break


		# Convert the color string to a Color object
		var color_string = shape_data.get("color", "(1, 1, 1, 1)")  # Default to white
		var color_components = color_string.strip_edges().replace("(", "").replace(")", "").split(", ")
		var color = Color(
			color_components[0].to_float(),
			color_components[1].to_float(),
			color_components[2].to_float(),
			color_components[3].to_float()
		)
		color_picker.color = color

		transparent_check_box.button_pressed = shape_data.get("transparent", false)

		if shape == "Box":
			width_scale_spin_box.value = shape_data.get("width_scale", 0.0)
			depth_scale_spin_box.value = shape_data.get("depth_scale", 0.0)
			width_scale_spin_box.visible = true
			depth_scale_spin_box.visible = true
			width_scale_label.visible = true
			depth_scale_label.visible = true
			radius_scale_spin_box.visible = false
			radius_scale_label.visible = false
		elif shape == "Cylinder":
			radius_scale_spin_box.value = shape_data.get("radius_scale", 0.0)
			width_scale_spin_box.visible = false
			depth_scale_spin_box.visible = false
			width_scale_label.visible = false
			depth_scale_label.visible = false
			radius_scale_spin_box.visible = true
			radius_scale_label.visible = true


func update_door_option(door_state):
	var items = doorOptionButton.get_item_count()
	for i in range(items):
		if doorOptionButton.get_item_text(i) == door_state or (door_state not in ["Open", "Closed"] and doorOptionButton.get_item_text(i) == "None"):
			doorOptionButton.selected = i
			return
	print_debug("No matching door state option found: " + door_state)


# This function will select the option in the option_button that matches the given string.
# If no match is found, it does nothing.
func select_option_by_string(option_button: OptionButton, option_string: String) -> void:
	for i in range(option_button.get_item_count()):
		if option_button.get_item_text(i) == option_string:
			option_button.selected = i
			return
	print_debug("No matching option found for the string: " + option_string)


#The editor is closed, destroy the instance
#TODO: Check for unsaved changes
func _on_close_button_button_up():
	queue_free.call_deferred()


# Updates the sprite_texture_rect with the given texture
func update_sprite_texture_rect(texture: Texture):
	if sprite_texture_rect:
		sprite_texture_rect.texture = texture


# This function takes all data from the form elements and stores them in the contentData.
# Since contentData is a reference to an item in Gamedata.data.furniture.data,
# the central array for furnituredata is updated with the changes as well.
# The function will signal to Gamedata that the data has changed and needs to be saved.
func _on_save_button_button_up():
	contentData["sprite"] = imageNameStringLabel.text
	contentData["name"] = NameTextEdit.text
	contentData["description"] = DescriptionTextEdit.text
	contentData["categories"] = CategoriesList.get_items()
	contentData["moveable"] = moveableCheckboxButton.button_pressed
	
	# Save the weight only if moveableCheckboxButton is checked, otherwise erase it.
	if moveableCheckboxButton.button_pressed:
		contentData["weight"] = weightSpinBox.value
	else:
		contentData.erase("weight")

	contentData["edgesnapping"] = edgeSnappingOptionButton.get_item_text(edgeSnappingOptionButton.selected)

	# Handle saving or erasing the support shape data
	handle_support_shape_option()
	handle_door_option()
	handle_container_option()
	handle_destruction_option()
	handle_disassembly_option()

	data_changed.emit(Gamedata.data.furniture, contentData, olddata)
	olddata = contentData.duplicate(true)


# Function to handle saving or erasing the support shape data
func handle_support_shape_option():
	if not moveableCheckboxButton.button_pressed:
		var shape = support_shape_option_button.get_item_text(support_shape_option_button.selected)
		var shape_data = {
			"shape": shape,
			"height": heigth_spin_box.value,
			"color": color_picker.color,
			"transparent": transparent_check_box.button_pressed
		}
		if shape == "Box":
			shape_data["width_scale"] = width_scale_spin_box.value
			shape_data["depth_scale"] = depth_scale_spin_box.value
		elif shape == "Cylinder":
			shape_data["radius_scale"] = radius_scale_spin_box.value

		contentData["support_shape"] = shape_data
	else:
		contentData.erase("support_shape")


# If the door function is set, we save the value to contentData
# Else, if the door state is set to none, we erase the value from contentdata
func handle_door_option():
	var door_state = doorOptionButton.get_item_text(doorOptionButton.selected)
	if door_state == "None" and "Function" in contentData and "door" in contentData["Function"]:
		contentData["Function"].erase("door")
	elif door_state in ["Open", "Closed"]:
		contentData["Function"] = {"door": door_state}


func handle_container_option():
	if containerCheckBox.is_pressed():
		if "Function" not in contentData:
			contentData["Function"] = {}
		if containerTextEdit.get_text() != "":
			contentData["Function"]["container"] = {"itemgroup": containerTextEdit.get_text()}
		else:
			contentData["Function"]["container"] = {}
	elif "Function" in contentData and "container" in contentData["Function"]:
		contentData["Function"].erase("container")
		if contentData["Function"].is_empty():
			contentData.erase("Function")

func handle_destruction_option():
	if canDestroyCheckbox.is_pressed():
		if "destruction" not in contentData:
			contentData["destruction"] = {}
		if destructionTextEdit.get_text() != "":
			contentData["destruction"]["group"] = destructionTextEdit.get_text()
		if destructionSpriteNameLabel.text != "":
			contentData["destruction"]["sprite"] = destructionSpriteNameLabel.text
		else:
			contentData["destruction"].erase("sprite")
	elif "destruction" in contentData:
		contentData.erase("destruction")

func handle_disassembly_option():
	if canDisassembleCheckbox.is_pressed():
		if "disassembly" not in contentData:
			contentData["disassembly"] = {}
		if disassemblyTextEdit.get_text() != "":
			contentData["disassembly"]["group"] = disassemblyTextEdit.get_text()
		if disassemblySpriteNameLabel.text != "":
			contentData["disassembly"]["sprite"] = disassemblySpriteNameLabel.text
		else:
			contentData["disassembly"].erase("sprite")
	elif "disassembly" in contentData:
		contentData.erase("disassembly")

func _input(event):
	if event.is_action_pressed("ui_focus_next"):
		for myControl in control_elements:
			if myControl.has_focus():
				if Input.is_key_pressed(KEY_SHIFT):  # Check if Shift key
					if !myControl.focus_previous.is_empty():
						myControl.get_node(myControl.focus_previous).grab_focus()
				else:
					if !myControl.focus_next.is_empty():
						myControl.get_node(myControl.focus_next).grab_focus()
				break
		get_viewport().set_input_as_handled()


func _on_container_check_box_toggled(toggled_on):
	if not toggled_on:
		containerTextEdit.mytextedit.clear()


# Called when the user has successfully dropped data onto the ItemGroupTextEdit
# We have to check the dropped_data for the id property
func itemgroup_drop(dropped_data: Dictionary, texteditcontrol: HBoxContainer) -> void:
	# Assuming dropped_data is a Dictionary that includes an 'id'
	if dropped_data and "id" in dropped_data:
		var itemgroup_id = dropped_data["id"]
		var itemgroup_data = Gamedata.get_data_by_id(Gamedata.data.itemgroups, itemgroup_id)
		if itemgroup_data.is_empty():
			print_debug("No item data found for ID: " + itemgroup_id)
			return
		texteditcontrol.set_text(itemgroup_id)
		# If it's the container group, we always set the container checkbox to true
		if texteditcontrol == containerTextEdit:
			containerCheckBox.button_pressed = true
		if texteditcontrol == destructionTextEdit:
			canDestroyCheckbox.button_pressed = true
		if texteditcontrol == disassemblyTextEdit:
			canDisassembleCheckbox.button_pressed = true
	else:
		print_debug("Dropped data does not contain an 'id' key.")


func can_itemgroup_drop(dropped_data: Dictionary):
	# Check if the data dictionary has the 'id' property
	if not dropped_data or not dropped_data.has("id"):
		return false
	
	# Fetch itemgroup data by ID from the Gamedata to ensure it exists and is valid
	var itemgroup_data = Gamedata.get_data_by_id(Gamedata.data.itemgroups, dropped_data["id"])
	if itemgroup_data.is_empty():
		return false

	# If all checks pass, return true
	return true


func set_drop_functions():
	containerTextEdit.drop_function = itemgroup_drop.bind(containerTextEdit)
	containerTextEdit.can_drop_function = can_itemgroup_drop
	disassemblyTextEdit.drop_function = itemgroup_drop.bind(disassemblyTextEdit)
	disassemblyTextEdit.can_drop_function = can_itemgroup_drop
	destructionTextEdit.drop_function = itemgroup_drop.bind(destructionTextEdit)
	destructionTextEdit.can_drop_function = can_itemgroup_drop


# When the furnitureImageDisplay is clicked, the user will be prompted to select an image from
# "res://Mods/Core/Furnitures/". The texture of the furnitureImageDisplay will change to the selected image
func _on_furniture_image_display_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		current_image_display = "furniture"
		furnitureSelector.show()

func _on_disassemble_image_display_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		current_image_display = "disassemble"
		furnitureSelector.show()

func _on_destruction_image_display_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		current_image_display = "destruction"
		furnitureSelector.show()

func _on_sprite_selector_sprite_selected_ok(clicked_sprite) -> void:
	var furnitureTexture: Resource = clicked_sprite.get_texture()
	if current_image_display == "furniture":
		furnitureImageDisplay.texture = furnitureTexture
		imageNameStringLabel.text = furnitureTexture.resource_path.get_file()
		update_sprite_texture_rect(furnitureTexture)
	elif current_image_display == "disassemble":
		disassemblyImageDisplay.texture = furnitureTexture
		disassemblySpriteNameLabel.text = furnitureTexture.resource_path.get_file()
	elif current_image_display == "destruction":
		destructionImageDisplay.texture = furnitureTexture
		destructionSpriteNameLabel.text = furnitureTexture.resource_path.get_file()


# Utility function to set the visibility of all children of the given container except the first one
func set_visibility_for_children(container: Control, isvisible: bool):
	for i in range(1, container.get_child_count()):
		container.get_child(i).visible = isvisible

func _on_can_destroy_check_box_toggled(toggled_on):
	if not toggled_on:
		destructionTextEdit.mytextedit.clear()
		destructionSpriteNameLabel.text = ""
		destructionImageDisplay.texture = load("res://Scenes/ContentManager/Mapeditor/Images/emptyTile.png")
	set_visibility_for_children(destructionTextEdit, toggled_on)

func _on_can_disassemble_check_box_toggled(toggled_on):
	if not toggled_on:
		disassemblyTextEdit.mytextedit.clear()
		disassemblySpriteNameLabel.text = ""
		disassemblyImageDisplay.texture = load("res://Scenes/ContentManager/Mapeditor/Images/emptyTile.png")
	set_visibility_for_children(disassemblyHboxContainer, toggled_on)


# Function to handle the toggle state of the checkbox
func _on_moveable_checkbox_toggled(button_pressed):
	weightLabel.visible = button_pressed
	weightSpinBox.visible = button_pressed


# When the user selects a shape from the optionbutton
func _on_support_shape_option_button_item_selected(index):
	if index == 0:  # Box is selected
		width_scale_spin_box.visible = true
		depth_scale_spin_box.visible = true
		width_scale_label.visible = true
		depth_scale_label.visible = true
		radius_scale_label.visible = false
		radius_scale_spin_box.visible = false
	elif index == 1:  # Cylinder is selected
		width_scale_spin_box.visible = false
		depth_scale_spin_box.visible = false
		width_scale_label.visible = false
		depth_scale_label.visible = false
		radius_scale_label.visible = true
		radius_scale_spin_box.visible = true


# When the user toggles the moveable checkbox
# We only show the shape tab if the furniture is not moveable but static
func _on_unmoveable_check_box_toggled(toggled_on):
	# Check if the checkbox is toggled on
	if toggled_on:
		# Hide the second tab in the tab container
		tab_container.set_tab_hidden(1, true)
	else:
		# Show the second tab in the tab container
		tab_container.set_tab_hidden(1, false)
