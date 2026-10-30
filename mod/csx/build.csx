// Applies the framerate mod to a loaded data.win. Driven by mod/tools/build.py.
// Environment:
//   FL_GEN_DIR    folder of generated .gml code entries to import (replacing or creating them)
//   FL_ROOM_SPEED room speed to store in every room (the runtime also sets it each room)
//   FL_SAVE_NAME  optional: change the game's internal name, which moves its save folder (testing)
using System.IO;
using System.Linq;
using UndertaleModLib.Models;

EnsureDataLoaded();
string genDir = Environment.GetEnvironmentVariable("FL_GEN_DIR");
uint roomSpeed = uint.Parse(Environment.GetEnvironmentVariable("FL_ROOM_SPEED") ?? "60");
string saveName = Environment.GetEnvironmentVariable("FL_SAVE_NAME");

if (Data.GameObjects.ByName("obj___fl_first") != null)
    throw new Exception("This data file already has the framerate mod applied.");

UndertaleGameObject MakeObj(string name, bool persistent, int depth, bool visible)
{
    var o = new UndertaleGameObject { Name = Data.Strings.MakeString(name), Visible = visible, Persistent = persistent, Depth = depth };
    Data.GameObjects.Add(o);
    return o;
}
// Draw-phase events run in depth order, highest first: obj___fl_first opens each frame's
// draw phase (Pre-Draw) and obj___fl_last closes it (Draw GUI End).
var first = MakeObj("obj___fl_first", true, 1000000000, true);
var last = MakeObj("obj___fl_last", true, -1000000000, true);
MakeObj("obj___fl_sink", false, 0, false);

// Logic events that must only run on frames with a logic tick, and key events that must not
// react while the mod's settings menu is open.
var gated = new HashSet<string>();
var keyGated = new HashSet<string>();
foreach (var obj in Data.GameObjects)
{
    if (obj.Name.Content.StartsWith("obj___fl_"))
        continue;
    for (int t = 0; t < obj.Events.Count; t++)
    {
        var et = (EventType)t;
        foreach (var ev in obj.Events[t])
        {
            bool gate = et == EventType.Step || et == EventType.Alarm || et == EventType.Collision
                     || et == EventType.Keyboard || et == EventType.Mouse
                     || (et == EventType.Other && (ev.EventSubtype == 0 || ev.EventSubtype == 1));
            bool keyGate = et == EventType.KeyPress || et == EventType.KeyRelease;
            foreach (var act in ev.Actions)
            {
                if (act.CodeId == null)
                    continue;
                if (gate)
                    gated.Add(act.CodeId.Name.Content);
                if (keyGate)
                    keyGated.Add(act.CodeId.Name.Content);
            }
        }
    }
}

const string GATE = "if (global.__fl_skip)\n    exit;\n";
const string KEY_GATE = "if (global.__fl_menu)\n    exit;\n";
var group = new UndertaleModLib.Compiler.CodeImportGroup(Data);
var imported = new HashSet<string>();
foreach (var path in Directory.GetFiles(genDir, "*.gml").OrderBy(p => p, StringComparer.Ordinal))
{
    string name = Path.GetFileNameWithoutExtension(path);
    string code = File.ReadAllText(path);
    if (gated.Contains(name))
        code = GATE + code;
    if (keyGated.Contains(name))
        code = KEY_GATE + code;
    group.QueueReplace(name, code);
    imported.Add(name);
}
int prepends = 0;
foreach (var name in gated.Concat(keyGated))
{
    if (imported.Contains(name))
        continue;
    group.QueuePrepend(name, keyGated.Contains(name) ? KEY_GATE : GATE);
    prepends++;
}
var res = group.Import(false);
if (!res.Successful)
{
    Console.WriteLine(res.PrintAllErrors(false));
    throw new Exception("compile failed");
}
Console.WriteLine($"imported {imported.Count} entries, gated {gated.Count} ({prepends} by prepend)");

foreach (var room in Data.Rooms)
    room.Speed = roomSpeed;

var room0 = Data.GeneralInfo.RoomOrder.First().Resource;
foreach (var (obj, idx) in new[] { (first, 0), (last, 1) })
{
    room0.GameObjects.Insert(idx, new UndertaleRoom.GameObject
    {
        InstanceID = Data.GeneralInfo.LastObj++,
        ObjectDefinition = obj,
        X = 0, Y = 0, ScaleX = 1, ScaleY = 1, Color = 0xFFFFFFFF
    });
}

// Undertale's settings start with vsync on, which caps the frame rate at the monitor's refresh
// rate; the runtime turns it on only when the player's setting says so.
Data.GeneralInfo.Info &= ~(UndertaleGeneralInfo.InfoFlags.SyncVertex1 | UndertaleGeneralInfo.InfoFlags.SyncVertex2 | UndertaleGeneralInfo.InfoFlags.SyncVertex3);

if (!string.IsNullOrEmpty(saveName))
{
    Data.GeneralInfo.Name = Data.Strings.MakeString(saveName);
    Data.GeneralInfo.FileName = Data.Strings.MakeString(saveName);
    Console.WriteLine("save folder name: " + saveName);
}
Console.WriteLine("build ok");
