// Undertale framerate mod: runtime.
// Each "// @@ <code entry name>" line starts a new code entry; the build splits this file on them.
//
// How it works, in short: logic still runs 30 times a second ("ticks"). The runner itself runs
// at the chosen frame rate. On frames between ticks, every logic event exits early (a gate the
// build adds to Step/Alarm/Collision/... events), and the engine's own per-step work (animation,
// built-in motion, alarms) is held. Each tick is drawn for real exactly once (on the last frame
// before the next tick). The frames before it are "throwaway" frames: instances and views are
// placed part-way between last tick and this tick, the game's draw code runs as usual, and every
// variable it changes is logged by barriers (inserted by tools/transform.py) and rolled back.

// @@ gml_Object_obj___fl_first_Create_0
__fl_init();

// @@ gml_Object_obj___fl_first_Other_4
__fl_roomstart();

// @@ gml_Object_obj___fl_first_Step_1
__fl_beginstep();

// @@ gml_Object_obj___fl_first_Draw_76
__fl_predraw();

// @@ gml_Object_obj___fl_first_KeyPress_120
// F9 toggles the frame rate overlay
global.__fl_overlay = !global.__fl_overlay;

// @@ gml_Object_obj___fl_first_KeyPress_122
// F11 starts a test battle, only if testbattle=N is set in UndertaleFramerate.ini (testing only)
if (global.__fl_testbattle > 0 && global.__fl_menu == 0 && instance_exists(obj_mainchara) && !instance_exists(obj_battler) && global.interact == 0)
{
    global.battlegroup = global.__fl_testbattle;
    instance_create(0, 0, obj_battler);
}

// @@ gml_Object_obj___fl_last_Draw_75
__fl_endframe();

// @@ gml_Script___fl_init
// One-time setup. Runs in obj___fl_first's Create event, before any game code.
global.__fl_tw = 0;
global.__fl_skip = 0;
global.__fl_real = 1;
global.__fl_alpha = 1;
global.__fl_phase = 0;
global.__fl_commit = 1;      // the next frame runs a tick (set whenever a frame draws for real)
global.__fl_tps = 30;
global.__fl_gen = 0;
global.__fl_vgen = -1;
global.__fl_frame = 0;
global.__fl_maxid = 0;
global.__fl_log = ds_list_create();
global.__fl_newmaps = ds_list_create();
global.__fl_newsurfs = ds_list_create();
global.__fl_newsprites = ds_list_create();
global.__fl_newbufs = ds_list_create();
global.__fl_imgfrz = ds_list_create();
global.__fl_movfrz = ds_list_create();
global.__fl_gs = 0;
global.__fl_valmap = -1;
for (var k = 255; k >= 0; k--)
{
    global.__fl_kpend[k] = 0;
    global.__fl_kwin[k] = 0;
    global.__fl_rpend[k] = 0;
    global.__fl_rwin[k] = 0;
}
// keys whose pressed/released state is carried over to the frames that run game code
var n = 0;
global.__fl_keys[n] = 1;
n += 1;
global.__fl_keys[n] = 8;
n += 1;
global.__fl_keys[n] = 13;
n += 1;
global.__fl_keys[n] = 16;
n += 1;
global.__fl_keys[n] = 17;
n += 1;
global.__fl_keys[n] = 27;
n += 1;
for (var c = 32; c <= 40; c++)
{
    global.__fl_keys[n] = c;
    n += 1;
}
for (var c = 48; c <= 57; c++)
{
    global.__fl_keys[n] = c;
    n += 1;
}
for (var c = 65; c <= 90; c++)
{
    global.__fl_keys[n] = c;
    n += 1;
}
for (var c = 112; c <= 123; c++)
{
    global.__fl_keys[n] = c;
    n += 1;
}
for (var v = 7; v >= 0; v--)
{
    global.__fl_vpx[v] = 0;
    global.__fl_vpy[v] = 0;
    global.__fl_vcx[v] = 0;
    global.__fl_vcy[v] = 0;
}
global.__fl_version = "0.1 EARLY TEST";
global.__fl_font = -1;       // the game's current font and text alignment (the draw_set_font /
global.__fl_halign = fa_left; // draw_set_halign / draw_set_valign calls are wrapped to track them,
global.__fl_valign = fa_top;  // since GameMaker 1.4 can't read them back)
global.__fl_fps = 60;        // frame rate cap chosen in the settings menu
global.__fl_unlimited = 0;   // 1 = no cap (vsync still limits it to the monitor's refresh rate)
global.__fl_overlay = 0;
global.__fl_menu = 0;        // settings menu: 0 closed, 1 open, 2 closing (waits for keys to be released)
global.__fl_validate = 0;    // N > 0: self-check every Nth throwaway frame (testing only)
global.__fl_valnow = 0;
global.__fl_valcount = 0;
global.__fl_trace = -1;      // object whose position/animation is logged every frame (testing only)
global.__fl_trace2 = -1;     // optional second object, and one of its variables, for the trace
global.__fl_tracevar = "";
global.__fl_testbattle = 0;  // F11 starts this battle group (testing only)
global.__fl_interp = 1;
global.__fl_snapdist = 48;
global.__fl_vsync = 0;
global.__fl_altkeys = 1;
// extra keys: action i = up, down, left, right, confirm, cancel, menu
global.__fl_keyname[0] = "UP";
global.__fl_keyname[1] = "DOWN";
global.__fl_keyname[2] = "LEFT";
global.__fl_keyname[3] = "RIGHT";
global.__fl_keyname[4] = "CONFIRM";
global.__fl_keyname[5] = "CANCEL";
global.__fl_keyname[6] = "MENU";
global.__fl_keytarget[0] = vk_up;
global.__fl_keytarget[1] = vk_down;
global.__fl_keytarget[2] = vk_left;
global.__fl_keytarget[3] = vk_right;
global.__fl_keytarget[4] = ord("Z");
global.__fl_keytarget[5] = ord("X");
global.__fl_keytarget[6] = ord("C");
__fl_keys_default();
// frame rate choices shown in the settings menu
var fl = "30,60,75,90,100,120,144,165,170,180,200,240,280,300,360";
var nf = 0;
var p = 1;
while (p <= string_length(fl))
{
    var q = p;
    while (q <= string_length(fl) && string_char_at(fl, q) != ",")
        q += 1;
    global.__fl_fpslist[nf] = real(string_copy(fl, p, q - p));
    nf += 1;
    p = q + 1;
}
global.__fl_mscreen = 0;     // menu screen: 0 main, 1 frame rate list, 2 controls, 3 waiting for a key
global.__fl_mcursor = 0;
global.__fl_mcap = 0;
global.__fl_mmsg = "";
global.__fl_starttime = get_timer();
__fl_readconfig();
__fl_settings_load();
// always apply it: Undertale's own game settings start with vsync on
display_reset(0, global.__fl_vsync);
__fl_apply_keys();
global.__fl_lastt = get_timer();
global.__fl_deadline = global.__fl_lastt;
global.__fl_dtavg = 1 / __fl_target();
global.__fl_stat_t = get_timer();
global.__fl_stat_frames = 0;
global.__fl_stat_ticks = 0;
global.__fl_stat_fps = 0;
global.__fl_stat_tps = 0;
global.__fl_stat_logmax = 0;
global.__fl_stat_tw = 0;
global.__fl_val_lines = 0;
global.__fl_val_bad = 0;
room_speed = __fl_roomspeed();

