import ui
import os
import json

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

struct Config {
mut:
	marked_files []string
}

[heap]
struct State {
mut:
	display_directory string
	item_list []ItemProprety
	item_list_string string
	treeview_string string
	selected_item int
	viewed_file_array map[string]bool
	config Config
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
		on_quit_request: fn [mut app](_ &ui.Window) { app.store_config('VEconfig.json') }
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
								//on_key_down: select_dirtree_item
							),
							ui.textbox(
								id: 'item_list_container'
								is_multiline: true
								scrollview: true
								read_only: true
								text: &app.item_list_string
								//on_key_down: select_listed_item
							)
						]
					)
				]
			)
		]
	)
	app.load_config('VEconfig.json')
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
			is_marked: app.viewed_file_array[os.join_path_single(app.display_directory, it)] or { false }
		})
	}
	app.item_list_string = app.item_list.map(it.to_string()).join('\n')
}

fn (mut app State) parent_dir_button_callback(sender &ui.Button) {
	app.change_displayed_directory(false)
}

fn (mut app State) search_button_callback(sender &ui.Button) {
	app.print_dir_contents(true)
}

fn (mut app State) search_enter_callback(sender &ui.TextBox) {
	app.print_dir_contents(true)
}

fn (mut app State) window_click_callback(window &ui.Window, e ui.MouseEvent) {
	item_list_container := window.get_or_panic[ui.TextBox]('item_list_container')
	if item_list_container.is_focused {

		line_pos := item_list_container.tv.tlv.cursor_pos_j
		char_pos := item_list_container.tv.tlv.cursor_pos_i

		if app.item_list.len == 0 || line_pos >= app.item_list.len {
			app.selected_item = 0
			return
		}

		// enter selected directory
		if char_pos > 0 &&
		app.item_list[line_pos].is_selected &&
		app.item_list[line_pos].is_directory {
			app.change_displayed_directory(true)
			return
		}

		// reset selection
		if app.selected_item < app.item_list.len {
			app.item_list[app.selected_item].is_selected = false
		}

		app.selected_item = line_pos
		app.item_list[line_pos].is_selected = true

		// toggle mark on the item if ballot is clicked
		if char_pos == 0 {
			app.toggle_file_mark()
		}

		app.print_dir_contents(false)
	}
}

fn (mut app State) change_displayed_directory(move_down bool) {
	if app.item_list.len == 0 {
		app.print_dir_contents(true)
		return
	}
	if move_down {
		app.display_directory = os.join_path_single(app.display_directory,
			app.item_list[app.selected_item].name
		)
	} else {
		app.display_directory = os.dir(app.display_directory)
	}
	app.print_dir_contents(true)
}

fn (mut app State) toggle_file_mark() {
	full_name := os.join_path_single(
		app.display_directory,
		app.item_list[app.selected_item].name
	)
	app.viewed_file_array[full_name] = !app.viewed_file_array[full_name]
	app.item_list[app.selected_item].is_marked = !app.item_list[app.selected_item].is_marked
}

fn (mut app State) load_config(config_file string) {
	data := os.read_file(config_file) or {
		eprintln(err)
		eprintln('If no file was found it will be created upon exiting the program.')
		return
	}
	app.config = json.decode(Config, data) or {
		eprintln(err)
		return
	}
	for file in app.config.marked_files {
		app.viewed_file_array[file] = true
	}
}

fn (mut app State) store_config(config_file string) {
	app.config.marked_files = app.viewed_file_array.keys().filter(app.viewed_file_array[it])
	data := json.encode_pretty(app.config)
	os.write_file(config_file, data) or {
		eprintln(err)
		return
	}
}