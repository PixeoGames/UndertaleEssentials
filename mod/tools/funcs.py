"""Classification of GameMaker builtins called by code that can run during a throwaway draw.

PURE: no lasting side effects (math, queries, drawing, render state), or the callee is game
      code that is itself transformed (event_user, script_execute, event_inherited).
      Instances created during a throwaway draw are found by id afterwards and removed, so
      instance_create & co. are PURE here.
WRAP: renamed to a __fl_<name> wrapper script (see mod/gml/wrappers.gml) that suppresses,
      tracks or logs the effect while a throwaway frame is drawn, and calls the builtin otherwise.
The transform refuses to run if it meets a builtin that is in neither set.
"""

PURE = {
    # math / strings / colours / types
    'sin', 'cos', 'tan', 'abs', 'floor', 'round', 'ceil', 'min', 'max', 'sqrt', 'sqr', 'power', 'exp', 'ln',
    'log2', 'log10', 'sign', 'frac', 'mean', 'median', 'clamp', 'lerp', 'degtorad', 'radtodeg', 'darctan2',
    'arctan2', 'arctan', 'arcsin', 'arccos', 'dsin', 'dcos', 'dtan', 'darcsin', 'darccos', 'darctan',
    'lengthdir_x', 'lengthdir_y', 'point_direction', 'point_distance', 'angle_difference', 'real', 'string',
    'ord', 'chr', 'string_pos', 'string_char_at', 'string_length', 'string_width', 'string_height',
    'string_copy', 'string_lower', 'string_upper', 'string_replace_all', 'string_replace', 'string_repeat',
    'string_delete', 'string_byte_length', 'string_insert', 'string_count', 'string_format', 'string_digits',
    'string_letters', 'string_lettersdigits', 'string_width_ext', 'string_height_ext', 'string_byte_at',
    'make_color_rgb', 'make_color_hsv', 'make_colour_rgb', 'make_colour_hsv', 'merge_color', 'merge_colour',
    'color_get_red', 'color_get_green', 'color_get_blue', 'color_get_hue', 'color_get_saturation',
    'color_get_value', 'is_undefined', 'is_array', 'is_string', 'is_real', 'array_length_1d',
    'array_height_2d', 'array_length_2d', 'random', 'irandom', 'random_range', 'irandom_range', 'choose',
    # drawing and render state
    'draw_sprite', 'draw_sprite_ext', 'draw_sprite_part', 'draw_sprite_part_ext', 'draw_sprite_stretched',
    'draw_sprite_stretched_ext', 'draw_sprite_general', 'draw_sprite_tiled', 'draw_sprite_tiled_ext',
    'draw_sprite_pos', 'draw_self', 'draw_text', 'draw_text_ext', 'draw_text_transformed',
    'draw_text_transformed_color', 'draw_text_color', 'draw_text_colour', 'draw_text_ext_color',
    'draw_text_ext_transformed', 'draw_set_color', 'draw_set_colour', 'draw_set_alpha',
    'draw_set_circle_precision', 'draw_rectangle', 'draw_rectangle_color',
    'draw_rectangle_colour', 'draw_circle', 'draw_circle_color', 'draw_circle_colour', 'draw_line',
    'draw_line_width', 'draw_line_color', 'draw_line_colour', 'draw_line_width_color', 'draw_triangle',
    'draw_triangle_color', 'draw_roundrect', 'draw_roundrect_color', 'draw_ellipse', 'draw_ellipse_color',
    'draw_point', 'draw_point_color', 'draw_background', 'draw_background_ext', 'draw_background_part',
    'draw_background_part_ext', 'draw_background_stretched', 'draw_background_stretched_ext',
    'draw_background_tiled', 'draw_background_tiled_ext', 'draw_surface', 'draw_surface_ext',
    'draw_surface_part', 'draw_surface_part_ext', 'draw_surface_stretched', 'draw_surface_stretched_ext',
    'draw_clear', 'draw_clear_alpha', 'draw_enable_alphablend', 'draw_set_blend_mode',
    'draw_set_blend_mode_ext', 'draw_get_color', 'draw_get_alpha', 'draw_healthbar', 'draw_arrow',
    'draw_primitive_begin', 'draw_primitive_end', 'draw_vertex', 'draw_vertex_color', 'draw_getpixel',
    'texture_set_interpolation', 'surface_set_target', 'surface_reset_target', 'sprite_prefetch',
    'shader_set', 'shader_reset',
    # queries
    'instance_exists', 'instance_number', 'instance_find', 'instance_position', 'instance_nearest',
    'instance_furthest', 'instance_place', 'collision_rectangle', 'collision_line', 'collision_point',
    'collision_circle', 'collision_ellipse', 'distance_to_object', 'distance_to_point', 'place_meeting',
    'place_free', 'place_empty', 'position_meeting', 'position_empty', 'sprite_get_width',
    'sprite_get_height', 'sprite_get_name', 'sprite_get_number', 'sprite_get_xoffset', 'sprite_get_yoffset',
    'sprite_exists', 'background_get_width', 'background_get_height', 'background_exists',
    'surface_get_width', 'surface_get_height', 'surface_exists', 'window_get_width', 'window_get_height',
    'window_get_fullscreen', 'window_get_x', 'window_get_y', 'display_get_width', 'display_get_height',
    'keyboard_check_direct', 'gamepad_button_check', 'gamepad_axis_value',
    'gamepad_get_device_count', 'gamepad_is_connected', 'joystick_buttons', 'joystick_check_button',
    'joystick_has_pov', 'joystick_exists', 'joystick_xpos', 'joystick_ypos', 'joystick_direction',
    'joystick_pov', 'mouse_check_button', 'os_is_paused', 'os_get_language', 'os_get_region',
    'date_current_datetime', 'current_time', 'get_timer', 'room_get_name', 'object_get_name',
    'audio_is_playing', 'audio_sound_get_track_position', 'audio_sound_get_pitch', 'audio_sound_get_gain',
    'file_exists', 'steam_file_exists', 'steam_initialised', 'ini_read_real', 'ini_read_string',
    'ini_section_exists', 'ini_key_exists', 'ds_map_find_value', 'ds_map_exists', 'ds_map_size',
    'ds_list_find_value', 'ds_list_size', 'json_encode', 'buffer_get_size', 'variable_global_exists',
    'variable_instance_exists', 'variable_instance_get', 'variable_global_get', 'file_text_eof',
    'file_text_read_string', 'file_text_readln', 'file_text_read_real', 'file_text_open_read',
    'ini_open', 'ini_open_from_string', 'ini_close', 'object_is_ancestor', 'asset_get_index',
    # creation (new instances are found by id and removed after a throwaway draw)
    'instance_create', 'instance_copy', 'action_create_object',
    # control flow into transformed code
    'event_user', 'script_execute', 'event_inherited', 'action_set_relative',
}