// @@ gml_Script___fl_readconfig
// Reads UndertaleFramerate.ini (key=value lines) and "-fps N" from the command line.
// Uses file_text, so the game never writes a copy of the file into its save folder.
var fps_s = "";
if (file_exists("UndertaleFramerate.ini"))
{
    var f = file_text_open_read("UndertaleFramerate.ini");
    while (!file_text_eof(f))
    {
        var line = file_text_read_string(f);
        file_text_readln(f);
        var eq = string_pos("=", line);
        var first = string_char_at(line, 1);
        if (eq > 0 && first != ";" && first != "#" && first != "[")
        {
            var key = string_lower(string_replace_all(string_copy(line, 1, eq - 1), " ", ""));
            var val = string_lower(string_replace_all(string_copy(line, eq + 1, string_length(line) - eq), " ", ""));
            var num = 0;
            if (string_length(string_digits(val)) > 0)
                num = real(string_digits(val));
            if (key == "fps")
                fps_s = val;
            else if (key == "overlay")
                global.__fl_overlay = (num != 0);
            else if (key == "validate")
                global.__fl_validate = num;
            else if (key == "trace")
                global.__fl_trace = asset_get_index(string_replace_all(string_copy(line, eq + 1, string_length(line) - eq), " ", ""));
            else if (key == "trace2")
                global.__fl_trace2 = asset_get_index(string_replace_all(string_copy(line, eq + 1, string_length(line) - eq), " ", ""));
            else if (key == "testbattle")
                global.__fl_testbattle = num;
            else if (key == "tracevar")
                global.__fl_tracevar = string_replace_all(string_copy(line, eq + 1, string_length(line) - eq), " ", "");
            else if (key == "interpolate")
                global.__fl_interp = (num != 0);
            else if (key == "vsync")
                global.__fl_vsync = (num != 0);
            else if (key == "altkeys")
                global.__fl_altkeys = (num != 0);
            else if (key == "unlimited")
                global.__fl_unlimited = (num != 0);
        }
    }
    file_text_close(f);
}
for (var i = 1; i < parameter_count(); i++)
{
    if (string_lower(parameter_string(i)) == "-fps")
        fps_s = string_lower(parameter_string(i + 1));
}
if (string_length(string_digits(fps_s)) > 0)
    global.__fl_fps = real(string_digits(fps_s));
if (global.__fl_fps < 30 || global.__fl_fps > 480)
    global.__fl_fps = 60;

// @@ gml_Script___fl_target
// Frame rate the mod aims for: the chosen cap, or as fast as possible when unlimited.
if (global.__fl_unlimited)
    return 1000;
return global.__fl_fps;

// @@ gml_Script___fl_roomspeed
// The runner always runs unlimited: its own limiter sleeps in 15.6 ms steps on Windows (it never
// raises the timer resolution), so a cap like 75 or 144 would come out at 64. __fl_limit holds the cap.
return max(1000, global.__fl_tps);

// @@ gml_Script___fl_limit
// Frame rate cap, at the very end of each frame: wait until this frame's slot is over. It waits by
// checking the clock (GML can't sleep), so a capped frame rate keeps one CPU core busy.
if (global.__fl_unlimited)
    exit;
var period = 1000000 / global.__fl_fps;
var now = get_timer();
global.__fl_deadline += period;
// a slow frame (or a hitch) doesn't earn faster frames afterwards: start counting again from now
if (global.__fl_deadline < now - period)
    global.__fl_deadline = now;
while (get_timer() < global.__fl_deadline)
{
}

// @@ gml_Script___fl_ratio
// Expected logic ticks during one rendered frame, from the measured frame time (at 1 or more,
// every frame is a tick and the game slows down like the original).
return global.__fl_tps * global.__fl_dtavg;

// @@ gml_Script___fl_roomstart
// Room Start runs before the new room's first Begin Step: make this frame a logic tick.
global.__fl_gen += 1;
__fl_img_unfreeze();
__fl_mov_unfreeze();
global.__fl_skip = 0;
global.__fl_phase = 0;
global.__fl_alpha = min(1, __fl_ratio());
global.__fl_real = (global.__fl_alpha >= 0.999);
global.__fl_commit = global.__fl_real;
room_speed = __fl_roomspeed();

// @@ gml_Script___fl_beginstep
__fl_img_unfreeze();
if (global.__fl_skip)
    __fl_mov_freeze();

// @@ gml_Script___fl_img_freeze
// Before a frame without a tick starts, stop the engine advancing image_index
// (it does that at the very start of each frame, before Begin Step).
var L = global.__fl_imgfrz;
ds_list_clear(L);
with (all)
{
    if (image_speed != 0)
    {
        ds_list_add(L, id, image_speed);
        image_speed = 0;
    }
}

// @@ gml_Script___fl_img_unfreeze
var L = global.__fl_imgfrz;
var n = ds_list_size(L);
for (var k = 0; k < n; k += 2)
{
    var inst = ds_list_find_value(L, k);
    if (instance_exists(inst))
    {
        if (inst.image_speed == 0)
            inst.image_speed = ds_list_find_value(L, k + 1);
    }
}
ds_list_clear(L);

// @@ gml_Script___fl_mov_freeze
// Frame without a tick: hold built-in motion and alarms so they keep tick timing.
var L = global.__fl_movfrz;
ds_list_clear(L);
with (all)
{
    if (speed != 0 || gravity != 0 || path_speed != 0)
    {
        ds_list_add(L, id, hspeed, vspeed, gravity, path_speed, direction, speed);
        speed = 0;
        gravity = 0;
        path_speed = 0;
    }
    for (var a = 0; a < 12; a++)
    {
        if (alarm[a] > 0)
            alarm[a] += 1;
    }
}

// @@ gml_Script___fl_mov_unfreeze
var L = global.__fl_movfrz;
var n = ds_list_size(L);
for (var k = 0; k < n; k += 7)
{
    var inst = ds_list_find_value(L, k);
    if (instance_exists(inst))
    {
        with (inst)
        {
            if (speed == 0 && ds_list_find_value(L, k + 6) != 0)
            {
                hspeed = ds_list_find_value(L, k + 1);
                vspeed = ds_list_find_value(L, k + 2);
            }
            if (gravity == 0)
                gravity = ds_list_find_value(L, k + 3);
            if (path_speed == 0)
                path_speed = ds_list_find_value(L, k + 4);
        }
    }
}
ds_list_clear(L);

// @@ gml_Script___fl_predraw
// Pre-Draw of obj___fl_first: the first draw-phase event of every frame (highest depth).
__fl_mov_unfreeze();
if (room_speed != __fl_roomspeed())
    room_speed = __fl_roomspeed();
if (!global.__fl_skip)
    __fl_sample();
if (!global.__fl_real)
    __fl_tw_begin();
if (global.__fl_trace >= 0)
{
    // what this frame will show
    var kind = " T";
    if (global.__fl_skip)
        kind = " -";
    if (global.__fl_real)
        kind += " real ";
    else
        kind += " tw   ";
    global.__fl_trline = string(global.__fl_frame) + kind + string_format(global.__fl_alpha, 1, 3);
    var ti = instance_find(global.__fl_trace, 0);
    if (ti != noone)
        global.__fl_trline += " shown " + string_format(ti.x, 4, 2) + "," + string_format(ti.y, 4, 2);
    global.__fl_trline += " view " + string_format(view_xview[0], 4, 2) + "," + string_format(view_yview[0], 4, 2);
}

// @@ gml_Script___fl_sample
// On a tick: remember where every instance and view was last tick and is now.
var gen = global.__fl_gen;
var mx = 0;
with (all)
{
    if (id > mx)
        mx = id;
    var have = 0;
    if (variable_instance_exists(id, "__fl_cg"))
        have = (__fl_cg == gen);
    if (have)
    {
        __fl_px = __fl_cx;
        __fl_py = __fl_cy;
        __fl_pa = __fl_ca;
        __fl_pal = __fl_cal;
        __fl_psx = __fl_csx;
        __fl_psy = __fl_csy;
    }
    else
    {
        __fl_px = x;
        __fl_py = y;
        __fl_pa = image_angle;
        __fl_pal = image_alpha;
        __fl_psx = image_xscale;
        __fl_psy = image_yscale;
    }
    __fl_cx = x;
    __fl_cy = y;
    __fl_ca = image_angle;
    __fl_cal = image_alpha;
    __fl_csx = image_xscale;
    __fl_csy = image_yscale;
    __fl_cg = gen;
}
global.__fl_maxid = mx;
for (var v = 0; v < 8; v++)
{
    if (global.__fl_vgen == gen)
    {
        global.__fl_vpx[v] = global.__fl_vcx[v];
        global.__fl_vpy[v] = global.__fl_vcy[v];
    }
    else
    {
        global.__fl_vpx[v] = view_xview[v];
        global.__fl_vpy[v] = view_yview[v];
    }
    global.__fl_vcx[v] = view_xview[v];
    global.__fl_vcy[v] = view_yview[v];
}
global.__fl_vgen = gen;

