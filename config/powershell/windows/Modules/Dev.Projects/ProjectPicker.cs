using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Automation;

namespace Dotfiles {
    public static class ProjectPicker {
        private static long selectionStarted;
        [DllImport("kernel32.dll")] private static extern IntPtr GetStdHandle(int handle);
        [DllImport("kernel32.dll")] private static extern bool GetConsoleMode(IntPtr handle, out uint mode);
        [DllImport("kernel32.dll")] private static extern bool SetConsoleMode(IntPtr handle, uint mode);
        private static string[][] Load(string file) {
            try {
                return File.ReadAllLines(file).Where(line => line.Length > 0)
                    .Select(line => line.Split('\t').Select(value => Encoding.UTF8.GetString(Convert.FromBase64String(value))).ToArray())
                    .Where(fields => fields.Length == 3).ToArray();
            } catch (IOException) { return new string[0][]; }
            catch (FormatException) { return new string[0][]; }
        }
        private static string[][] Filter(string[][] projects, string query) {
            var words = query.Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
            return projects.Where(project => words.All(word =>
                string.Join(" ", project).IndexOf(word, StringComparison.OrdinalIgnoreCase) >= 0)).ToArray();
        }
        private static void RefreshSnapshot(string snapshot) {
            if (File.Exists(snapshot) && DateTime.UtcNow - File.GetLastWriteTimeUtc(snapshot) < TimeSpan.FromSeconds(60)) return;
            var file = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "picker.module.txt");
            if (!File.Exists(file)) return;
            var script = Path.Combine(Path.GetDirectoryName(File.ReadAllText(file).Trim()), "Start-ProjectPicker.ps1");
            var encoded = Convert.ToBase64String(Encoding.Unicode.GetBytes("& '" + script.Replace("'", "''") + "' -Refresh"));
            using (Process.Start(new ProcessStartInfo("pwsh.exe", "-NoProfile -EncodedCommand " + encoded) {
                UseShellExecute = false, CreateNoWindow = true, WindowStyle = ProcessWindowStyle.Hidden
            })) { }
        }
        private static string Clean(string value) {
            return new string(value.Select(c => char.IsControl(c) ? ' ' : c).ToArray());
        }
        private static string Fit(string value, int width) {
            value = Clean(value);
            if (width <= 0) return "";
            return value.Length <= width ? value : value.Substring(0, Math.Max(0, width - 1)) + "…";
        }
        private static void Render(string[][] matches, string query, int index, bool normal, int testWidth = 0, int testRows = 0) {
            int width = testWidth > 0 ? testWidth : (Console.IsOutputRedirected ? 100 : Math.Max(1, Console.WindowWidth - 1));
            int rows = testRows > 0 ? testRows : (Console.IsOutputRedirected ? 20 : Math.Max(1, Console.WindowHeight));
            int capacity = Math.Max(0, rows - 7);
            var lines = new List<string>();
            lines.Add("\x1b[1;38;5;223m" + Fit("  PROJECTS", width) + "\x1b[0m");
            string search = "  " + (normal ? "NORMAL / " : "Search / ") + query;
            lines.Add("\x1b[38;5;109m" + Fit(search, width) + "\x1b[0m");
            string rule = "\x1b[38;5;242m" + new string('─', width) + "\x1b[0m";
            lines.Add(rule);
            int first = Math.Max(0, index - capacity + 1);
            int names = Math.Min(28, Math.Max(10, width / 4));
            int branches = Math.Min(24, Math.Max(8, width / 5));
            for (int i = first; i < Math.Min(matches.Length, first + capacity); i++) {
                var project = matches[i];
                string text = width < 60 ? project[1] + "  [" + project[2] + "]" :
                    Fit(project[1], names).PadRight(names) + "  " + Fit(project[2], branches).PadRight(branches) + "  " + project[0];
                lines.Add((i == index ? "\x1b[48;5;237;38;5;223m" : "\x1b[38;5;250m") +
                    Fit((i == index ? "› " : "  ") + text, width).PadRight(width) + "\x1b[0m");
            }
            if (matches.Length == 0 && capacity > 0) lines.Add("\x1b[38;5;245m" + Fit("  No matches. Try a project, branch or path.", width) + "\x1b[0m");
            while (lines.Count < rows - 3) lines.Add("");
            lines.Add(rule);
            lines.Add("\x1b[38;5;245m" + Fit("  " + matches.Length + " results  ·  " + (matches.Length == 0 ? 0 : index + 1) + "/" + matches.Length, width) + "\x1b[0m");
            lines.Add("\x1b[38;5;245m" + Fit("  Enter open   ↑↓ / Ctrl+j/k move   Esc close   Tab " + (normal ? "search" : "vim"), width) + "\x1b[0m");
            var output = new StringBuilder("\x1b[H");
            for (int i = 0; i < Math.Min(rows, lines.Count); i++) {
                if (i > 0) output.Append("\r\n");
                output.Append(lines[i]).Append("\x1b[K");
            }
            output.Append("\x1b[J\x1b[2;").Append(Math.Min(width, Clean(search).Length + 1)).Append("H");
            Console.Write(output.ToString()); Console.Out.Flush();
        }
        private static string Title(string path) {
            return Path.GetFileName(path.TrimEnd('\\', '/'));
        }
        private static Dictionary<string, AutomationElement> ReadTabs(IntPtr window) {
            var tabs = new Dictionary<string, AutomationElement>();
            if (window == IntPtr.Zero) return tabs;
            try {
                var root = AutomationElement.FromHandle(window);
                var condition = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem);
                foreach (AutomationElement tab in root.FindAll(TreeScope.Descendants, condition)) tabs[tab.Current.Name] = tab;
            } catch (ElementNotAvailableException) { }
            catch (InvalidOperationException) { }
            return tabs;
        }
        // Windows argv quoting; Terminal handles semicolons as command separators.
        private static string Quote(string value) {
            var result = new StringBuilder("\"");
            int slashes = 0;
            foreach (char c in value) {
                if (c == '\\') { slashes++; continue; }
                result.Append('\\', c == '"' ? slashes * 2 + 1 : slashes);
                result.Append(c); slashes = 0;
            }
            return result.Append('\\', slashes * 2).Append('"').ToString();
        }
        private static Process Open(string path, string launcher) {
            if (!Directory.Exists(path)) throw new DirectoryNotFoundException("Checkout was removed. Refresh the project list.");
            var arguments = new[] { "-w", "0", "new-tab", "--profile", "{574e775e-4f2a-5b96-ac1e-a2962a402336}",
                "--inheritEnvironment", "-d", path, "--title", Title(path), "--suppressApplicationTitle" };
            var start = new ProcessStartInfo(launcher,
                string.Join(" ", arguments.Select(arg => Quote(arg.Replace(";", "\\;"))))) { UseShellExecute = false };
            // Terminal inherits this launch environment. The first prompt
            // records real selection-to-ready latency, including Terminal and the profile.
            start.EnvironmentVariables["DOTFILES_PROJECT_LAUNCH_TICKS"] =
                (selectionStarted == 0 ? DateTime.UtcNow.Ticks : selectionStarted).ToString();
            return Process.Start(start);
        }
        private static void WriteState(string file, string value) {
            var temp = file + "." + Process.GetCurrentProcess().Id + ".tmp";
            File.WriteAllText(temp, value, new UTF8Encoding(false));
            if (File.Exists(file)) File.Replace(temp, file, null); else File.Move(temp, file);
        }
        private static void RecordSelection(string[] project) {
            // After dispatch; no Git scan or PowerShell startup on selection.
            using (var mutex = new System.Threading.Mutex(false, @"Local\Dotfiles.Terminal.Projects")) {
                bool owned = false;
                try {
                    try { owned = mutex.WaitOne(2000); } catch (System.Threading.AbandonedMutexException) { owned = true; }
                    if (!owned) return;
                    var json = new JavaScriptSerializer();
                    var state = AppDomain.CurrentDomain.BaseDirectory;
                    var file = Path.Combine(state, "history.json");
                    var history = File.Exists(file) ? json.Deserialize<Dictionary<string, object>>(File.ReadAllText(file)) : new Dictionary<string, object>();
                    object current;
                    if (!history.TryGetValue("current", out current) || !String.Equals(current as string, project[0], StringComparison.OrdinalIgnoreCase)) {
                        history["previous"] = current; history["current"] = project[0];
                        WriteState(file, json.Serialize(history));
                    }
                    file = Path.Combine(state, "opened.json");
                    var opened = new List<Dictionary<string, object>>();
                    if (File.Exists(file)) {
                        var data = json.DeserializeObject(File.ReadAllText(file));
                        var array = data as object[] ?? new[] { data };
                        foreach (var entry in array) {
                            var item = entry as Dictionary<string, object>;
                            if (item != null && item.ContainsKey("Path") && !String.Equals(item["Path"] as string, project[0], StringComparison.OrdinalIgnoreCase)) opened.Add(item);
                        }
                    }
                    opened.Add(new Dictionary<string, object> { { "Path", project[0] }, { "Name", project[1] }, { "Branch", project[2] } });
                    WriteState(file, json.Serialize(opened));
                } catch (IOException) { }
                catch (ArgumentException) { }
                finally { if (owned) mutex.ReleaseMutex(); }
            }
        }
        public static int Main(string[] args) {
            if (args.Length == 3 && args[0] == "--benchmark-open") {
                var timer = Stopwatch.StartNew();
                using (var launched = Open(args[2], args[1])) launched.WaitForExit();
                Console.WriteLine(timer.Elapsed.TotalMilliseconds.ToString(System.Globalization.CultureInfo.InvariantCulture));
                return 0;
            }
            Console.OutputEncoding = new UTF8Encoding(false);
            bool benchmark = args.Contains("--benchmark");
            var snapshot = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "picker.tsv");
            var projects = Load(snapshot);
            if (args.Length == 4 && args[0] == "--render") {
                Render(Filter(projects, args[3]), args[3], 0, false, int.Parse(args[1]), int.Parse(args[2]));
                return 0;
            }
            if (args.Length == 3 && args[0] == "--record-selection") {
                RecordSelection(new[] { args[1], Path.GetFileName(args[1]), args[2] });
                return 0;
            }
            var version = File.GetLastWriteTimeUtc(snapshot);
            uint previousMode;
            var handle = GetStdHandle(-11);
            bool restoreMode = GetConsoleMode(handle, out previousMode);
            if (restoreMode) SetConsoleMode(handle, previousMode | 4);
            string[] selected = null;
            Task<Dictionary<string, AutomationElement>> tabs = null;
            try {
                if (!Console.IsOutputRedirected) Console.Write("\x1b[?1049h");
                string query = "";
                bool normal = false, pendingG = false, refreshed = false;
                int index = 0;
                while (true) {
                    var matches = Filter(projects, query);
                    index = Math.Max(0, Math.Min(index, matches.Length - 1));
                    Render(matches, query, index, normal);
                    if (benchmark) {
                        var filtered = Filter(projects, "project-99");
                        Render(filtered, "project-99", 0, false);
                        return filtered.Length == 11 ? 0 : 2;
                    }
                    if (Console.IsInputRedirected) return 1;
                    if (tabs == null) {
                        var window = ProjectWindows.CurrentTerminalWindow();
                        tabs = Task.Run(() => ReadTabs(window));
                    }
                    if (!refreshed) { RefreshSnapshot(snapshot); refreshed = true; }
                    var key = Console.ReadKey(true);
                    bool ctrl = (key.Modifiers & ConsoleModifiers.Control) != 0;
                    if (key.Key == ConsoleKey.Escape) break;
                    if (key.Key == ConsoleKey.Enter && matches.Length > 0) {
                        selectionStarted = DateTime.UtcNow.Ticks; selected = matches[index]; break;
                    }
                    // Refresh only after handling the displayed selection, so Enter cannot select an unseen row.
                    var updated = File.GetLastWriteTimeUtc(snapshot);
                    if (updated != version) { version = updated; projects = Load(snapshot); }
                    if (key.Key == ConsoleKey.Tab || (ctrl && key.Key == ConsoleKey.Oem4)) { normal = !normal; continue; }
                    if (key.Key == ConsoleKey.DownArrow || (ctrl && key.Key == ConsoleKey.J) || (normal && key.KeyChar == 'j')) { index++; pendingG = false; continue; }
                    if (key.Key == ConsoleKey.UpArrow || (ctrl && key.Key == ConsoleKey.K) || (normal && key.KeyChar == 'k')) { index--; pendingG = false; continue; }
                    if (normal) {
                        if (key.KeyChar == 'g') { if (pendingG) index = 0; pendingG = !pendingG; }
                        else { pendingG = false; if (key.KeyChar == 'G') index = matches.Length - 1; if (key.KeyChar == '/') normal = false; }
                    } else if (key.Key == ConsoleKey.Backspace && query.Length > 0) { query = query.Substring(0, query.Length - 1); index = 0; }
                    else if (!char.IsControl(key.KeyChar)) { query += key.KeyChar; index = 0; }
                }
            } finally {
                if (!Console.IsOutputRedirected) Console.Write("\x1b[?1049l");
                if (restoreMode) SetConsoleMode(handle, previousMode);
            }
            if (selected != null) {
                try {
                    bool focused = false;
                    bool ambiguous = projects.Any(project =>
                        !String.Equals(project[0], selected[0], StringComparison.OrdinalIgnoreCase) &&
                        String.Equals(Title(project[0]), Title(selected[0]), StringComparison.OrdinalIgnoreCase));
                    if (!ambiguous && tabs != null && tabs.Status == TaskStatus.RanToCompletion) {
                        try {
                            AutomationElement tab;
                            if (tabs.Result.TryGetValue(Title(selected[0]), out tab)) {
                                ((SelectionItemPattern)tab.GetCurrentPattern(SelectionItemPattern.Pattern)).Select();
                                focused = true;
                            }
                        } catch (Exception) { /* A closed tab or restricted UIA falls back to opening. */ }
                    }
                    if (!focused) using (Open(selected[0], "wt.exe")) { }
                    RecordSelection(selected);
                } catch (Exception error) {
                    Console.WriteLine("Could not open project: " + error.Message + "\nPress any key to close.");
                    if (!Console.IsInputRedirected) Console.ReadKey(true);
                    return 1;
                }
            }
            return 0;
        }
    }
}
