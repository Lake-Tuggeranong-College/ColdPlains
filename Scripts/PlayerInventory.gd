extends Node
class_name PlayerInventory

@export var inventory_size: int = 10
@export var health_pack_heal_amount: int = 30

var inventory: Array = []
var player_id: int


func _ready() -> void:
	player_id = get_parent().name.to_int()


func add_item(item: Item) -> bool:
	if inventory.size() >= inventory_size:
		print("Inventory is full!")
		return false
	# Add item data to inventory
	var item_data = {
		"id": item.item_id,
		"name": item.item_name,
		"type": item.item_type
	}
	inventory.append(item_data)
	print("Item added to inventory: ", item.item_name)
	return true


func remove_item(index: int) -> bool:
	if index < 0 or index >= inventory.size():
		return false
	inventory.remove_at(index)
	return true


func get_inventory() -> Array:
	return inventory


func get_inventory_size() -> int:
	return inventory.size()


func clear_inventory() -> void:
	inventory.clear()


func use_health_pack(player: Node) -> bool:
	for i in range(inventory.size()):
		var item_data = inventory[i]
		if item_data.get("id", "") == "health_pack":
			if not player.has_method("heal"):
				return false
			# Attempt to heal before consuming the item.
			if player.heal(health_pack_heal_amount):
				remove_item(i)
				print("Health Pack used! Remaining items: ", inventory.size())
				return true
			print("Cannot use Health Pack: health is full or player is dead.")
			return false
	print("No Health Pack in inventory!")
	return false


func use_health_pack_server(heal_amount: int) -> bool:
	if not multiplayer.is_server():
		return false
	var player := get_parent()
	# Find a Health Pack in the inventory.
	for i in range(inventory.size()):
		if inventory[i].get("id", "") == "health_pack":
			inventory.remove_at(i)
			print("Health Pack consumed on server.")
			return true
	return false