// @@ gml_Script___fl_tw_begin
// Start a throwaway frame. From here until __fl_tw_end, every change the draw code makes is
// logged and later rolled back, and instances/views sit part-way between last tick and this one.
if (global.__fl_skip)
{
    var mx = 0;
    with (all)
    {
        if (id > mx)
            mx = id;
    }
    global.__fl_maxid = mx;
}
ds_list_clear(global.__fl_log);
ds_list_clear(global.__fl_newmaps);
ds_list_clear(global.__fl_newsurfs);
ds_list_clear(global.__fl_newsprites);
ds_list_clear(global.__fl_newbufs);
__fl_gsnap();
global.__fl_valnow = 0;
if (global.__fl_validate > 0)
{
    global.__fl_valcount += 1;
    if (global.__fl_valcount >= global.__fl_validate)
    {
        global.__fl_valcount = 0;
        global.__fl_valnow = 1;
        __fl_val_snap();
    }
}
global.__fl_tw = 1;
global.__fl_stat_tw += 1;
if (global.__fl_interp)
{
    var a = global.__fl_alpha;
    var T = global.__fl_snapdist;
    var gen = global.__fl_gen;
    var L = global.__fl_log;
    with (all)
    {
        if (variable_instance_exists(id, "__fl_cg"))
        {
            if (__fl_cg == gen)
            {
                // position (big jumps are teleports: shown as-is)
                if (x == __fl_cx && y == __fl_cy)
                {
                    var dx = __fl_cx - __fl_px;
                    var dy = __fl_cy - __fl_py;
                    if ((dx != 0 || dy != 0) && abs(dx) <= T && abs(dy) <= T)
                    {
                        ds_list_add(L, 1, id, "x", x, 0, 0, 1, id, "y", y, 0, 0);
                        x = __fl_px + (dx * a);
                        y = __fl_py + (dy * a);
                    }
                }
                // rotation, by the short way round
                if (image_angle == __fl_ca)
                {
                    var da = __fl_ca - __fl_pa;
                    da -= 360 * round(da / 360);
                    if (da != 0 && abs(da) <= 45)
                    {
                        ds_list_add(L, 1, id, "image_angle", image_angle, 0, 0);
                        image_angle = __fl_ca - (da * (1 - a));
                    }
                }
                // fades (but not blinking, which jumps)
                if (image_alpha == __fl_cal)
                {
                    var dl = __fl_cal - __fl_pal;
                    if (dl != 0 && abs(dl) <= 0.25)
                    {
                        ds_list_add(L, 1, id, "image_alpha", image_alpha, 0, 0);
                        image_alpha = __fl_pal + (dl * a);
                    }
                }
                // growing/shrinking (but not flipping)
                if (image_xscale == __fl_csx && image_yscale == __fl_csy)
                {
                    var dsx = __fl_csx - __fl_psx;
                    var dsy = __fl_csy - __fl_psy;
                    if ((dsx != 0 || dsy != 0) && abs(dsx) <= 0.5 && abs(dsy) <= 0.5 && (__fl_psx * __fl_csx) > 0 && (__fl_psy * __fl_csy) > 0)
                    {
                        ds_list_add(L, 1, id, "image_xscale", image_xscale, 0, 0, 1, id, "image_yscale", image_yscale, 0, 0);
                        image_xscale = __fl_psx + (dsx * a);
                        image_yscale = __fl_psy + (dsy * a);
                    }
                }
            }
        }
    }
    if (global.__fl_vgen == gen)
    {
        for (var v = 0; v < 8; v++)
        {
            if (view_xview[v] == global.__fl_vcx[v] && view_yview[v] == global.__fl_vcy[v])
            {
                var vdx = global.__fl_vcx[v] - global.__fl_vpx[v];
                var vdy = global.__fl_vcy[v] - global.__fl_vpy[v];
                if ((vdx != 0 || vdy != 0) && abs(vdx) <= (T * 2) && abs(vdy) <= (T * 2))
                {
                    view_xview[v] = global.__fl_vpx[v] + (vdx * a);
                    view_yview[v] = global.__fl_vpy[v] + (vdy * a);
                }
            }
        }
    }
}

// @@ gml_Script___fl_tw_end
// End a throwaway frame: undo every logged change, remove what it created.
global.__fl_tw = 0;
var n = ds_list_size(global.__fl_log);
if (n > global.__fl_stat_logmax)
    global.__fl_stat_logmax = n;
__fl_rollback();
var mx = global.__fl_maxid;
with (all)
{
    if (id > mx)
    {
        instance_change(obj___fl_sink, false);
        instance_destroy();
    }
}
var L = global.__fl_newmaps;
for (var k = ds_list_size(L) - 1; k >= 0; k--)
{
    if (ds_exists(ds_list_find_value(L, k), ds_type_map))
        ds_map_destroy(ds_list_find_value(L, k));
}
ds_list_clear(L);
L = global.__fl_newsurfs;
for (var k = ds_list_size(L) - 1; k >= 0; k--)
{
    if (surface_exists(ds_list_find_value(L, k)))
        surface_free(ds_list_find_value(L, k));
}
ds_list_clear(L);
L = global.__fl_newsprites;
for (var k = ds_list_size(L) - 1; k >= 0; k--)
{
    if (sprite_exists(ds_list_find_value(L, k)))
        sprite_delete(ds_list_find_value(L, k));
}
ds_list_clear(L);
L = global.__fl_newbufs;
for (var k = ds_list_size(L) - 1; k >= 0; k--)
    buffer_delete(ds_list_find_value(L, k));
ds_list_clear(L);
__fl_grestore();
if (global.__fl_valnow)
    __fl_val_check();

// @@ gml_Script___fl_rollback
// Replay the change log backwards. Records are 6 slots: kind, target, name, old value, i, j.
var L = global.__fl_log;
for (var k = ds_list_size(L) - 6; k >= 0; k -= 6)
{
    var kind = ds_list_find_value(L, k);
    var inst = ds_list_find_value(L, k + 1);
    var nm = ds_list_find_value(L, k + 2);
    var old = ds_list_find_value(L, k + 3);
    var i = ds_list_find_value(L, k + 4);
    var j = ds_list_find_value(L, k + 5);
    switch (kind)
    {
        case 1:
            if (instance_exists(inst))
                variable_instance_set(inst, nm, old);
            break;
        case 2:
            if (instance_exists(inst))
            {
                var a1 = variable_instance_get(inst, nm);
                if (is_array(a1))
                {
                    a1[i] = old;
                    variable_instance_set(inst, nm, a1);
                }
            }
            break;
        case 3:
            if (instance_exists(inst))
            {
                var a2 = variable_instance_get(inst, nm);
                if (is_array(a2))
                {
                    a2[i, j] = old;
                    variable_instance_set(inst, nm, a2);
                }
            }
            break;
        case 4:
            if (instance_exists(inst))
            {
                with (inst)
                    alarm[i] = old;
            }
            break;
        case 5:
            variable_global_set(nm, old);
            break;
        case 6:
            var g1 = variable_global_get(nm);
            if (is_array(g1))
            {
                g1[i] = old;
                variable_global_set(nm, g1);
            }
            break;
        case 7:
            var g2 = variable_global_get(nm);
            if (is_array(g2))
            {
                g2[i, j] = old;
                variable_global_set(nm, g2);
            }
            break;
        case 8:
            if (ds_exists(inst, ds_type_map))
            {
                if (i)
                    ds_map_replace(inst, nm, old);
                else
                    ds_map_delete(inst, nm);
            }
            break;
        case 9:
            // motion: nm = hspeed, old = vspeed, i = direction, j = speed
            if (instance_exists(inst))
            {
                with (inst)
                {
                    if (j == 0)
                    {
                        speed = 0;
                        direction = i;
                    }
                    else
                    {
                        hspeed = nm;
                        vspeed = old;
                    }
                }
            }
            break;
    }
}
ds_list_clear(L);

// @@ gml_Script___fl_bs
// Barrier: self.argument0 is about to be written.
if (variable_instance_exists(id, argument0))
    ds_list_add(global.__fl_log, 1, id, argument0, variable_instance_get(id, argument0), 0, 0);

// @@ gml_Script___fl_ba
// Barrier: self.argument0[argument1] is about to be written.
if (!variable_instance_exists(id, argument0))
    exit;
