// Undertale Essentials. Copyright (C) 2026 Pixeo.
// Free software under the GNU GPL version 3 or later: see LICENSE.
// Fidelity test: decompile every code entry and recompile it unchanged, then compare disassembly.
using System.IO;
using System.Linq;
using System.Text;
using UndertaleModLib.Decompiler;

EnsureDataLoaded();
string root = Path.GetDirectoryName(FilePath);
string outDir = Path.Combine(root, "work", "roundtrip");
Directory.CreateDirectory(outDir);

GlobalDecompileContext gctx = new(Data);
var settings = Data.ToolInfo.DecompilerSettings;

var before = new Dictionary<string, string>();
var sources = new Dictionary<string, string>();
foreach (var code in Data.Code)
{
    if (code.ParentEntry != null) continue;
    before[code.Name.Content] = Disassembler.Disassemble(code, Data.Variables, Data.CodeLocals?.For(code));
    sources[code.Name.Content] = new Underanalyzer.Decompiler.DecompileContext(gctx, code, settings).DecompileToString();
}
Console.WriteLine("decompiled " + sources.Count);

var group = new UndertaleModLib.Compiler.CodeImportGroup(Data);
foreach (var kv in sources)
    group.QueueReplace(Data.Code.ByName(kv.Key), kv.Value);
var res = group.Import();
Console.WriteLine("compile ok: " + res.Successful);
if (!res.Successful) Console.WriteLine(res.PrintAllErrors(false));

int same = 0, diff = 0;
var sb = new StringBuilder();
foreach (var kv in before)
{
    var code = Data.Code.ByName(kv.Key);
    string after = Disassembler.Disassemble(code, Data.Variables, Data.CodeLocals?.For(code));
    if (after == kv.Value) same++;
    else
    {
        diff++;
        sb.AppendLine(kv.Key);
        File.WriteAllText(Path.Combine(outDir, kv.Key + ".before.asm"), kv.Value);
        File.WriteAllText(Path.Combine(outDir, kv.Key + ".after.asm"), after);
    }
}
File.WriteAllText(Path.Combine(outDir, "_diffs.txt"), sb.ToString());
Console.WriteLine($"same {same} diff {diff}");
