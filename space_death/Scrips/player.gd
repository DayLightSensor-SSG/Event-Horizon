extends Node3D

# Reference to the camera child node. Can be assigned in the inspector.
@export var camera: Camera3D

# Master list of all valid anchor points (X1, X2, etc.) found in the scene.
var anchors: Array[Node3D] = []
# The anchor the player is currently standing on.
var current_anchor: Node3D
# The index in the available_targets array representing what the camera is looking at.
var observed_anchor_index: int = 0
# A filtered list of anchors we can look at and move to (excludes the current_anchor).
var available_targets: Array[Node3D] = []

func _ready() -> void:
	print("[Logic] Player _ready() started.")
	
	# Fallback: Find the camera automatically if it wasn't set in the inspector.
	if not camera:
		camera = get_node_or_null("Camera3D")
		print("[Logic] Camera reference assigned automatically: ", camera != null)
		
	# Start searching the scene tree from the root node.
	var scene_root = get_tree().current_scene
	var i = 1
	
	print("[Logic] Searching for anchor nodes (X1, X2, X3...)...")
	
	# Incrementally search for nodes named X1, X2, X3, etc.
	# The loop breaks automatically when a number is missing, allowing infinite level expansion.
	while true:
		var anchor_name = "X" + str(i)
		# Search the scene tree recursively, avoiding case sensitivity issues.
		var found_node = scene_root.find_child(anchor_name, true, false)
		
		# If the node exists and is a 3D object, add it to our master list.
		if found_node and found_node is Node3D:
			anchors.append(found_node)
			print("[Logic] Found and registered anchor: ", anchor_name)
			i += 1
		else:
			# No more sequential anchors found, exit the search loop.
			print("[Logic] Search complete. Total anchors found: ", anchors.size())
			break
			
	# Safety check: Prevent errors if no anchors exist in the scene.
	if anchors.is_empty():
		push_error("[Error] No anchors found! Make sure they are named X1, X2, X3, etc. in the scene.")
		return
		
	# Snap the player to the first found anchor to start the game.
	print("[Logic] Initializing starting position at: ", anchors[0].name)
	move_to_anchor(anchors[0])

func _input(event: InputEvent) -> void:
	# Disable input if there aren't enough anchors to move between.
	if anchors.size() < 2: return 
	
	# Only process key presses (ignore releases) and ignore held-down keys (echoes).
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_A:
				print("[Input] 'A' pressed. Cycling observation LEFT.")
				# Move selection index backward by 1.
				cycle_observation(-1)
			KEY_D:
				print("[Input] 'D' pressed. Cycling observation RIGHT.")
				# Move selection index forward by 1.
				cycle_observation(1)
			KEY_W:
				print("[Input] 'W' pressed. Moving to currently observed target.")
				# Teleport to the anchor currently being looked at.
				move_to_anchor(available_targets[observed_anchor_index])
			KEY_S:
				print("[Input] 'S' pressed. (Action currently blank)")
				# Placeholder for future logic (e.g., retreating or interacting).
				pass 

func cycle_observation(direction: int) -> void:
	# Prevent cycling if there is nowhere to look.
	if available_targets.is_empty(): 
		print("[Logic] Cycle blocked: No available targets to look at.")
		return
	
	var old_index = observed_anchor_index
	# Shift the index based on input direction (-1 or 1).
	observed_anchor_index += direction
	
	# Wrap-around logic: 
	# If going below 0, jump to the end of the list.
	# If going past the end, jump back to 0.
	if observed_anchor_index < 0:
		observed_anchor_index = available_targets.size() - 1
	elif observed_anchor_index >= available_targets.size():
		observed_anchor_index = 0
		
	print("[Logic] Observation index changed from ", old_index, " to ", observed_anchor_index)
	# Update the camera rotation to match the new selection.
	look_at_observed()

func look_at_observed() -> void:
	# Get the specific node based on the current selection index.
	var target = available_targets[observed_anchor_index]
	print("[Logic] Camera snapping to look at: ", target.name)
	
	# Snap the camera's orientation directly toward the target's position in the world.
	if camera:
		camera.look_at(target.global_position, Vector3.UP)

func move_to_anchor(target_node: Node3D) -> void:
	# Update internal state to track where the player currently is.
	current_anchor = target_node
	print("[Logic] Moving player to anchor: ", current_anchor.name)
	
	# Snap the entire Player node to the target anchor's exact 3D position.
	global_position = current_anchor.global_position
	
	print("[Logic] Rebuilding available targets list (excluding current position)...")
	# Clear the old observation list to rebuild it based on the new location.
	available_targets.clear()
	
	# Loop through all anchors and add them to the available targets, 
	# skipping the one the player is currently standing on.
	for anchor in anchors:
		if anchor != current_anchor:
			available_targets.append(anchor)
			
	print("[Logic] Available targets count: ", available_targets.size())
			
	# Reset the selection index so the player starts by looking at the first available option.
	observed_anchor_index = 0
	# Immediately rotate the camera to look at this new first option.
	look_at_observed()
