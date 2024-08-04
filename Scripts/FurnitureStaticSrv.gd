class_name FurnitureStaticSrv
extends RefCounted

# Variables to store furniture data
var furniture_position: Vector3
var furnitureJSON: Dictionary
var dfurniture: DFurniture
var collider: RID
var shape: RID
var mesh_instance: RID  # Variable to store the mesh instance RID
var myworld3d: World3D

# Function to initialize the furniture object
func _init(furniturepos: Vector3, newFurnitureJSON: Dictionary, world3d: World3D):
	furniture_position = furniturepos
	furnitureJSON = newFurnitureJSON
	dfurniture = Gamedata.furnitures.by_id(furnitureJSON.id)
	myworld3d = world3d
	
	if is_new_furniture():
		furniture_position.y += 1.025 # Move the furniture to slightly above the block

	create_box_shape(Vector3(1, 1, 1))  # Example size
	create_visual_instance(Vector3(1, 1, 1))  # Example size

# Function to create a BoxShape3D collider based on the given size
func create_box_shape(size: Vector3):
	shape = PhysicsServer3D.box_shape_create()
	PhysicsServer3D.shape_set_data(shape, Vector3(size.x / 2.0, size.y / 2.0, size.z / 2.0))
	
	collider = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(collider, PhysicsServer3D.BODY_MODE_STATIC)
	# Set space, so it collides in the same space as current scene.
	PhysicsServer3D.body_set_space(collider, myworld3d.space)
	PhysicsServer3D.body_add_shape(collider, shape)
	PhysicsServer3D.body_set_state(collider, PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis(), furniture_position))
	set_collision_layers_and_masks()

# Function to set collision layers and masks
func set_collision_layers_and_masks():
	# Set collision layer to layer 3 (static obstacles layer)
	var collision_layer = 1 << 2  # Layer 3 is 1 << 2

	# Set collision mask to include layers 1, 2, 3, 4, 5, and 6
	var collision_mask = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4) | (1 << 5)
	# Explanation:
	# - 1 << 0: Layer 1 (player layer)
	# - 1 << 1: Layer 2 (enemy layer)
	# - 1 << 2: Layer 3 (movable obstacles layer)
	# - 1 << 3: Layer 4 (static obstacles layer)
	# - 1 << 4: Layer 5 (friendly projectiles layer)
	# - 1 << 5: Layer 6 (enemy projectiles layer)
	
	PhysicsServer3D.body_set_collision_layer(collider, collision_layer)
	PhysicsServer3D.body_set_collision_mask(collider, collision_mask)

