// ColarImagem: Ctrl+V no terminal cola texto na hora, pela colagem do proprio terminal, e so vira Alt+V (o
// "colar imagem" do Claude Code) quando a area de transferencia tem imagem e nao tem texto.
//
// Por que existe: com Ctrl+V ligado ao chat:imagePaste do Claude Code, cada colagem abria dois powershell.exe
// (um para ver se havia imagem, outro para ler o texto), ~2,1 s por Ctrl+V medidos em 13/09/2026. A checagem
// aqui e IsClipboardFormatAvailable, instantanea. Texto copiado do Word/Excel tambem traz bitmap: por isso
// texto presente sempre vence.
//
// Compila com o csc do .NET Framework 4.8 (C# 5). Sem barra invertida em literal de proposito.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

[assembly: System.Reflection.AssemblyTitle("ColarImagem")]
[assembly: System.Reflection.AssemblyProduct("MyWinISO")]
[assembly: System.Reflection.AssemblyVersion("1.0.0.0")]

namespace MyWinIso
{
    static class ColarImagem
    {
        const int WH_KEYBOARD_LL = 13;
        const int WM_KEYDOWN = 0x0100, WM_SYSKEYDOWN = 0x0104;
        const int VK_SHIFT = 0x10, VK_CONTROL = 0x11, VK_MENU = 0x12, VK_V = 0x56, VK_LWIN = 0x5B, VK_RWIN = 0x5C;
        const uint LLKHF_INJECTED = 0x10;
        const uint INPUT_KEYBOARD = 1, KEYEVENTF_KEYUP = 0x0002;
        const uint CF_BITMAP = 2, CF_DIB = 8, CF_UNICODETEXT = 13, CF_DIBV5 = 17;

        [StructLayout(LayoutKind.Sequential)]
        struct KBDLLHOOKSTRUCT { public uint vkCode, scanCode, flags, time; public IntPtr extra; }
        [StructLayout(LayoutKind.Sequential)]
        struct MOUSEINPUT { public int dx, dy; public uint mouseData, dwFlags, time; public IntPtr dwExtraInfo; }
        [StructLayout(LayoutKind.Sequential)]
        struct KEYBDINPUT { public ushort wVk, wScan; public uint dwFlags, time; public IntPtr dwExtraInfo; }
        [StructLayout(LayoutKind.Explicit)]
        struct UNIAO { [FieldOffset(0)] public MOUSEINPUT mi; [FieldOffset(0)] public KEYBDINPUT ki; }
        [StructLayout(LayoutKind.Sequential)]
        struct INPUT { public uint type; public UNIAO u; }

        delegate IntPtr HookProc(int code, IntPtr w, IntPtr l);

        [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SetWindowsHookEx(int id, HookProc proc, IntPtr mod, uint thread);
        [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr h, int code, IntPtr w, IntPtr l);
        [DllImport("user32.dll")] static extern short GetAsyncKeyState(int vk);
        [DllImport("user32.dll")] static extern bool IsClipboardFormatAvailable(uint fmt);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern uint RegisterClipboardFormat(string nome);
        [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
        [DllImport("user32.dll", SetLastError = true)] static extern uint SendInput(uint n, INPUT[] inputs, int tamanho);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern IntPtr GetModuleHandle(string nome);

        static HookProc gancho; // referencia viva: sem ela o GC coleta o delegate e o hook morre
        static uint cfPng;
        static readonly Dictionary<uint, string> nomes = new Dictionary<uint, string>();

        // janelas onde o Ctrl+V com imagem vira Alt+V: os terminais. No VS Code vale para o editor tambem, e por isso
        // o keybindings.json dele liga Alt+V a colar fora do terminal.
        static readonly string[] alvos = { "WindowsTerminal", "Code", "OpenConsole", "conhost", "pwsh", "powershell", "cmd", "mintty", "wezterm-gui", "alacritty" };

        [STAThread]
        static void Main()
        {
            bool unica;
            using (Mutex trava = new Mutex(true, "MyWinIsoColarImagem", out unica))
            {
                if (!unica) return;
                cfPng = RegisterClipboardFormat("PNG");
                gancho = Gancho;
                IntPtr h = SetWindowsHookEx(WH_KEYBOARD_LL, gancho, GetModuleHandle(null), 0);
                if (h == IntPtr.Zero) return;
                Application.Run(); // laco de mensagens: o hook de teclado baixo nivel precisa dele
            }
        }

        static bool Apertada(int vk) { return (GetAsyncKeyState(vk) & 0x8000) != 0; }

        static bool SoImagem()
        {
            if (IsClipboardFormatAvailable(CF_UNICODETEXT)) return false;
            return IsClipboardFormatAvailable(CF_BITMAP) || IsClipboardFormatAvailable(CF_DIB) ||
                   IsClipboardFormatAvailable(CF_DIBV5) || (cfPng != 0 && IsClipboardFormatAvailable(cfPng));
        }

        static bool NoTerminal()
        {
            uint pid;
            GetWindowThreadProcessId(GetForegroundWindow(), out pid);
            if (pid == 0) return false;
            string nome;
            if (!nomes.TryGetValue(pid, out nome))
            {
                try { using (Process p = Process.GetProcessById((int)pid)) nome = p.ProcessName; } catch { nome = ""; }
                if (nomes.Count > 200) nomes.Clear();
                nomes[pid] = nome;
            }
            foreach (string a in alvos) if (string.Equals(a, nome, StringComparison.OrdinalIgnoreCase)) return true;
            return false;
        }

        static INPUT Tecla(int vk, bool solta)
        {
            INPUT i = new INPUT();
            i.type = INPUT_KEYBOARD;
            i.u.ki.wVk = (ushort)vk;
            i.u.ki.dwFlags = solta ? KEYEVENTF_KEYUP : 0;
            return i;
        }

        static IntPtr Gancho(int code, IntPtr w, IntPtr l)
        {
            if (code >= 0)
            {
                int msg = w.ToInt32();
                if (msg == WM_KEYDOWN || msg == WM_SYSKEYDOWN)
                {
                    KBDLLHOOKSTRUCT k = (KBDLLHOOKSTRUCT)Marshal.PtrToStructure(l, typeof(KBDLLHOOKSTRUCT));
                    if (k.vkCode == VK_V && (k.flags & LLKHF_INJECTED) == 0 &&
                        Apertada(VK_CONTROL) && !Apertada(VK_MENU) && !Apertada(VK_SHIFT) && !Apertada(VK_LWIN) && !Apertada(VK_RWIN) &&
                        SoImagem() && NoTerminal())
                    {
                        INPUT[] seq = { Tecla(VK_CONTROL, true), Tecla(VK_MENU, false), Tecla(VK_V, false), Tecla(VK_V, true), Tecla(VK_MENU, true) };
                        SendInput((uint)seq.Length, seq, Marshal.SizeOf(typeof(INPUT)));
                        return (IntPtr)1; // engole o Ctrl+V original
                    }
                }
            }
            return CallNextHookEx(IntPtr.Zero, code, w, l);
        }
    }
}