var a = variable_instance_get(id, argument0);
if (!is_array(a))
{
    ds_list_add(global.__fl_log, 1, id, argument0, a, 0, 0);
    exit;
}
if (argument1 >= 0 && argument1 < array_length_1d(a))
    ds_list_add(global.__fl_log, 2, id, argument0, a[argument1], argument1, 0);

// @@ gml_Script___fl_ba2
// Barrier: self.argument0[argument1, argument2] is about to be written.
if (!variable_instance_exists(id, argument0))
    exit;
var a = variable_instance_get(id, argument0);
if (!is_array(a))
{
    ds_list_add(global.__fl_log, 1, id, argument0, a, 0, 0);
    exit;
}
if (argument1 >= 0 && argument2 >= 0 && argument1 < array_height_2d(a))
{
    if (argument2 < array_length_2d(a, argument1))
        ds_list_add(global.__fl_log, 3, id, argument0, a[argument1, argument2], argument1, argument2);
}

// @@ gml_Script___fl_balarm
// Barrier: self.alarm[argument0] is about to be written.
ds_list_add(global.__fl_log, 4, id, "", alarm[argument0], argument0, 0);

// @@ gml_Script___fl_bmotion
// Barrier: hspeed/vspeed/speed/direction of self are about to change (they are linked).
ds_list_add(global.__fl_log, 9, id, hspeed, vspeed, direction, speed);

// @@ gml_Script___fl_bg
// Barrier: global.argument0 is about to be written.
if (variable_global_exists(argument0))
    ds_list_add(global.__fl_log, 5, 0, argument0, variable_global_get(argument0), 0, 0);

// @@ gml_Script___fl_bga
// Barrier: global.argument0[argument1] is about to be written.
if (!variable_global_exists(argument0))
    exit;
var a = variable_global_get(argument0);
if (!is_array(a))
{
    ds_list_add(global.__fl_log, 5, 0, argument0, a, 0, 0);
    exit;
}
if (argument1 >= 0 && argument1 < array_length_1d(a))
    ds_list_add(global.__fl_log, 6, 0, argument0, a[argument1], argument1, 0);

// @@ gml_Script___fl_bga2
// Barrier: global.argument0[argument1, argument2] is about to be written.
if (!variable_global_exists(argument0))
    exit;
var a = variable_global_get(argument0);
if (!is_array(a))
{
    ds_list_add(global.__fl_log, 5, 0, argument0, a, 0, 0);
    exit;
}
if (argument1 >= 0 && argument2 >= 0 && argument1 < array_height_2d(a))
{
    if (argument2 < array_length_2d(a, argument1))
        ds_list_add(global.__fl_log, 7, 0, argument0, a[argument1, argument2], argument1, argument2);
}

// @@ gml_Script___fl_logmap
// Barrier: key argument1 of ds_map argument0 is about to change (maps made this frame are skipped).
if (ds_list_find_index(global.__fl_newmaps, argument0) >= 0)
    exit;
if (ds_map_exists(argument0, argument1))
    ds_list_add(global.__fl_log, 8, argument0, argument1, ds_map_find_value(argument0, argument1), 1, 0);
else
    ds_list_add(global.__fl_log, 8, argument0, argument1, 0, 0, 0);

// @@ gml_Script___fl_logmotion
// Barrier for builtins that move self (move_towards_point, action_move_to, ...).
ds_list_add(global.__fl_log, 1, id, "x", x, 0, 0, 1, id, "y", y, 0, 0);
ds_list_add(global.__fl_log, 1, id, "gravity", gravity, 0, 0, 1, id, "gravity_direction", gravity_direction, 0, 0);
ds_list_add(global.__fl_log, 1, id, "friction", friction, 0, 0);
ds_list_add(global.__fl_log, 9, id, hspeed, vspeed, direction, speed);

// @@ gml_Script___fl_gsnap
// Snapshot the engine's view/background globals before a throwaway frame.
var k = 0;
for (var v = 0; v < 8; v++)
{
    global.__fl_gs[k] = view_xview[v];
    global.__fl_gs[k + 1] = view_yview[v];
    global.__fl_gs[k + 2] = view_wview[v];
    global.__fl_gs[k + 3] = view_hview[v];
    global.__fl_gs[k + 4] = view_xport[v];
    global.__fl_gs[k + 5] = view_yport[v];
    global.__fl_gs[k + 6] = view_wport[v];
    global.__fl_gs[k + 7] = view_hport[v];
    global.__fl_gs[k + 8] = view_angle[v];
    global.__fl_gs[k + 9] = view_visible[v];
    global.__fl_gs[k + 10] = view_object[v];
    global.__fl_gs[k + 11] = view_hborder[v];
    global.__fl_gs[k + 12] = view_vborder[v];
    global.__fl_gs[k + 13] = view_hspeed[v];
    global.__fl_gs[k + 14] = view_vspeed[v];
    k += 15;
}
for (var b = 0; b < 8; b++)
{
    global.__fl_gs[k] = background_x[b];
    global.__fl_gs[k + 1] = background_y[b];
    global.__fl_gs[k + 2] = background_hspeed[b];
    global.__fl_gs[k + 3] = background_vspeed[b];
    global.__fl_gs[k + 4] = background_alpha[b];
    global.__fl_gs[k + 5] = background_blend[b];
    global.__fl_gs[k + 6] = background_index[b];
    global.__fl_gs[k + 7] = background_visible[b];
    global.__fl_gs[k + 8] = background_foreground[b];
    global.__fl_gs[k + 9] = background_htiled[b];
    global.__fl_gs[k + 10] = background_vtiled[b];
    global.__fl_gs[k + 11] = background_xscale[b];
    global.__fl_gs[k + 12] = background_yscale[b];
    k += 13;
}
global.__fl_gs[k] = background_color;
global.__fl_gs[k + 1] = background_showcolor;
global.__fl_gs[k + 2] = room_caption;
global.__fl_gs[k + 3] = keyboard_string;
global.__fl_gs[k + 4] = keyboard_lastchar;
global.__fl_gs[k + 5] = keyboard_lastkey;

// @@ gml_Script___fl_grestore
var k = 0;
for (var v = 0; v < 8; v++)
{
    view_xview[v] = global.__fl_gs[k];
    view_yview[v] = global.__fl_gs[k + 1];
    view_wview[v] = global.__fl_gs[k + 2];
    view_hview[v] = global.__fl_gs[k + 3];
    view_xport[v] = global.__fl_gs[k + 4];
    view_yport[v] = global.__fl_gs[k + 5];
    view_wport[v] = global.__fl_gs[k + 6];
    view_hport[v] = global.__fl_gs[k + 7];
    view_angle[v] = global.__fl_gs[k + 8];
    view_visible[v] = global.__fl_gs[k + 9];
    view_object[v] = global.__fl_gs[k + 10];
    view_hborder[v] = global.__fl_gs[k + 11];
    view_vborder[v] = global.__fl_gs[k + 12];
    view_hspeed[v] = global.__fl_gs[k + 13];
    view_vspeed[v] = global.__fl_gs[k + 14];
    k += 15;
}
for (var b = 0; b < 8; b++)
{
    background_x[b] = global.__fl_gs[k];
    background_y[b] = global.__fl_gs[k + 1];
    background_hspeed[b] = global.__fl_gs[k + 2];
    background_vspeed[b] = global.__fl_gs[k + 3];
    background_alpha[b] = global.__fl_gs[k + 4];
    background_blend[b] = global.__fl_gs[k + 5];
    background_index[b] = global.__fl_gs[k + 6];
    background_visible[b] = global.__fl_gs[k + 7];
    background_foreground[b] = global.__fl_gs[k + 8];
    background_htiled[b] = global.__fl_gs[k + 9];
    background_vtiled[b] = global.__fl_gs[k + 10];
    background_xscale[b] = global.__fl_gs[k + 11];
    background_yscale[b] = global.__fl_gs[k + 12];
    k += 13;
}
background_color = global.__fl_gs[k];
background_showcolor = global.__fl_gs[k + 1];
if (room_caption != global.__fl_gs[k + 2])
    room_caption = global.__fl_gs[k + 2];
keyboard_string = global.__fl_gs[k + 3];
keyboard_lastchar = global.__fl_gs[k + 4];
keyboard_lastkey = global.__fl_gs[k + 5];

