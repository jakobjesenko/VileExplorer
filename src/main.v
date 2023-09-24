import ui
import os

struct ItemProprety {
	name string
	is_directory bool
	is_executable bool
mut:
	is_marked bool
	is_selected bool
}

fn (item_proprety ItemProprety) to_string() string {
	mark_status := if item_proprety.is_marked { '☑' } else { '☐' }
	select_status := if item_proprety.is_selected { '→' } else { '  ' }
	
	return mark_status + select_status + item_proprety.name
}

[heap]
struct State {
mut:
	display_directory string
	item_list []ItemProprety
	item_list_string string
	treeview_string string
	selected_item int
	window &ui.Window
}

fn main() {
	mut app := &State{
		display_directory: os.getwd()
		treeview_string: ['v /', '   v home/', '      > jakob/', '      > usr/', '   > etc/', '   > file.txt'].join('\n')
		window: unsafe { nil }
	}
	window := ui.window(
		width: 1000
		height: 600
		title: 'Vile explorer'
		on_click: app.window_click_callback
		children: [
			ui.column(
				heights: [40.0, ui.stretch]
				children: [
					ui.row(
						margin: ui.Margin{10, 10, 10, 10}
						widths: [40.0, ui.stretch, 40]
						spacing: 5
						children: [
							ui.button(
								text: '⬑'
								on_click: app.parent_dir_button_callback
							),
							ui.textbox(
								width: 500
								text: &app.display_directory
								on_enter: app.search_enter_callback
							),
							ui.button(
								text: 'OK'
								on_click: app.search_button_callback
							)
						]
					),
					ui.row(
						margin: ui.Margin{10, 10, 10, 10}
						spacing: 10
						widths: [100.0, ui.stretch]
						children: [
							ui.textbox(
								is_multiline: true
								scrollview: true
								read_only: true
								text: &app.treeview_string
								on_key_down: select_dirtree_item
							),
							ui.textbox(
								id: 'item_list_container'
								is_multiline: true
								scrollview: true
								read_only: true
								text: &app.item_list_string
								on_key_down: select_listed_item
							)
						]
					)
				]
			)
		]
	)
	app.window = window
	app.print_dir_contents(true)
	ui.run(window)
}

fn (mut app State) print_dir_contents(read_fresh bool) {
	item_list := os.ls(app.display_directory) or {return}
	if read_fresh {
		defer {
			app.window.update_layout()
		}
		app.selected_item = 0
		app.item_list = item_list.map(ItemProprety{
			name: it
			is_directory: os.is_dir(os.join_path_single(app.display_directory, it))
		})
	}
	app.item_list_string = app.item_list.map(it.to_string()).join('\n')
}

fn (mut app State) parent_dir_button_callback(sender &ui.Button) {
	new_path := os.dir(app.display_directory)
	app.display_directory = new_path
	app.print_dir_contents(true)
}

fn (mut app State) search_button_callback(sender &ui.Button) {
	app.print_dir_contents(true)
}

fn (mut app State) search_enter_callback(sender &ui.TextBox) {
	app.print_dir_contents(true)
}

fn select_dirtree_item(sender &ui.TextBox, param u32) {
	//println('${param}')
	//println(sender.tv.cursor_x())
	//sender.tv.info()
	//println('>$sender.tv.tlv.cursor_pos_i, $sender.tv.tlv.cursor_pos_j')
}

fn select_listed_item(mut sender &ui.TextBox, e u32) {
	println(e)
	//println('${param}')
	//println(sender.tv.cursor_x())
	//println('$sender.tv.tlv.cursor_pos_i, $sender.tv.tlv.cursor_pos_j')
}

fn (mut app State) window_click_callback(window &ui.Window, e ui.MouseEvent){
	item_list_container := window.get_or_panic[ui.TextBox]('item_list_container')
	if item_list_container.is_focused {

		line_pos := item_list_container.tv.tlv.cursor_pos_j
		char_pos := item_list_container.tv.tlv.cursor_pos_i

		if app.item_list.len == 0 || line_pos >= app.item_list.len {
			app.selected_item = 0
			return
		}
		println(app.item_list[line_pos])
		if char_pos > 0 &&
		app.item_list[line_pos].is_selected &&
		app.item_list[line_pos].is_directory {
			app.display_directory += '/' + app.item_list[line_pos].name
			app.print_dir_contents(true)
			return
		}

		if app.selected_item < app.item_list.len {
			app.item_list[app.selected_item].is_selected = false
		}

		app.selected_item = line_pos
		app.item_list[line_pos].is_selected = true

		if char_pos == 0 {
			app.item_list[line_pos].is_marked = !app.item_list[line_pos].is_marked
		}

		app.print_dir_contents(false)
	}
}