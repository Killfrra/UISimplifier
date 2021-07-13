tool
extends Control

#TODO: deduplicate with plugin.gd
func find_child_by_class(root: Node, cls_name: String):
	for child in root.get_children():
		if (child as Node).get_class() == cls_name:
			return child

var tree: Tree
var texture_to_button_id: Dictionary
func _init():
	tree = find_child_by_class(self, "Tree")
	if !tree.is_connected("nothing_selected", self, "process_tree"):
		tree.connect("nothing_selected", self, "process_tree")
	#get_tree().connect("tree_changed", self, "process_tree")
	process_tree()
	
	texture_to_button_id = {
		get_icon("InstanceOptions", "EditorIcons"): 0,
		get_icon("GuiVisibilityVisible", "EditorIcons"): 1,
		get_icon("Script", "EditorIcons"): 2,
		get_icon("Lock", "EditorIcons"): 3,
		get_icon("Group", "EditorIcons"): 4,
		get_icon("NodeWarning", "EditorIcons"): 5,
		get_icon("SignalsAndGroups", "EditorIcons"): 6,
		get_icon("Groups", "EditorIcons"): 7,
		get_icon("Pin", "EditorIcons"): 8
	}

var enabled := true
func enable(really: bool):
	enabled = really
	self.call("update_tree")
	process_tree(true)

#func update_tree():
#	print("update_tree called")
#	process_tree()

func _test_update_tree():
	#print("_test_update_tree called")
	process_tree()

func _update_tree(_arg = false):
	#print("_update_tree called")
	process_tree()

func process_tree(force = false):
	#print("process_tree called")
	var root = tree.get_root()
	if root && (force || !root.has_meta("processed")):
		if enabled:
			first_node_path_to_last_node_path.clear()
			copy_v3(root)
		root.set_meta("processed", true)

func has_single_child(node: TreeItem):
	return node.get_children() && !node.get_children().get_next()

func is_skipable_up(scene_node: Node):
	return scene_node.get_child_count() == 1 && scene_node.is_class("Container") && scene_node.name.begins_with("Outer")

func is_skipable_down(scene_node: Node):
	return scene_node.is_class("Container") && scene_node.name.begins_with("Inner")

func _is_skipable_up(node: TreeItem):
	var scene_node = get_node(node.get_metadata(0))
	return is_skipable_up(scene_node)

func _is_skipable_down(node: TreeItem):
	var scene_node = get_node(node.get_metadata(0))
	return is_skipable_down(scene_node)

var first_node_path_to_last_node_path := {}
func copy_v3(from: TreeItem, to: TreeItem = null, to_is_newly_created_node := false):
	assert(from != null)
	if to == null:
		to = from

	# determening first, last and center node in chain
	var first_node := from
	var child := from
	while child && _is_skipable_up(child):
		child = child.get_children()
	var front_node = child #TODO: check that front node is not skipable
	if !(front_node.get_children() && front_node.get_children().get_next()):
		while child.get_children() && _is_skipable_down(child.get_children()):
			child = child.get_children()
	var last_node = child

	if first_node != last_node:
		first_node_path_to_last_node_path[first_node.get_metadata(0)] = last_node.get_metadata(0)

	var scene_root := get_tree().get_edited_scene_root()
#	print(
#		scene_root.get_path_to(get_node(first_node.get_metadata(0))), ' ',
#		scene_root.get_path_to(get_node(front_node.get_metadata(0))), ' ',
#		scene_root.get_path_to(get_node(last_node.get_metadata(0)))
#	)

	if first_node.is_selected(0):
		to.select(0)

	if last_node != to:
		
		#copy_attributes(front_node, to)
		copy_attributes(front_node, to, false)
		to.set_metadata(0, first_node.get_metadata(0))
		
		child = last_node.get_children()
		while(child):
			copy_v3(child, tree.create_item(to), true)
			child = child.get_next()
		
		if first_node.get_children():
			first_node.remove_child(first_node.get_children())

	else:
	
		child = last_node.get_children()
		while(child):
			copy_v3(child, child)
			child = child.get_next()

func copy_attributes(from: TreeItem, to: TreeItem, with_meta := true):
	to.set_text(0, from.get_text(0))
	to.set_editable(0, from.is_editable(0))
	to.set_selectable(0, from.is_selectable(0))
	to.set_collapsed(from.is_collapsed())
	to.set_icon(0, from.get_icon(0))
	if with_meta:
		to.set_metadata(0, from.get_metadata(0))

	for i in range(to.get_button_count(0)):
		to.erase_button(0, i)
	for i in range(from.get_button_count(0)):
		var texture = from.get_button(0, i)
		if texture_to_button_id.has(texture):
			to.add_button(0, texture, texture_to_button_id[texture], from.is_button_disabled(0, i), from.get_button_tooltip(0, i))
	
	#to.set_custom_color(0, from.get_custom_color(0))