// @@ gml_Script___fl_kcp
// keyboard_check_pressed for game code: on frames without a tick, report what was pressed
// during the current tick's window, so presses that land on draw-only frames are not lost.
if (global.__fl_skip)
    return global.__fl_kwin[argument0];
return keyboard_check_pressed(argument0) || global.__fl_kpend[argument0];

// @@ gml_Script___fl_kcd
// keyboard_check_direct reads the physical key, which the extra-key remap doesn't cover.
if (keyboard_check_direct(argument0))
    return 1;
if (!global.__fl_altkeys)
    return 0;
for (var i = 0; i < 7; i++)
{
    if (global.__fl_keytarget[i] == argument0 && global.__fl_key[i] > 0)
        return keyboard_check_direct(global.__fl_key[i]);
}
return 0;

// @@ gml_Script___fl_keys_default
// Default extra keys: W A S D move, J K L confirm, cancel, menu.
global.__fl_key[0] = ord("W");
global.__fl_key[1] = ord("S");
global.__fl_key[2] = ord("A");
global.__fl_key[3] = ord("D");
global.__fl_key[4] = ord("J");
global.__fl_key[5] = ord("K");
global.__fl_key[6] = ord("L");

// @@ gml_Script___fl_apply_keys
// Each extra key acts as the game key it's bound to (the game itself only knows the originals).
keyboard_unset_map();
if (!global.__fl_altkeys)
    exit;
for (var i = 0; i < 7; i++)
{
    if (global.__fl_key[i] > 0)
        keyboard_set_map(global.__fl_key[i], global.__fl_keytarget[i]);
}

// @@ gml_Script___fl_key_allowed
// Keys the player may bind: not the game's own keys, Esc or the F-keys.
var k = argument0;
if (k == 9 || k == 32)
    return 1;
if (k >= 48 && k <= 57)
    return 1;
if (k >= 65 && k <= 90)
    return (k != ord("Z") && k != ord("X") && k != ord("C"));
if (k >= 96 && k <= 111)
    return 1;
if ((k >= 186 && k <= 192) || (k >= 219 && k <= 222))
    return 1;
return 0;

// @@ gml_Script___fl_key_name
var k = argument0;
if (k <= 0)
    return "---";
if ((k >= 48 && k <= 57) || (k >= 65 && k <= 90))
    return chr(k);
if (k >= 96 && k <= 105)
    return "NUM " + string(k - 96);
switch (k)
{
    case 9:
        return "TAB";
    case 32:
        return "SPACE";
    case 106:
        return "NUM *";
    case 107:
        return "NUM +";
    case 109:
        return "NUM -";
    case 110:
        return "NUM .";
    case 111:
        return "NUM /";
    case 186:
        return ";";
    case 187:
        return "=";
    case 188:
        return ",";
    case 189:
        return "-";
    case 190:
        return ".";
    case 191:
        return "/";
    case 192:
        return "`";
    case 219:
        return "[";
    case 220:
        return "\";
    case 221:
        return "]";
    case 222:
        return "'";
}
return "KEY " + string(k);

// @@ gml_Script___fl_settings_load
// Settings changed in the F1 menu are kept in fl_settings.ini in the game's save folder.
if (!file_exists("fl_settings.ini"))
    exit;
ini_open("fl_settings.ini");
global.__fl_fps = ini_read_real("video", "fps", global.__fl_fps);
global.__fl_unlimited = ini_read_real("video", "unlimited", global.__fl_unlimited);
global.__fl_vsync = ini_read_real("video", "vsync", global.__fl_vsync);
global.__fl_interp = ini_read_real("video", "smooth", global.__fl_interp);
global.__fl_overlay = ini_read_real("video", "showfps", global.__fl_overlay);
global.__fl_altkeys = ini_read_real("keys", "enabled", global.__fl_altkeys);
for (var i = 0; i < 7; i++)
{
    var k = ini_read_real("keys", "key" + string(i), global.__fl_key[i]);
    if (k == 0 || __fl_key_allowed(k))
        global.__fl_key[i] = k;
}
ini_close();
if (global.__fl_fps < 30 || global.__fl_fps > 480)
    global.__fl_fps = 60;

// @@ gml_Script___fl_settings_save
ini_open("fl_settings.ini");
ini_write_real("video", "fps", global.__fl_fps);
ini_write_real("video", "unlimited", global.__fl_unlimited);
ini_write_real("video", "vsync", global.__fl_vsync);
ini_write_real("video", "smooth", global.__fl_interp);
ini_write_real("video", "showfps", global.__fl_overlay);
ini_write_real("keys", "enabled", global.__fl_altkeys);
for (var i = 0; i < 7; i++)
    ini_write_real("keys", "key" + string(i), global.__fl_key[i]);
ini_close();

// @@ gml_Script___fl_rate_changed
// After the frame rate setting changes, restart the frame pacing from the new target.
global.__fl_dtavg = 1 / __fl_target();
global.__fl_lastt = get_timer();
global.__fl_deadline = global.__fl_lastt;
room_speed = __fl_roomspeed();

// @@ gml_Script___fl_kcr
if (global.__fl_skip)
    return global.__fl_rwin[argument0];
return keyboard_check_released(argument0) || global.__fl_rpend[argument0];

// @@ gml_Script___fl_keys_endframe
var K = global.__fl_keys;
var n = array_length_1d(K);
if (!global.__fl_skip)
{
    for (var i = 0; i < n; i++)
    {
        var k = K[i];
        global.__fl_kwin[k] = global.__fl_kpend[k] || keyboard_check_pressed(k);
        global.__fl_kpend[k] = 0;
        global.__fl_rwin[k] = global.__fl_rpend[k] || keyboard_check_released(k);
        global.__fl_rpend[k] = 0;
    }
}
else
{
    for (var i = 0; i < n; i++)
    {
        var k = K[i];
        if (keyboard_check_pressed(k))
            global.__fl_kpend[k] = 1;
        if (keyboard_check_released(k))
            global.__fl_rpend[k] = 1;
    }
}

// @@ gml_Script___fl_endframe
// Draw GUI End of obj___fl_last: the last event of every frame (lowest depth).
if (global.__fl_tw)
    __fl_tw_end();
if (global.__fl_trace >= 0)
    __fl_trace_frame();
__fl_keys_endframe();
__fl_stats();
__fl_menu_input();
__fl_draw_gui();
__fl_decide_next();
__fl_limit();

// @@ gml_Script___fl_decide_next
// Decide what the next frame does: run a logic tick or not, and draw for real or throwaway.
// global.__fl_phase is how far (in ticks) the next frame starts after the latest tick. It
// advances by the real length of each frame, at every frame rate setting: the cap only limits how
// often frames are drawn, so the game keeps real-time speed whatever the cap or the actual rate.
if (global.__fl_menu != 0)
{
    // settings menu open: the game is paused. Every frame redraws the current tick (throwaway,
    // so nothing advances) and the tick schedule is left as it was for when the menu closes.
    global.__fl_lastt = get_timer();
    global.__fl_skip = 1;
    global.__fl_real = 0;
    global.__fl_alpha = 1;
    __fl_img_freeze();
    global.__fl_frame += 1;
    exit;
}
var now = get_timer();
var dt = (now - global.__fl_lastt) / 1000000;
global.__fl_lastt = now;
if (dt < 0)
    dt = 0;
if (dt > 0.1)
    dt = 0.1;
global.__fl_dtavg += (dt - global.__fl_dtavg) * 0.05;
var r = __fl_ratio();
global.__fl_phase += dt * global.__fl_tps;
// Every tick must get exactly one real draw, on the frame right before the next tick. So when a
// frame is chosen to be the real draw, the tick on the frame after it is committed right away
// (global.__fl_commit), even if frame times change in between.
var tick = global.__fl_commit;
global.__fl_skip = !tick;
if (tick)
    global.__fl_phase -= 1;
// Owed time is capped at two ticks: after a hitch the game catches up by ticking every frame
// for a moment; anything longer is dropped (the game just pauses, as the original does).
global.__fl_phase = max(-1, min(global.__fl_phase, 2));
var a = global.__fl_phase + r;
if (r >= 0.999 || a >= 0.999)
{
    global.__fl_alpha = 1;
    global.__fl_real = 1;
    global.__fl_commit = 1;
}
else
{
    global.__fl_alpha = max(0, a);
    global.__fl_real = 0;
    global.__fl_commit = 0;
}
if (global.__fl_skip)
    __fl_img_freeze();
