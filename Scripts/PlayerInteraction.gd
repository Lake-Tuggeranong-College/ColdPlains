extends Area3D
class_name PlayerInteraction

@export var pickup_range: float = 3.0

var player_id: int
var nearby_items: Array[Item] = []
var inventory: PlayerInventory


func _ready() -> void:
	# Get the parent player node
	var player = get_parent()
	player_id = player.name.to_int()
	# Get or create inventory
	inventory = player.get_node_or_null("PlayerInventory")
	if not inventory:
		print("[WARNING] PlayerInventory not found on player!")
	else:
		print("[PlayerInteraction] PlayerInventory found!")
	# Set up area signals
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	print("[PlayerInteraction] Area signals connected")
	if not is_multiplayer_authority():
		print("[PlayerInteraction] Not multiplayer authority, input disabled")
		return
	print("[PlayerInteraction] Is multiplayer authority - input enabled")


func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if Input.is_action_just_pressed("interact"):
		print("[PlayerInteraction] E key pressed!")
		print("[PlayerInteraction] Nearby items: ", nearby_items.size())
		attempt_pickup()
	if Input.is_action_just_pressed("use_health_pack"):
		var player := get_parent()
		if player.has_method("request_use_health_pack"):
			player.request_use_health_pack()


func attempt_pickup() -> void:
	# Find closest item within range
	var closest_item: Item = null
	var closest_distance: float = pickup_range
	print("[Pickup] Searching for items in range (", pickup_range, "m)")
	for item in nearby_items:
		print("[Pickup] Checking item: ", item.item_name, " - Already picked up: ", item.is_picked_up)
		if not item.is_picked_up:
			var distance = global_position.distance_to(item.global_position)
			print("[Pickup] Distance to ", item.item_name, ": ", distance)
			if distance < closest_distance:
				closest_distance = distance
				closest_item = item


	if closest_item:
		print("[Pickup] Attempting to pick up: ", closest_item.item_name)
		if closest_item.pick_up(player_id):
			# Add item to inventory
			if inventory:
				inventory.add_item(closest_item)
			print("[Pickup] Successfully picked up: ", closest_item.item_name)
		else:
			print("[Pickup] Failed to pick up item (already picked)")
	else:
		print("[Pickup] No items found in range!")


func _on_area_entered(area: Area3D) -> void:
	print("[Area Detection] Area entered: ", area.name)
	# Check if the area belongs to an Item node
	var item = area.get_parent()
	print("[Area Detection] Parent type: ", item.get_class())
	if item is Item:
		if item not in nearby_items:
			nearby_items.append(item)
			print("[Area Detection] Item added to nearby list: ", item.item_name)
	else:
		print("[Area Detection] Parent is not an Item class")


func _on_area_exited(area: Area3D) -> void:
	print("[Area Detection] Area exited: ", area.name)
	# Check if the area belongs to an Item node
	var item = area.get_parent()
	if item is Item:
		nearby_items.erase(item)
		print("[Area Detection] Item removed from nearby list: ", item.item_name)


func get_nearby_items() -> Array[Item]:
	return nearby_items
