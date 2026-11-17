using System;
using System.Runtime.InteropServices;
using System.Text;
namespace Dotfiles {
    public static class ProjectWindows {
        private delegate bool Visitor(IntPtr window, IntPtr unused);
        [DllImport("user32.dll")] private static extern bool EnumWindows(Visitor visit, IntPtr unused);
        [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetWindowText(IntPtr window, StringBuilder text, int size);
        [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr window, StringBuilder text, int size);
        [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern IntPtr GetProp(IntPtr window, string key);
        [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern bool SetProp(IntPtr window, string key, IntPtr value);
        [DllImport("user32.dll")] private static extern bool IsIconic(IntPtr window);
        [DllImport("user32.dll")] private static extern bool ShowWindowAsync(IntPtr window, int command);
        [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr window);
        [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();

        public static IntPtr Find(string id, string title) {
            IntPtr found = IntPtr.Zero;
            EnumWindows((window, _) => {
                var text = new StringBuilder(512);
                GetClassName(window, text, text.Capacity);
                if (text.ToString() != "CASCADIA_HOSTING_WINDOW_CLASS") return true;
                if (GetProp(window, id) == IntPtr.Zero) {
                    if (String.IsNullOrEmpty(title)) return true;
                    text.Clear();
                    GetWindowText(window, text, text.Capacity);
                    if (text.ToString() != title || !SetProp(window, id, new IntPtr(1))) return true;
                }
                found = window;
                return false;
            }, IntPtr.Zero);
            return found;
        }

        public static bool Focus(IntPtr window) {
            if (GetForegroundWindow() == window) return true;
            if (IsIconic(window)) ShowWindowAsync(window, 9);
            return SetForegroundWindow(window);
        }
    }
}
