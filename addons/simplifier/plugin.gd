tool
class_name SimplifierPlugin
extends EditorPlugin

func find_child_by_class(root: Node, cls_name: String, recursive = false):
	for child in root.get_children():
		if (child as Node).get_class() == cls_name:
			return child
		elif recursive:
			var temp = find_child_by_class(child, cls_name)
			if temp:
				return temp

var scene_tree_dock: Control
var scene_tree_editor: Control
var create_dialog: Control
var filter_hbc: Control
var filter: LineEdit
var selection: EditorSelection
var editor_node: Node
var search_options: Tree
func require_elements():
	if !scene_tree_dock:
		var interface := get_editor_interface()
		var base := interface.get_base_control()
		scene_tree_dock = base.find_node("Scene", true, false)
		scene_tree_editor = find_child_by_class(scene_tree_dock, "SceneTreeEditor")
		create_dialog = find_child_by_class(scene_tree_dock, "CreateDialog")
		
		filter_hbc = find_child_by_class(scene_tree_dock, "HBoxContainer")
		filter = find_child_by_class(filter_hbc, "LineEdit")
		
		selection = interface.get_selection()
		
		#var inspector = base.find_node("Inspector", true, false)
		editor_node = base.get_parent().get_parent()
		
		#print((editor_node as Node).get_method_list())
		var hsc = find_child_by_class(create_dialog, "HSplitContainer")
		var vbc = find_child_by_class(hsc, "VBoxContainer")
		search_options = find_child_by_class(vbc, "Tree", true)

func _init():
	require_elements()
	var checkbox: CheckBox = filter_hbc.get_node_or_null("HideContainers")
	if checkbox:
		plugin_enabled = checkbox.pressed
	
	#var methods := []
	#for method in scene_tree_dock.get_method_list():
	#	methods.append(method.name)
	#print(methods)
	
	#scene_tree_dock.call("set_edited_scene", null)

func mitm(source, target, signal_name, func_name, enable := true):
	if enable:
		source.disconnect(signal_name, target, func_name)
		source.connect(signal_name, self, func_name)
	#	self.connect(signal_name, target, func_name)
	else:
		source.disconnect(signal_name, self, func_name)
		source.connect(signal_name, target, func_name)
		
func _enter_tree():
	#require_elements()

	var checkbox := CheckBox.new()
	checkbox.name = "HideContainers"
	checkbox.pressed = plugin_enabled
	checkbox.connect("toggled", self, "_toggle_plugin")
	filter_hbc.add_child(checkbox)
	
	filter.connect("text_changed", scene_tree_editor, "process_tree")
	
	#create_dialog.connect("create", self, "_node_created")
	scene_tree_editor.set_script(preload("res://addons/simplifier/scene_tree_editor.gd"))

	selection.connect("selection_changed", self, "_selection_changed")
	
	mitm(scene_tree_editor, scene_tree_dock, "nodes_rearranged", "_nodes_dragged")
	mitm(create_dialog, scene_tree_dock, "create", "_create")
	
func _nodes_dragged(p_nodes: Array, p_to: NodePath, p_type: int):
	#require_elements()
	if plugin_enabled:
		p_to = (scene_tree_editor.first_node_path_to_last_node_path as Dictionary).get(p_to, p_to)
	scene_tree_dock._nodes_dragged(p_nodes, p_to, p_type)

var ignore_next_selection_change := false
func _selection_changed():

	if ignore_next_selection_change:
		ignore_next_selection_change = false
		print("selection_changed (ignored)")

	else:
	
		if plugin_enabled:
		
			print("selection_changed")
			
			var selected_nodes := selection.get_selected_nodes()
			for node in selected_nodes:
				var first_node = node
				while first_node && scene_tree_editor.is_skipable_down(first_node):
					first_node = first_node.get_parent()
				while first_node && first_node.get_parent() && scene_tree_editor.is_skipable_up(first_node.get_parent()):
					first_node = first_node.get_parent()
				
				if node != first_node:
					ignore_next_selection_change = true
					selection.remove_node(node)
					selection.add_node(first_node)
					selection.property_list_changed_notify()
					#print(node.name, "->", first_node.name)

			if selected_nodes.size() == 1:
				
				if ignore_next_selection_change:
					selected_nodes = selection.get_selected_nodes()
				
				var front_node = selected_nodes[0]
				while front_node && scene_tree_editor.is_skipable_up(front_node):
					front_node = front_node.get_child(0)
					
				#print(selected_nodes[0].name, ' ', front_node.name)
				#get_editor_interface().inspect_object(front_node, "", false)
				#get_editor_interface().edit_node(front_node)

	scene_tree_editor.process_tree()

var plugin_enabled := true
func _toggle_plugin(pressed: bool):
	#require_elements()
	
	plugin_enabled = !plugin_enabled
	scene_tree_editor.enable(plugin_enabled)

func _exit_tree():
	#require_elements()
	
	filter_hbc.get_node("HideContainers").queue_free()
	filter.disconnect("text_changed", scene_tree_editor, "process_tree")
	
	#create_dialog.disconnect("create", self, "_node_created")
	scene_tree_editor.set_script(null)
	scene_tree_editor.update_tree()
	
	get_editor_interface().get_selection().disconnect("selection_changed", self, "_selection_changed")

	mitm(scene_tree_editor, scene_tree_dock, "nodes_rearranged", "_nodes_dragged", false)
	mitm(create_dialog, scene_tree_dock, "create", "_create", false)

func _create():
	#require_elements()
	if plugin_enabled:
		var selected_class := search_options.get_selected()
#ifdef WRAP_IN_CONTAINER_ON_CREATE
#		var selected_class_text := selected_class.get_text(0)
#		var selected_class_metadata = selected_class.get_metadata(0)
#		selected_class.set_text(0, "MarginContainer")
#		selected_class.set_metadata(0, "")
#endif
		var selected_parent := (scene_tree_editor.tree as Tree).get_selected()
		if !selected_parent:
			selected_parent = scene_tree_editor.tree.get_root()
		#var selected_parent_metadata = selected_parent.get_metadata(0)
		if selected_parent:
			var last_node_path = (scene_tree_editor.first_node_path_to_last_node_path as Dictionary).get(selected_parent.get_metadata(0))
			if last_node_path:
				selected_parent.set_metadata(0, last_node_path)
				scene_tree_editor._selected_changed() # Update SceneTreeEditor::selected
			print(last_node_path)
		
		
		scene_tree_dock._create()

#ifdef WRAP_IN_CONTAINER_ON_CREATE
#		selected_class.set_text(0, selected_class_text)
#		selected_class.set_metadata(0, selected_class_metadata)

		#if last_node_path:
		#	selected_parent.set_metadata(0, selected_parent_metadata)
		#	scene_tree_editor.emit_signal("cell_selected")
		# No need to restore - it's already deleted

#		var outer_container = selection.get_selected_nodes()[0]
#		var node := Control.new()
#		var inner_container := MarginContainer.new()
#
#		outer_container.add_child(node)
#		node.add_child(inner_container)
#
#		var scene_root := get_tree().get_edited_scene_root()
#		outer_container.set_owner(scene_root)
#		node.set_owner(scene_root)
#		inner_container.set_owner(scene_root)
#
#		node.name = "Control"
#		outer_container.name = "Outer" + node.name
#		inner_container.name = "Inner" + node.name
#		inner_container.set_anchors_and_margins_preset(Control.PRESET_WIDE)
#endif
		scene_tree_editor.enable(true)
		
	else:
		scene_tree_dock._create()
