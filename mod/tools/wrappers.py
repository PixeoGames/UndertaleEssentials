# Undertale Essentials. Copyright (C) 2026 Pixeo.
# Free software under the GNU GPL version 3 or later: see LICENSE.
"""Generates the __fl_<builtin> wrapper scripts used by transformed code.

Each wrapper behaves exactly like the builtin, except while a throwaway frame is being
drawn (global.__fl_tw), when the effect is suppressed, tracked for cleanup, or logged.
"""

# name: (argc, mode, extra)
SPEC = {
    # suppressed in throwaway frames (value returned instead)
    'room_goto': (1, 'suppress', '0'), 'room_goto_next': (0, 'suppress', '0'),
    'room_goto_previous': (0, 'suppress', '0'), 'room_restart': (0, 'suppress', '0'),
    'game_restart': (0, 'suppress', '0'), 'game_end': (0, 'suppress', '0'),
    'room_set_persistent': (2, 'suppress', '0'), 'keyboard_clear': (1, 'suppress', '0'),
    'keyboard_key_press': (1, 'suppress', '0'), 'keyboard_key_release': (1, 'suppress', '0'),
    'io_clear': (0, 'suppress', '0'), 'randomize': (0, 'suppress', '0'),
    'random_set_seed': (1, 'suppress', '0'),
    'instance_deactivate_all': (1, 'deactivate', '0'), 'instance_deactivate_object': (1, 'deactivate', '0'),
    'instance_activate_all': (0, 'suppress', '0'), 'instance_activate_object': (1, 'suppress', '0'),
    'window_set_caption': (1, 'suppress', '0'), 'window_set_fullscreen': (1, 'suppress', '0'),
    'window_set_size': (2, 'suppress', '0'), 'window_center': (0, 'suppress', '0'),
    'window_set_position': (2, 'suppress', '0'),
    'application_surface_enable': (1, 'suppress', '0'), 'application_surface_draw_enable': (1, 'suppress', '0'),
    'audio_play_sound': (3, 'suppress', '-1'), 'audio_stop_all': (0, 'suppress', '0'),
    'audio_stop_sound': (1, 'suppress', '0'), 'audio_sound_gain': (3, 'suppress', '0'),
    'audio_sound_pitch': (2, 'suppress', '0'), 'audio_pause_all': (0, 'suppress', '0'),
    'audio_resume_all': (0, 'suppress', '0'), 'audio_pause_sound': (1, 'suppress', '0'),
    'audio_resume_sound': (1, 'suppress', '0'), 'audio_sound_set_track_position': (2, 'suppress', '0'),
    'audio_channel_num': (1, 'suppress', '0'),
    'ini_write_real': (3, 'suppress', '0'), 'ini_write_string': (3, 'suppress', '0'),
    'file_text_open_write': (1, 'suppress', '-1'), 'file_text_open_append': (1, 'suppress', '-1'),
    'file_text_write_string': (2, 'suppress', '0'), 'file_text_write_real': (2, 'suppress', '0'),
    'file_text_writeln': (1, 'suppress', '0'), 'file_delete': (1, 'suppress', '0'),
    'file_rename': (2, 'suppress', '0'), 'steam_file_delete': (1, 'suppress', '0'),
    'steam_file_write_file': (2, 'suppress', '0'),
    'buffer_save_async': (4, 'suppress', '-1'), 'buffer_load_async': (4, 'suppress', '-1'),
    'buffer_async_group_begin': (1, 'suppress', '0'), 'buffer_async_group_option': (2, 'suppress', '0'),
    'buffer_async_group_end': (0, 'suppress', '-1'), 'get_string_async': (2, 'suppress', '-1'),
    'path_start': (4, 'suppress', '0'), 'path_end': (0, 'suppress', '0'),
    'sprite_replace': (7, 'suppress', '0'), 'sprite_collision_mask': (9, 'suppress', '0'),
    'tile_layer_shift': (3, 'suppress', '0'), 'tile_layer_hide': (1, 'suppress', '0'),
    'tile_layer_show': (1, 'suppress', '0'),
    'instance_destroy': (0, 'suppress', '0'), 'instance_change': (2, 'suppress', '0'),
    'file_text_close': (1, 'fileclose', None),
    # allocations made during a throwaway frame are freed afterwards
    'ds_map_create': (0, 'track', '__fl_newmaps'), 'surface_create': (2, 'track', '__fl_newsurfs'),
    'sprite_create_from_surface': (9, 'track', '__fl_newsprites'), 'buffer_create': (3, 'track', '__fl_newbufs'),
    'ds_map_destroy': (1, 'free', '__fl_newmaps'), 'surface_free': (1, 'free', '__fl_newsurfs'),
    'sprite_delete': (1, 'free', '__fl_newsprites'),
    'buffer_write': (3, 'ownedonly', '__fl_newbufs'),
    # remembers the game's current font so the overlay and menu can restore it
    'draw_set_font': (1, 'font', '__fl_font'),
    'draw_set_halign': (1, 'font', '__fl_halign'),
    'draw_set_valign': (1, 'font', '__fl_valign'),
    # mutations of existing data are logged
    'ds_map_add': (3, 'map', None), 'ds_map_set': (3, 'map', None), 'ds_map_replace': (3, 'map', None),
    'ds_map_delete': (2, 'map', None), 'ds_map_set_post': (3, 'map', None),
    'move_towards_point': (3, 'motion', None), 'move_snap': (2, 'motion', None),
    'action_move_to': (2, 'motion', None), 'action_move': (2, 'motion', None),
    'action_set_motion': (2, 'motion', None), 'action_set_gravity': (2, 'motion', None),
    'action_set_friction': (1, 'motion', None), 'action_set_hspeed': (1, 'motion', None),
    'action_move_point': (3, 'motion', None), 'action_set_alarm': (2, 'alarm', None),
}