global.__fl_frame += 1;

// @@ gml_Script___fl_stats
global.__fl_stat_frames += 1;
if (!global.__fl_skip)
    global.__fl_stat_ticks += 1;
var now = get_timer();
if ((now - global.__fl_stat_t) >= 1000000)
{
    var secs = (now - global.__fl_stat_t) / 1000000;
    global.__fl_stat_fps = global.__fl_stat_frames / secs;
    global.__fl_stat_tps = global.__fl_stat_ticks / secs;
    if (global.__fl_validate > 0 || global.__fl_trace >= 0)
    {
        __fl_val_write("stats fps=" + string(global.__fl_stat_fps) + " tps=" + string(global.__fl_stat_tps) + " throwaway=" + string(global.__fl_stat_tw) + " logmax=" + string(global.__fl_stat_logmax) + " room=" + room_get_name(room) + " inst=" + string(instance_count));
        global.__fl_stat_logmax = 0;
    }
    global.__fl_stat_frames = 0;
    global.__fl_stat_ticks = 0;
    global.__fl_stat_tw = 0;
    global.__fl_stat_t = now;
}

// @@ gml_Script___fl_draw_gui
// Everything the mod draws on screen: FPS counter, hints and the settings menu. Positions are in
// a 640x480 frame scaled and centred in the GUI layer (so fullscreen works). It uses its own
// font and puts the game's font, alignment, colour and alpha back afterwards.
var gw = display_get_gui_width();
var gh = display_get_gui_height();
var s = min(gw / 640, gh / 480);
global.__fl_gw = gw;
global.__fl_gh = gh;
global.__fl_s = s;
global.__fl_ox = (gw - (640 * s)) / 2;
global.__fl_oy = (gh - (480 * s)) / 2;
var oc = draw_get_color();
var oa = draw_get_alpha();
draw_set_font(fnt_maintext);
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_alpha(1);
if (global.__fl_menu == 1)
{
    __fl_menu_draw();
}
else
{
    if (global.__fl_overlay && global.__fl_stat_fps > 0)
    {
        var t = "unlimited";
        if (!global.__fl_unlimited)
            t = string(global.__fl_fps);
        var o = string(round(global.__fl_stat_fps)) + " fps / " + string(round(global.__fl_stat_tps)) + " ticks (cap " + t + ")";
        if (!global.__fl_interp)
            o += " [smooth off]";
        __fl_mtext(5, 5, o, c_black, 1);
        __fl_mtext(4, 4, o, c_yellow, 1);
    }
    if ((get_timer() - global.__fl_starttime) < 12000000)
    {
        // top left, under the counter: the bottom of the title screens has the copyright line
        var h = "Framerate mod " + global.__fl_version + "  -  press F1 for settings";
        var hy = 4;
        if (global.__fl_overlay)
            hy = 22;
        __fl_mtext(5, hy + 1, h, c_black, 1);
        __fl_mtext(4, hy, h, c_yellow, 1);
    }
    if (instance_exists(obj_settingsmenu))
        __fl_mtext(40, 420, "F1: FRAMERATE MOD", c_yellow, 2);
}
if (global.__fl_font >= 0)
    draw_set_font(global.__fl_font);
draw_set_halign(global.__fl_halign);
draw_set_valign(global.__fl_valign);
draw_set_color(oc);
draw_set_alpha(oa);

// @@ gml_Script___fl_mtext
// Text at (argument0, argument1) in the 640x480 frame: string, colour, scale.
draw_set_color(argument3);
draw_text_transformed(global.__fl_ox + (argument0 * global.__fl_s), global.__fl_oy + (argument1 * global.__fl_s), argument2, argument4 * global.__fl_s, argument4 * global.__fl_s, 0);

// @@ gml_Script___fl_mtext_c
// Like __fl_mtext, centred on x.
var w = string_width(argument2) * argument4;
__fl_mtext(argument0 - (w / 2), argument1, argument2, argument3, argument4);

// @@ gml_Script___fl_onoff
if (argument0)
    return "ON";
return "OFF";

// @@ gml_Script___fl_menu_close
__fl_settings_save();
global.__fl_menu = 2;
global.__fl_mscreen = 0;

// @@ gml_Script___fl_menu_input
// Settings menu (F1). While it is open the game is paused; it closes once all keys are let go,
// so the key that closed it doesn't reach the game.
if (global.__fl_menu == 2)
{
    if (!keyboard_check(vk_anykey))
    {
        global.__fl_menu = 0;
        for (var k = 255; k >= 0; k--)
        {
            global.__fl_kpend[k] = 0;
            global.__fl_kwin[k] = 0;
            global.__fl_rpend[k] = 0;
            global.__fl_rwin[k] = 0;
        }
        global.__fl_lastt = get_timer();
    }
    exit;
}
var f1 = keyboard_check_pressed(vk_f1);
if (global.__fl_menu == 0)
{
    if (f1)
    {
        global.__fl_menu = 1;
        global.__fl_mscreen = 0;
        global.__fl_mcursor = 0;
        global.__fl_mmsg = "";
    }
    exit;
}
if (global.__fl_mscreen == 3)
{
    // waiting for a key to bind. Keys are read directly: with the extra keys mapped, a mapped key
    // reports as its target, and after a map change the runner drops that key's next press.
    if (f1)
    {
        __fl_apply_keys();
        __fl_menu_close();
        exit;
    }
    var hitk = -1;
    for (var k = 8; k <= 222; k++)
    {
        var dn = keyboard_check_direct(k);
        if (dn && !global.__fl_capdown[k] && hitk < 0)
            hitk = k;
        global.__fl_capdown[k] = dn;
    }
    if (hitk >= 0)
    {
        k = hitk;
        var a = global.__fl_mcap;
        if (k == vk_escape)
        {
            global.__fl_mmsg = "";
            global.__fl_mscreen = 2;
        }
        else if (k == vk_backspace)
        {
            global.__fl_key[a] = 0;
            global.__fl_mmsg = "No extra key for " + global.__fl_keyname[a] + ".";
            global.__fl_mscreen = 2;
        }
        else if (!__fl_key_allowed(k))
        {
            global.__fl_mmsg = "That key can't be used. Try another one.";
        }
        else
        {
            var used = -1;
            for (var j = 0; j < 7; j++)
            {
                if (j != a && global.__fl_key[j] == k)
                    used = j;
            }
            if (used >= 0)
            {
                global.__fl_mmsg = __fl_key_name(k) + " is already used for " + global.__fl_keyname[used] + ".";
            }
            else
            {
                global.__fl_key[a] = k;
                global.__fl_mmsg = "";
                global.__fl_mscreen = 2;
            }
        }
        if (global.__fl_mscreen == 2)
        {
            __fl_apply_keys();
            __fl_settings_save();
        }
    }
    exit;
}
var up = keyboard_check_pressed(vk_up);
var down = keyboard_check_pressed(vk_down);
var left = keyboard_check_pressed(vk_left);
var right = keyboard_check_pressed(vk_right);
var ok = keyboard_check_pressed(ord("Z")) || keyboard_check_pressed(vk_enter);
var back = keyboard_check_pressed(ord("X")) || keyboard_check_pressed(vk_shift) || keyboard_check_pressed(vk_escape);
if (f1)
{
    __fl_menu_close();
    exit;
}
var c = global.__fl_mcursor;
var nfps = array_length_1d(global.__fl_fpslist);
if (global.__fl_mscreen == 0)
{
    if (up)
        c = (c + 6) mod 7;
    if (down)
        c = (c + 1) mod 7;
    var change = ok || left || right;
    if (c == 0 && (left || right))
    {
        // step through the frame rate list without opening it
        var idx = 0;
        for (var i = 0; i < nfps; i++)
        {
            if (global.__fl_fpslist[i] <= global.__fl_fps)
                idx = i;
        }
        if (left)
            idx = max(0, idx - 1);
        if (right)
            idx = min(nfps - 1, idx + 1);
        global.__fl_fps = global.__fl_fpslist[idx];
        global.__fl_unlimited = 0;
        __fl_rate_changed();
        __fl_settings_save();
    }
    else if (c == 0 && ok)
    {
        global.__fl_mscreen = 1;
        c = 0;
        for (var i = 0; i < nfps; i++)
        {
            if (global.__fl_fpslist[i] == global.__fl_fps)
                c = i;
        }
    }
    else if (change && c == 1)
    {
        global.__fl_unlimited = !global.__fl_unlimited;
        __fl_rate_changed();
        __fl_settings_save();
    }
    else if (change && c == 2)
    {
        global.__fl_vsync = !global.__fl_vsync;
        display_reset(0, global.__fl_vsync);
        __fl_rate_changed();
        __fl_settings_save();
    }
    else if (change && c == 3)
    {
        global.__fl_interp = !global.__fl_interp;
        __fl_settings_save();
    }
    else if (change && c == 4)
    {
        global.__fl_overlay = !global.__fl_overlay;
        __fl_settings_save();
    }
    else if (ok && c == 5)
    {
        global.__fl_mscreen = 2;
        global.__fl_mmsg = "";
        c = 0;
    }
    else if (ok && c == 6)
    {
        __fl_menu_close();
        exit;
    }
    if (back)
    {
        __fl_menu_close();
        exit;
    }
}
else if (global.__fl_mscreen == 1)
{
    // frame rate list, 4 per row
    if (left)
        c = max(0, c - 1);
    if (right)
        c = min(nfps - 1, c + 1);
    if (up && c >= 4)
        c -= 4;
    if (down && (c + 4) < nfps)
        c += 4;
    if (ok)
    {
        global.__fl_fps = global.__fl_fpslist[c];
        global.__fl_unlimited = 0;
        __fl_rate_changed();
        __fl_settings_save();
        global.__fl_mscreen = 0;
        c = 0;
    }
    else if (back)
    {
        global.__fl_mscreen = 0;
        c = 0;
    }
}
else if (global.__fl_mscreen == 2)
{
    if (up)
        c = (c + 9) mod 10;
    if (down)
        c = (c + 1) mod 10;
    if (ok && c <= 6)
    {
        global.__fl_mcap = c;
        global.__fl_mmsg = "";
        global.__fl_mscreen = 3;
        // keys already held (the Z or Enter that opened this) don't count as the new key
        for (var k = 8; k <= 222; k++)
            global.__fl_capdown[k] = keyboard_check_direct(k);
    }
    else if ((ok || left || right) && c == 7)
    {
        global.__fl_altkeys = !global.__fl_altkeys;
        __fl_apply_keys();
        __fl_settings_save();
    }
    else if (ok && c == 8)
    {
        __fl_keys_default();
        __fl_apply_keys();
        __fl_settings_save();
        global.__fl_mmsg = "Extra keys reset to W A S D and J K L.";
    }
    else if ((ok && c == 9) || back)
    {
        global.__fl_mscreen = 0;
        global.__fl_mmsg = "";
        c = 5;
    }
}
global.__fl_mcursor = c;

