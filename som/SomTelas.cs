// mywiniso: som mudo enquanto os monitores estao apagados.
//
// O Windows avisa pelo GUID_CONSOLE_DISPLAY_STATE (RegisterPowerSettingNotification) quando a tela apaga e
// acende. Vale para os dois jeitos de apagar: inatividade (Energia > desligar a tela) e o botao Telas do
// RicePanel, que manda SC_MONITORPOWER. Tela apagou: muta a saida de audio padrao. Tela voltou: desmuta, mas
// so se foi este programa que mutou (quem ja estava mudo continua mudo). Sem janela visivel; roda do logon
// ate desligar, pela tarefa "Som mudo com a tela apagada". Registro em somtelas.log ao lado do exe.
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

namespace MyWinIso
{
    [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDeviceEnumerator
    {
        int EnumAudioEndpoints(int fluxo, int estado, out IntPtr lista);
        int GetDefaultAudioEndpoint(int fluxo, int papel, out IMMDevice dispositivo);
        int GetDevice([MarshalAs(UnmanagedType.LPWStr)] string id, out IMMDevice dispositivo);
    }

    [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDevice
    {
        int Activate(ref Guid iid, int ctx, IntPtr parametros, [MarshalAs(UnmanagedType.IUnknown)] out object iface);
        int OpenPropertyStore(int acesso, out IntPtr loja);
        int GetId([MarshalAs(UnmanagedType.LPWStr)] out string id);
    }

    [ComImport, Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAudioEndpointVolume
    {
        int RegisterControlChangeNotify(IntPtr n);
        int UnregisterControlChangeNotify(IntPtr n);
        int GetChannelCount(out uint n);
        int SetMasterVolumeLevel(float db, ref Guid ctx);
        int SetMasterVolumeLevelScalar(float nivel, ref Guid ctx);
        int GetMasterVolumeLevel(out float db);
        int GetMasterVolumeLevelScalar(out float nivel);
        int SetChannelVolumeLevel(uint canal, float db, ref Guid ctx);
        int SetChannelVolumeLevelScalar(uint canal, float nivel, ref Guid ctx);
        int GetChannelVolumeLevel(uint canal, out float db);
        int GetChannelVolumeLevelScalar(uint canal, out float nivel);
        int SetMute([MarshalAs(UnmanagedType.Bool)] bool mudo, ref Guid ctx);
        int GetMute([MarshalAs(UnmanagedType.Bool)] out bool mudo);
    }

    static class Audio
    {
        static readonly Guid CLSID_Enumerador = new Guid("BCDE0395-E52F-467C-8E3D-C4579291692E");
        static Guid IID_Volume = new Guid("5CDF2C82-841E-4546-9722-0CF74078229A");
        static Guid Contexto = Guid.Empty;

        static IAudioEndpointVolume Volume(string id, out string idUsado)
        {
            IMMDeviceEnumerator en = (IMMDeviceEnumerator)Activator.CreateInstance(Type.GetTypeFromCLSID(CLSID_Enumerador));
            IMMDevice d;
            if (id == null) Marshal.ThrowExceptionForHR(en.GetDefaultAudioEndpoint(0, 1, out d)); // eRender, eMultimedia
            else Marshal.ThrowExceptionForHR(en.GetDevice(id, out d));
            d.GetId(out idUsado);
            object v;
            Marshal.ThrowExceptionForHR(d.Activate(ref IID_Volume, 23, IntPtr.Zero, out v)); // CLSCTX_ALL
            return (IAudioEndpointVolume)v;
        }

        // muta a saida padrao; devolve o id dela se estava com som (null se ja estava muda)
        public static string Mutar()
        {
            string id;
            IAudioEndpointVolume v = Volume(null, out id);
            bool mudo;
            v.GetMute(out mudo);
            if (mudo) return null;
            v.SetMute(true, ref Contexto);
            return id;
        }

        public static void Desmutar(string id)
        {
            string usado;
            IAudioEndpointVolume v = Volume(id, out usado);
            v.SetMute(false, ref Contexto);
        }
    }

    class Janela : Form
    {
        [DllImport("user32.dll")] static extern IntPtr RegisterPowerSettingNotification(IntPtr h, ref Guid g, int flags);
        [StructLayout(LayoutKind.Sequential, Pack = 4)]
        struct POWERBROADCAST_SETTING { public Guid PowerSetting; public uint DataLength; public uint Data; }

        static Guid GUID_CONSOLE_DISPLAY_STATE = new Guid("6FE69556-704A-47A0-8F24-C28D936FDA47");
        const int WM_POWERBROADCAST = 0x0218, PBT_POWERSETTINGCHANGE = 0x8013;

        string mutadoPorMim;   // id do dispositivo que este programa mutou
        readonly string log = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "somtelas.log");

        public Janela()
        {
            ShowInTaskbar = false;
            FormBorderStyle = FormBorderStyle.None;
            Opacity = 0;
            Size = new System.Drawing.Size(1, 1);
            StartPosition = FormStartPosition.Manual;
            Location = new System.Drawing.Point(-2000, -2000);
            CreateHandle(); // o form nunca fica visivel, entao a janela precisa nascer aqui para receber o aviso
        }

        protected override void SetVisibleCore(bool visivel) { base.SetVisibleCore(false); }

        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            RegisterPowerSettingNotification(Handle, ref GUID_CONSOLE_DISPLAY_STATE, 0); // DEVICE_NOTIFY_WINDOW_HANDLE
            Anotar("vigiando o estado da tela");
        }

        void Anotar(string m)
        {
            try { File.AppendAllText(log, DateTime.Now.ToString("dd/MM HH:mm:ss") + " " + m + Environment.NewLine); } catch { }
        }

        protected override void WndProc(ref Message m)
        {
            if (m.Msg == WM_POWERBROADCAST && (int)m.WParam == PBT_POWERSETTINGCHANGE)
            {
                POWERBROADCAST_SETTING s = (POWERBROADCAST_SETTING)Marshal.PtrToStructure(m.LParam, typeof(POWERBROADCAST_SETTING));
                if (s.PowerSetting == GUID_CONSOLE_DISPLAY_STATE)
                {
                    try
                    {
                        if (s.Data == 0 && mutadoPorMim == null)            // 0 = apagada
                        {
                            mutadoPorMim = Audio.Mutar();
                            Anotar(mutadoPorMim != null ? "tela apagou: som mudo" : "tela apagou: som ja estava mudo, nada a fazer");
                        }
                        else if (s.Data == 1 && mutadoPorMim != null)       // 1 = acesa (2 = esmaecida, ignora)
                        {
                            Audio.Desmutar(mutadoPorMim);
                            mutadoPorMim = null;
                            Anotar("tela voltou: som de volta");
                        }
                    }
                    catch (Exception ex) { Anotar("falhou: " + ex.Message); }
                }
            }
            base.WndProc(ref m);
        }

        [STAThread]
        static void Main()
        {
            bool unica;
            using (Mutex trava = new Mutex(true, "MyWinIsoSomTelas", out unica))
            {
                if (!unica) return;
                Application.Run(new Janela());
            }
        }
    }
}