def gen():
    out = {}
    for name, (argc, mode, extra) in SPEC.items():
        args = ', '.join(f'argument{i}' for i in range(argc))
        call = f'{name}({args})'
        if mode == 'suppress':
            if name == 'instance_destroy':
                body = 'if (global.__fl_tw)\n    return 0;\ninstance_destroy();\nreturn 0;\n'
            else:
                body = f'if (global.__fl_tw)\n    return {extra};\nreturn {call};\n'
        elif mode == 'deactivate':
            body = (f'if (global.__fl_tw)\n    return 0;\n{call};\n'
                    'instance_activate_object(obj___fl_first);\ninstance_activate_object(obj___fl_last);\nreturn 0;\n')
        elif mode == 'fileclose':
            body = f'if (argument0 < 0)\n    return 0;\nreturn {call};\n'
        elif mode == 'track':
            body = f'var r = {call};\nif (global.__fl_tw)\n    ds_list_add(global.{extra}, r);\nreturn r;\n'
        elif mode == 'free':
            body = (f'if (global.__fl_tw)\n{{\n    var p = ds_list_find_index(global.{extra}, argument0);\n'
                    f'    if (p < 0)\n        return 0;\n    ds_list_delete(global.{extra}, p);\n}}\nreturn {call};\n')
        elif mode == 'ownedonly':
            body = (f'if (global.__fl_tw)\n{{\n    if (ds_list_find_index(global.{extra}, argument0) < 0)\n'
                    f'        return 0;\n}}\nreturn {call};\n')
        elif mode == 'map':
            body = f'if (global.__fl_tw)\n    __fl_logmap(argument0, argument1);\nreturn {call};\n'
        elif mode == 'motion':
            body = f'if (global.__fl_tw)\n    __fl_logmotion();\nreturn {call};\n'
        elif mode == 'font':
            body = f'global.{extra} = argument0;\n{call};\nreturn 0;\n'
        elif mode == 'alarm':
            body = f'if (global.__fl_tw)\n    __fl_balarm(argument1);\nreturn {call};\n'
        else:
            raise ValueError(mode)
        out['gml_Script___fl_' + name] = f'// wrapper for {name} (generated by tools/wrappers.py)\n' + body
    return out