WRAP = {
    # global state changes: suppressed while drawing a throwaway frame
    'room_goto', 'room_goto_next', 'room_goto_previous', 'room_restart', 'game_restart', 'game_end',
    'room_set_persistent', 'keyboard_clear', 'keyboard_key_press', 'keyboard_key_release', 'io_clear',
    'randomize', 'random_set_seed', 'instance_deactivate_all', 'instance_activate_all',
    'instance_activate_object', 'instance_deactivate_object', 'window_set_caption', 'window_set_fullscreen',
    'window_set_size', 'window_center', 'window_set_position', 'steam_file_write_file', 'application_surface_enable', 'application_surface_draw_enable',
    'audio_play_sound', 'audio_stop_all', 'audio_stop_sound', 'audio_sound_gain', 'audio_sound_pitch',
    'audio_pause_all', 'audio_resume_all', 'audio_pause_sound', 'audio_resume_sound',
    'audio_sound_set_track_position', 'audio_channel_num', 'ini_write_real', 'ini_write_string',
    'file_text_open_write', 'file_text_open_append', 'file_text_write_string', 'file_text_write_real',
    'file_text_writeln', 'file_text_close', 'file_delete', 'file_rename', 'steam_file_delete',
    'buffer_save_async', 'buffer_load_async', 'buffer_async_group_begin', 'buffer_async_group_option',
    'buffer_async_group_end', 'buffer_write', 'get_string_async', 'path_start', 'path_end',
    'sprite_replace', 'sprite_collision_mask', 'tile_layer_shift', 'tile_layer_hide', 'tile_layer_show',
    'instance_destroy', 'instance_change',
    # render state the mod's own drawing has to put back (GameMaker 1.4 has no draw_get_font)
    'draw_set_font', 'draw_set_halign', 'draw_set_valign',
    # allocations: tracked and freed after a throwaway draw
    'ds_map_create', 'ds_map_destroy', 'surface_create', 'surface_free', 'sprite_create_from_surface',
    'sprite_delete', 'buffer_create',
    # mutations of existing data: logged and rolled back
    'ds_map_add', 'ds_map_set', 'ds_map_replace', 'ds_map_delete', 'ds_map_set_post',
    'move_towards_point', 'move_snap', 'action_move_to', 'action_move', 'action_set_motion',
    'action_set_gravity', 'action_set_friction', 'action_set_hspeed', 'action_move_point',
    'action_set_alarm',
}

KEY_PRESS_FUNCS = {'keyboard_check_pressed': '__fl_kcp', 'keyboard_check_released': '__fl_kcr',
                   # keys the test hook holds down (testing only)
                   'keyboard_check': '__fl_kc',
                   # reads the physical key, so the WASD remap needs a wrapper too
                   'keyboard_check_direct': '__fl_kcd'}

assert not (PURE & WRAP), PURE & WRAP