// @@ gml_Script___fl_menu_draw
// Undertale-style settings screens: white items, the selected one in yellow.
draw_set_alpha(1);
draw_set_color(c_black);
draw_rectangle(0, 0, global.__fl_gw, global.__fl_gh, false);
draw_set_alpha(1);
var c = global.__fl_mcursor;
var sc = global.__fl_mscreen;
var s = global.__fl_s;
if (sc == 0)
{
    __fl_mtext_c(320, 16, "FRAMERATE MOD", c_white, 4);
    var cap = string(global.__fl_fps) + " FPS";
    if (global.__fl_unlimited)
        cap = "(UNLIMITED)";
    var label, value;
    label[0] = "FRAMERATE";
    value[0] = cap;
    label[1] = "UNLIMITED FPS";
    value[1] = __fl_onoff(global.__fl_unlimited);
    label[2] = "VSYNC";
    value[2] = __fl_onoff(global.__fl_vsync);
    label[3] = "SMOOTH MOTION";
    value[3] = __fl_onoff(global.__fl_interp);
    label[4] = "SHOW FPS";
    value[4] = __fl_onoff(global.__fl_overlay);
    label[5] = "CONTROLS";
    value[5] = "";
    label[6] = "CLOSE";
    value[6] = "";
    for (var i = 0; i < 7; i++)
    {
        var col = c_white;
        if (i == c)
            col = c_yellow;
        __fl_mtext(60, 84 + (i * 32), label[i], col, 2);
        __fl_mtext(400, 84 + (i * 32), value[i], col, 2);
    }
    __fl_mtext(40, 318, "* THIS IS AN EARLY TEST VERSION,", c_yellow, 2);
    __fl_mtext(40, 344, "  NOT THE FINAL RELEASE.", c_yellow, 2);
    __fl_mtext(40, 370, "* EXPECT BUGS AND ISSUES.", c_yellow, 2);
    var d = "";
    switch (c)
    {
        case 0:
            d = "Frames drawn per second. Left/Right to change, Z for the full list.";
            break;
        case 1:
            d = "No frame cap. With VSync on, it runs at your monitor's refresh rate.";
            break;
        case 2:
            d = "Wait for the monitor's refresh. Stops tearing.";
            break;
        case 3:
            d = "Draw movement between game ticks. OFF looks like the original.";
            break;
        case 4:
            d = "Show the frame rate in the top-left corner (F9 also toggles it).";
            break;
        case 5:
            d = "Change the extra keys (W A S D and J K L at first).";
            break;
        case 6:
            d = "Close this menu (F1, X or Esc also close it).";
            break;
    }
    __fl_mtext(40, 410, d, c_ltgray, 1);
    __fl_mtext(40, 438, "Z/ENTER: SELECT   LEFT/RIGHT: CHANGE   X/SHIFT/F1: CLOSE", c_gray, 1);
}
else if (sc == 1)
{
    __fl_mtext_c(320, 16, "FRAMERATE", c_white, 4);
    var n = array_length_1d(global.__fl_fpslist);
    for (var i = 0; i < n; i++)
    {
        var xx = 90 + ((i mod 4) * 135);
        var yy = 96 + ((i div 4) * 44);
        var col = c_white;
        if (i == c)
            col = c_yellow;
        __fl_mtext(xx, yy, string(global.__fl_fpslist[i]) + " FPS", col, 2);
        if (global.__fl_fpslist[i] == global.__fl_fps && !global.__fl_unlimited)
            draw_sprite_ext(spr_heart, 0, global.__fl_ox + ((xx - 26) * s), global.__fl_oy + ((yy + 4) * s), s, s, 0, c_white, 1);
    }
    __fl_mtext(40, 290, "MULTIPLES OF 30 (60, 90, 120...)", c_white, 2);
    __fl_mtext(40, 316, "GIVE THE SMOOTHEST MOTION.", c_white, 2);
    __fl_mtext(40, 352, "Others work too, but in-between frames are less evenly spaced.", c_ltgray, 1);
    if (global.__fl_unlimited)
        __fl_mtext(40, 372, "Unlimited FPS is on. Picking a cap here turns it off.", c_yellow, 1);
    __fl_mtext(40, 438, "ARROWS: MOVE   Z/ENTER: CHOOSE   X/SHIFT: BACK", c_gray, 1);
}
else
{
    __fl_mtext_c(320, 16, "CONTROLS", c_white, 4);
    for (var i = 0; i < 10; i++)
    {
        var col = c_white;
        if (i == c)
            col = c_yellow;
        var lab = "";
        var val = "";
        if (i <= 6)
        {
            lab = global.__fl_keyname[i];
            val = __fl_key_name(global.__fl_key[i]);
            if (!global.__fl_altkeys)
                val = "(" + val + ")";
            if (sc == 3 && global.__fl_mcap == i)
                val = "PRESS A KEY...";
        }
        else if (i == 7)
        {
            lab = "EXTRA KEYS";
            val = __fl_onoff(global.__fl_altkeys);
        }
        else if (i == 8)
        {
            lab = "RESET TO DEFAULTS";
        }
        else
        {
            lab = "BACK";
        }
        __fl_mtext(60, 76 + (i * 30), lab, col, 2);
        __fl_mtext(360, 76 + (i * 30), val, col, 2);
    }
    __fl_mtext(40, 384, "Arrow keys, Z, X, C, Enter, Shift and Ctrl always work too.", c_ltgray, 1);
    if (sc == 3)
        __fl_mtext(40, 402, "Press the new key.  Esc: cancel.  Backspace: no extra key.", c_yellow, 1);
    __fl_mtext(40, 418, global.__fl_mmsg, c_yellow, 1);
    __fl_mtext(40, 438, "Z/ENTER: REBIND   X/SHIFT: BACK", c_gray, 1);
}
__fl_mtext(40, 456, "VERSION " + global.__fl_version, c_dkgray, 1);

