// Dumps object/room/variable metadata to JSON for the static analysis.
using System.IO;
using System.Linq;
using System.Text;
using Newtonsoft.Json;

EnsureDataLoaded();
string outPath = Environment.GetEnvironmentVariable("FL_META_OUT") ?? Path.Combine(Path.GetDirectoryName(FilePath), "work", "meta.json");
var objs = new List<object>();
foreach (var o in Data.GameObjects)
{
    var evs = new List<object>();
    for (int t = 0; t < o.Events.Count; t++)
        foreach (var e in o.Events[t])
            evs.Add(new { type = t, sub = e.EventSubtype, code = e.Actions.Select(a => a.CodeId?.Name?.Content).ToList() });
    objs.Add(new { name = o.Name.Content, parent = o.ParentId?.Name?.Content, depth = o.Depth, visible = o.Visible,
                   persistent = o.Persistent, solid = o.Solid, sprite = o.Sprite?.Name?.Content, events = evs });
}
var rooms = new List<object>();
foreach (var r in Data.Rooms)
{
    rooms.Add(new { name = r.Name.Content, speed = r.Speed, w = r.Width, h = r.Height, persistent = r.Persistent,
        flags = r.Flags.ToString(),
        views = r.Views.Select(v => new { v.Enabled, v.ViewX, v.ViewY, v.ViewWidth, v.ViewHeight, v.PortX, v.PortY, v.PortWidth, v.PortHeight,
                                          v.BorderX, v.BorderY, v.SpeedX, v.SpeedY, follow = v.ObjectId?.Name?.Content }).ToList(),
        ninst = r.GameObjects.Count, ntiles = r.Tiles.Count });
}
var vars = Data.Variables.Select(v => new { name = v.Name.Content, inst = v.InstanceType.ToString(), id = v.VarID }).ToList();
var funcs = Data.Functions.Select(f => f.Name.Content).ToList();
var gi = Data.GeneralInfo;
var info = new { gi.FileName.Content, Name = gi.Name.Content, Display = gi.DisplayName.Content, gi.Major, gi.Minor, gi.Release, gi.Build,
                 gi.SteamAppID, gi.LastObj, gi.DefaultWindowWidth, gi.DefaultWindowHeight, Info = gi.Info.ToString(),
                 RoomOrder = gi.RoomOrder.Select(r => r.Resource.Name.Content).ToList() };
File.WriteAllText(outPath, JsonConvert.SerializeObject(new { info, objs, rooms, vars, funcs }, Formatting.Indented));
Console.WriteLine("wrote " + outPath);
