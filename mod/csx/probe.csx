// Undertale Framerate Mod. Copyright (C) 2026 Pixeo.
// Free software under the GNU GPL version 3 or later: see LICENSE.
// Stage-0 probe: logs GameMaker 1.4 runner event ordering to a file in the save dir.
using System.IO;
using System.Linq;
using System.Text;

EnsureDataLoaded();
Data.GeneralInfo.Name = Data.Strings.MakeString("UNDERTALE_FLPROBE");
Data.GeneralInfo.FileName = Data.Strings.MakeString("UNDERTALE_FLPROBE");

var spr = Data.Sprites.First(s => s.Textures.Count >= 4 && s.Width >= 8);
Console.WriteLine("probe sprite " + spr.Name.Content);

UndertaleGameObject MakeObj(string name, bool persistent, int depth)
{
    var o = new UndertaleGameObject { Name = Data.Strings.MakeString(name), Visible = true, Persistent = persistent, Depth = depth, Sprite = spr };
    Data.GameObjects.Add(o);
    return o;
}
var probe = MakeObj("obj_fl_probe", true, 1000);
var probe2 = MakeObj("obj_fl_probe2", false, 0);

var g = new UndertaleModLib.Compiler.CodeImportGroup(Data);
g.QueueReplace("gml_Script_scr_fl_plog", @"
if (!variable_global_exists(""__fl_plog"")) { global.__fl_plog = """"; global.__fl_pframe = 0; }
if (global.__fl_pframe < 400 || (global.__fl_pframe >= 2000 && global.__fl_pframe < 2100))
    global.__fl_plog += string(global.__fl_pframe) + ""|"" + argument0 + chr(13) + chr(10);
");
string L(string ev) => $"scr_fl_plog(\"{ev} id=\" + string(id) + \" d=\" + string(depth) + \" ii=\" + string(image_index) + \" a0=\" + string(alarm[0]) + \" x=\" + string(x) + \" rm=\" + room_get_name(room));";
g.QueueReplace("gml_Object_obj_fl_probe_Create_0", L("Create") + @"
image_speed = 0.25;
hspeed = 1;
alarm[0] = 3;
if (!variable_global_exists(""__fl_probeB""))
{
    global.__fl_probeB = 1;
    var b = instance_create(0, 0, obj_fl_probe);
    b.depth = -1000;
    // semantics tests
    variable_instance_set(id, ""x"", 123);
    scr_fl_plog(""T1 vis_set x -> "" + string(x) + "" get="" + string(variable_instance_get(id, ""x"")));
    scr_fl_plog(""T2 exists x="" + string(variable_instance_exists(id, ""x"")) + "" exists foo="" + string(variable_instance_exists(id, ""foo"")));
    arr1[0] = 1; arr2 = arr1; arr1[0] = 5;
    scr_fl_plog(""T3 owner write: copy sees "" + string(arr2[0]));
    arr3[0] = 1; arr4 = arr3; arr4[0] = 9;
    scr_fl_plog(""T4 nonowner write: original sees "" + string(arr3[0]));
    var l = ds_list_create(); ds_list_add(l, 1, 2, 3, 4, 5, 6);
    scr_fl_plog(""T5 ds_list_add 6 -> size "" + string(ds_list_size(l)));
    var names = variable_instance_get_names(id);
    var s = """"; for (var i = 0; i < array_length_1d(names); i++) s += names[i] + "","";
    scr_fl_plog(""T6 names: "" + s);
    arr5[0] = 1; var cp = variable_instance_get(id, ""arr5""); cp[0] = 7;
    scr_fl_plog(""T7 vig copy write: inst sees "" + string(arr5[0]));
    variable_instance_set(id, ""image_speed"", 0.5);
    scr_fl_plog(""T8 vis_set image_speed -> "" + string(image_speed));
    variable_instance_set(id, ""alarm"", 7);
    scr_fl_plog(""T9 vis_set alarm -> "" + string(alarm[0]));
    scr_fl_plog(""T10 room_speed="" + string(room_speed));
    image_speed = 0.25;
    x = 0;
}
");
foreach (var (ev, nm) in new[] { ("Step_1", "BeginStep"), ("Step_0", "Step"), ("Step_2", "EndStep"), ("Draw_76", "PreDraw"), ("Draw_72", "DrawBegin"),
                                 ("Draw_0", "Draw"), ("Draw_73", "DrawEnd"), ("Draw_77", "PostDraw"), ("Draw_74", "GUIBegin"), ("Draw_64", "GUI"),
                                 ("Draw_75", "GUIEnd"), ("Other_4", "RoomStart"), ("Other_7", "AnimEnd"), ("Alarm_0", "Alarm0"), ("Other_5", "RoomEnd") })
{
    string extra = "";
    if (ev == "Alarm_0") extra = "alarm[0] = 3;";
    if (ev == "Draw_75") extra = "if (depth == 1000) { global.__fl_pframe += 1; if (global.__fl_pframe mod 30 == 0) { var f = file_text_open_append(\"fl_probe.txt\"); file_text_write_string(f, global.__fl_plog); file_text_close(f); global.__fl_plog = \"\"; } }";
    if (ev == "Other_4") extra = "if (depth == 1000) instance_create(0, 0, obj_fl_probe2);";
    g.QueueReplace("gml_Object_obj_fl_probe_" + ev, L(nm) + extra);
}
foreach (var (ev, nm) in new[] { ("Create_0", "P2Create"), ("Step_1", "P2BeginStep"), ("Step_0", "P2Step"), ("Draw_0", "P2Draw"), ("Other_4", "P2RoomStart") })
    g.QueueReplace("gml_Object_obj_fl_probe2_" + ev, L(nm));
g.QueuePrepend("gml_Object_obj_time_Step_1", "scr_fl_plog(\"time BeginStep id=\" + string(id));");
g.QueuePrepend("gml_Object_obj_time_Create_0", "scr_fl_plog(\"time Create id=\" + string(id));");
g.QueuePrepend("gml_Object_obj_time_Other_4", "scr_fl_plog(\"time RoomStart id=\" + string(id));");
var res = g.Import();
Console.WriteLine("compile ok: " + res.Successful);
if (!res.Successful) Console.WriteLine(res.PrintAllErrors(false));

// first room: probe instance first
var room0 = Data.GeneralInfo.RoomOrder.First().Resource;
room0.GameObjects.Insert(0, new UndertaleRoom.GameObject { InstanceID = Data.GeneralInfo.LastObj++, ObjectDefinition = probe, X = 10, Y = 10, ScaleX = 1, ScaleY = 1, Color = 0xFFFFFFFF });
// log objects in room_introstory begin/step
var r1 = Data.Rooms.ByName("room_introstory");
foreach (var gi in r1.GameObjects) Console.WriteLine("introstory inst: " + gi.ObjectDefinition.Name.Content + " " + gi.InstanceID);