// @@ gml_Script___fl_val_write
// Validation log (validate=1 in UndertaleFramerate.ini), written to the game's save folder.
if (global.__fl_val_lines > 20000)
    exit;
global.__fl_val_lines += 1;
var f = file_text_open_append("fl_validate.txt");
file_text_write_string(f, string(global.__fl_frame) + " " + argument0);
file_text_writeln(f);
file_text_close(f);

// @@ gml_Script___fl_trace_frame
// Trace log (trace=<object name> in UndertaleFramerate.ini): one line per frame with what was
// shown and the object's real state afterwards. Written to fl_trace.txt in the save folder.
if (!variable_global_exists("__fl_trbuf"))
{
    global.__fl_trbuf = "";
    global.__fl_trn = 0;
}
if (!variable_global_exists("__fl_trline"))
    exit;
var s = global.__fl_trline;
var ti = instance_find(global.__fl_trace, 0);
if (ti != noone)
{
    s += " | real " + string_format(ti.x, 4, 2) + "," + string_format(ti.y, 4, 2) + " img " + string_format(ti.image_index, 2, 3) + " spr " + string(ti.sprite_index);
    s += " path " + string(ti.path_index) + "@" + string_format(ti.path_position, 1, 4) + " ps " + string(ti.path_speed) + " spd " + string(ti.speed) + " is " + string(ti.image_speed);
}
if (global.__fl_trace2 >= 0)
{
    var t2 = instance_find(global.__fl_trace2, 0);
    if (t2 == noone)
        s += " | obj2 none";
    else if (variable_instance_exists(t2, global.__fl_tracevar))
        s += " | " + global.__fl_tracevar + "=" + string(variable_instance_get(t2, global.__fl_tracevar)) + " a4=" + string(t2.alarm[4]) + " a5=" + string(t2.alarm[5]);
}
s += " writer " + string(instance_number(OBJ_WRITER)) + " interact " + string(global.interact);
global.__fl_trbuf += s + chr(13) + chr(10);
global.__fl_trn += 1;
if (global.__fl_trn >= 30)
{
    var f = file_text_open_append("fl_trace.txt");
    file_text_write_string(f, global.__fl_trbuf);
    file_text_close(f);
    global.__fl_trbuf = "";
    global.__fl_trn = 0;
}

// @@ gml_Script___fl_val_put
// Store value argument2 under key argument1 in map argument0 (arrays element by element).
var M = argument0;
var key = argument1;
var v = argument2;
if (is_array(v))
{
    var h = array_height_2d(v);
    ds_map_add(M, key + "#h", h);
    for (var i = 0; i < h; i++)
    {
        var w = array_length_2d(v, i);
        ds_map_add(M, key + "#w" + string(i), w);
        for (var j = 0; j < w; j++)
            ds_map_add(M, key + "[" + string(i) + "," + string(j) + "]", v[i, j]);
    }
}
else
{
    ds_map_add(M, key, v);
}

// @@ gml_Script___fl_val_collect
// Full state of every instance and global, keyed by name, for the rollback self-check.
var M = ds_map_create();
with (all)
{
    var pre = string(id) + "|";
    ds_map_add(M, pre + "#obj", object_index);
    var names = variable_instance_get_names(id);
    for (var i = 0; i < array_length_1d(names); i++)
    {
        var nm = names[i];
        if (string_copy(nm, 1, 5) != "__fl_")
            __fl_val_put(M, pre + nm, variable_instance_get(id, nm));
    }
    ds_map_add(M, pre + "x", x);
    ds_map_add(M, pre + "y", y);
    ds_map_add(M, pre + "image_index", image_index);
    ds_map_add(M, pre + "image_speed", image_speed);
    ds_map_add(M, pre + "sprite_index", sprite_index);
    ds_map_add(M, pre + "image_alpha", image_alpha);
    ds_map_add(M, pre + "image_blend", image_blend);
    ds_map_add(M, pre + "image_xscale", image_xscale);
    ds_map_add(M, pre + "image_yscale", image_yscale);
    ds_map_add(M, pre + "image_angle", image_angle);
    ds_map_add(M, pre + "visible", visible);
    ds_map_add(M, pre + "depth", depth);
    ds_map_add(M, pre + "hspeed", hspeed);
    ds_map_add(M, pre + "vspeed", vspeed);
    ds_map_add(M, pre + "direction", direction);
    ds_map_add(M, pre + "gravity", gravity);
    ds_map_add(M, pre + "friction", friction);
    ds_map_add(M, pre + "path_speed", path_speed);
    ds_map_add(M, pre + "mask_index", mask_index);
    ds_map_add(M, pre + "persistent", persistent);
    for (var a = 0; a < 12; a++)
        ds_map_add(M, pre + "alarm" + string(a), alarm[a]);
}
var G = __fl_globals_list();
for (var i = 0; i < array_length_1d(G); i++)
{
    if (variable_global_exists(G[i]))
        __fl_val_put(M, "global|" + G[i], variable_global_get(G[i]));
}
return M;

// @@ gml_Script___fl_val_snap
if (global.__fl_valmap >= 0)
    ds_map_destroy(global.__fl_valmap);
global.__fl_valmap = __fl_val_collect();

// @@ gml_Script___fl_val_check
// After a rollback, everything must equal the snapshot taken before the throwaway draw.
var A = global.__fl_valmap;
var B = __fl_val_collect();
var bad = 0;
var key = ds_map_find_first(A);
while (!is_undefined(key))
{
    var va = ds_map_find_value(A, key);
    if (!ds_map_exists(B, key))
    {
        bad += 1;
        if (bad <= 8)
            __fl_val_write("MISSING " + key + " was " + string(va) + " " + __fl_val_objname(key));
    }
    else
    {
        var vb = ds_map_find_value(B, key);
        var same = 0;
        if (is_string(va) == is_string(vb))
        {
            if (is_undefined(va) || is_undefined(vb))
                same = (is_undefined(va) == is_undefined(vb));
            else
                same = (va == vb);
        }
        if (!same)
        {
            if (string_pos("#w", key) > 0 || string_pos("#h", key) > 0)
            {
                // an array grew during the draw; extra elements can't be removed (see below)
                if (global.__fl_val_lines < 2000)
                    __fl_val_write("note: grew " + key + " " + string(va) + " -> " + string(vb) + " " + __fl_val_objname(key));
            }
            else
            {
                bad += 1;
                if (bad <= 8)
                    __fl_val_write("CHANGED " + key + " " + string(va) + " -> " + string(vb) + " " + __fl_val_objname(key));
            }
        }
    }
    key = ds_map_find_next(A, key);
}
// Variables first created during a throwaway draw can't be removed again (GameMaker 1.4 has no
// way to delete a variable). The real draw creates them anyway, so they are only noted once.
key = ds_map_find_first(B);
while (!is_undefined(key))
{
    if (!ds_map_exists(A, key))
    {
        if (string_pos("#obj", key) > 0)
        {
            bad += 1;
            __fl_val_write("LEFTOVER INSTANCE " + key + " " + __fl_val_objname(key));
        }
        else if (global.__fl_val_lines < 2000)
            __fl_val_write("note: created " + key + " " + __fl_val_objname(key));
    }
    key = ds_map_find_next(B, key);
}
if (bad > 0)
{
    global.__fl_val_bad += 1;
    __fl_val_write("frame had " + string(bad) + " mismatches, room " + room_get_name(room));
}
ds_map_destroy(B);
ds_map_destroy(A);
global.__fl_valmap = -1;

// @@ gml_Script___fl_val_objname
// Object name for a validation key "id|var".
var p = string_pos("|", argument0);
if (p <= 1)
    return "";
var idstr = string_copy(argument0, 1, p - 1);
if (idstr == "global")
    return "";
var inst = real(idstr);
if (instance_exists(inst))
    return "(" + object_get_name(inst.object_index) + ")";
return "(gone)";