# Function to create a visual instance with a mesh to represent the box shape
func create_visual_instance(_size: Vector3):
	var color = Color.html(dfurniture.support_shape.color)
	
	var mymeshdict: Dictionary = {} 
	mymeshdict["primitive"] = RenderingServer.PRIMITIVE_TRIANGLES
	mymeshdict["format"] = 34359742487
	mymeshdict["vertex_data"] = [0, 0, 0, 191, 0, 0, 0, 63, 0, 0, 0, 63, 0, 0, 0, 63, 0, 0, 0, 63, 0, 0, 0, 191, 0, 0, 0, 63, 0, 0, 0, 63, 0, 0, 0, 63, 0, 0, 0, 191, 0, 0, 0, 63, 0, 0, 0, 191, 0, 0, 0, 191, 0, 0, 0, 191, 0, 0, 0, 63, 0, 0, 0, 63, 0, 0, 0, 191, 0, 0, 0, 191, 0, 0, 0, 63, 0, 0, 0, 191, 0, 0, 0, 63, 0, 0, 0, 191, 0, 0, 0, 191, 0, 0, 0, 191, 0, 0, 0, 63, 0, 0, 0, 63, 0, 0, 0, 63, 0, 0, 0, 191, 0, 0, 0, 63, 0, 0, 0, 191, 0, 0, 0, 63, 0, 0, 0, 63, 0, 0, 0, 191, 0, 0, 0, 191, 0, 0, 0, 63, 0, 0, 0, 63, 0, 0, 0, 63, 0, 0, 0, 191, 0, 0, 0, 63, 0, 0, 0, 191, 0, 0, 0, 191, 0, 0, 0, 191, 0, 0, 0, 63, 0, 0, 0, 191, 0, 0, 0, 191, 0, 0, 0, 191, 0, 0, 0, 191, 0, 0, 0, 63, 0, 0, 0, 63, 0, 0, 0, 63, 0, 0, 0, 63, 0, 0, 0, 191, 0, 0, 0, 191, 0, 0, 0, 63, 0, 0, 0, 191, 0, 0, 0, 63, 0, 0, 0, 63, 0, 0, 0, 63, 0, 0, 0, 191, 0, 0, 0, 63, 0, 0, 0, 63, 0, 0, 0, 63, 0, 0, 0, 191, 0, 0, 0, 191, 0, 0, 0, 191, 0, 0, 0, 191, 0, 0, 0, 191, 0, 0, 0, 63, 0, 0, 0, 191, 0, 0, 0, 63, 0, 0, 0, 191, 0, 0, 0, 191, 255, 127, 255, 127, 255, 255, 255, 191, 255, 255, 255, 255, 0, 0, 255, 191, 255, 127, 255, 127, 255, 255, 255, 191, 255, 255, 255, 255, 0, 0, 255, 191, 255, 127, 255, 127, 255, 255, 255, 191, 255, 255, 255, 255, 0, 0, 255, 191, 255, 127, 255, 127, 255, 255, 255, 191, 255, 255, 255, 255, 0, 0, 255, 191, 255, 255, 255, 127, 255, 255, 255, 255, 0, 0, 255, 127, 255, 127, 255, 191, 255, 255, 255, 127, 255, 255, 255, 255, 0, 0, 255, 127, 255, 127, 255, 191, 255, 255, 255, 127, 255, 255, 255, 255, 0, 0, 255, 127, 255, 127, 255, 191, 255, 255, 255, 127, 255, 255, 255, 255, 0, 0, 255, 127, 255, 127, 255, 191, 255, 127, 255, 255, 0, 0, 255, 191, 255, 127, 0, 0, 255, 255, 255, 191, 255, 127, 255, 255, 0, 0, 255, 191, 255, 127, 0, 0, 255, 255, 255, 191, 255, 127, 255, 255, 0, 0, 255, 191, 255, 127, 0, 0, 255, 255, 255, 191, 255, 127, 255, 255, 0, 0, 255, 191, 255, 127, 0, 0, 255, 255, 255, 191]
	
	mymeshdict["attribute_data"] = [0, 0, 0, 0, 0, 0, 0, 0, 171, 170, 42, 63, 0, 0, 0, 0, 171, 170, 170, 62, 0, 0, 0, 0, 0, 0, 128, 63, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 63, 171, 170, 42, 63, 0, 0, 0, 63, 171, 170, 170, 62, 0, 0, 0, 63, 0, 0, 128, 63, 0, 0, 0, 63, 171, 170, 170, 62, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 63, 171, 170, 42, 63, 0, 0, 0, 0, 171, 170, 170, 62, 0, 0, 0, 63, 171, 170, 170, 62, 0, 0, 0, 63, 0, 0, 0, 0, 0, 0, 128, 63, 171, 170, 42, 63, 0, 0, 0, 63, 171, 170, 170, 62, 0, 0, 128, 63, 171, 170, 170, 62, 0, 0, 0, 63, 171, 170, 42, 63, 0, 0, 0, 63, 171, 170, 42, 63, 0, 0, 0, 63, 0, 0, 128, 63, 0, 0, 0, 63, 171, 170, 170, 62, 0, 0, 128, 63, 171, 170, 42, 63, 0, 0, 128, 63, 171, 170, 42, 63, 0, 0, 128, 63, 0, 0, 128, 63, 0, 0, 128, 63]
	mymeshdict["vertex_count"] = 24
	mymeshdict["index_data"] = [0, 0, 2, 0, 4, 0, 2, 0, 6, 0, 4, 0, 1, 0, 3, 0, 5, 0, 3, 0, 7, 0, 5, 0, 8, 0, 10, 0, 12, 0, 10, 0, 14, 0, 12, 0, 9, 0, 11, 0, 13, 0, 11, 0, 15, 0, 13, 0, 16, 0, 18, 0, 20, 0, 18, 0, 22, 0, 20, 0, 17, 0, 19, 0, 21, 0, 19, 0, 23, 0, 21, 0]
	mymeshdict["index_count"] = 36
	
	# Define the position (min corner) and size of the AABB
	mymeshdict["aabb"] = AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1.0, 1.0, 1.0))
	mymeshdict["uv_scale"] =  Vector4(0.0, 0.0, 0.0, 0.0)
	var newmaterial: RID = RenderingServer.material_create()
	
	RenderingServer.material_set_param(newmaterial, "albedo", Color(1, 0, 1, 1));
	RenderingServer.material_set_param(newmaterial, "specular", 0.5);
	RenderingServer.material_set_param(newmaterial, "metallic", 0.0);
	RenderingServer.material_set_param(newmaterial, "roughness", 1.0);
	RenderingServer.material_set_param(newmaterial, "uv1_offset", Vector3(0, 0, 0));
	RenderingServer.material_set_param(newmaterial, "uv1_scale", Vector3(1, 1, 1));
	RenderingServer.material_set_param(newmaterial, "uv2_offset", Vector3(0, 0, 0));
	RenderingServer.material_set_param(newmaterial, "uv2_scale", Vector3(1, 1, 1));
	mymeshdict["material"] =  newmaterial
	
	var newmesh: RID = RenderingServer.mesh_create_from_surfaces([mymeshdict])
	#RenderingServer.mesh_surface_set_material(newmesh, 0, newmaterial)
	# Create the mesh instance using the RenderingServer
	mesh_instance = RenderingServer.instance_create2(newmesh,myworld3d.get_scenario())

	# Set the transform for the mesh instance to match the furniture position
	RenderingServer.instance_set_transform(mesh_instance, Transform3D(Basis(), furniture_position))



# Helper function to determine if the furniture is new
func is_new_furniture() -> bool:
	return not furnitureJSON.has("global_position_x")
