# O que o Intelligent Standby List Cleaner faz: quando a RAM livre cai abaixo de um quarto do total e a
# standby list (cache de arquivos que o Windows segura "por via das dúvidas") passa de 1 GB, esvazia a
# standby list. A chamada é a mesma do ISLC: NtSetSystemInformation(SystemMemoryListInformation,
# MemoryPurgeStandbyList), que precisa do privilégio SeProfileSingleProcessPrivilege (administrador).
# Roda pela tarefa agendada 'Standby list' (\mywiniso), a cada minuto, sem janela.
param([int] $LivreMinPorcento = 25, [int] $StandbyMinMB = 1024)

$os  = Get-CimInstance Win32_OperatingSystem
$perf = Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory     # nomes fixos, não dependem do idioma dos contadores
$totalMB   = [int]($os.TotalVisibleMemorySize / 1024)
$livreMB   = [int]($os.FreePhysicalMemory / 1024)
$standbyMB = [int](($perf.StandbyCacheNormalPriorityBytes + $perf.StandbyCacheCoreBytes + $perf.StandbyCacheReserveBytes) / 1MB)
if ($livreMB -gt $totalMB * $LivreMinPorcento / 100 -or $standbyMB -lt $StandbyMinMB) { exit 0 }

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Standby {
    [DllImport("ntdll.dll")] static extern int NtSetSystemInformation(int cls, ref int info, int len);
    [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
    [DllImport("advapi32.dll", SetLastError = true)] static extern bool OpenProcessToken(IntPtr h, uint acesso, out IntPtr tok);
    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)] static extern bool LookupPrivilegeValue(string sys, string nome, out long luid);
    [DllImport("advapi32.dll", SetLastError = true)] static extern bool AdjustTokenPrivileges(IntPtr tok, bool desliga, ref TP novo, int len, IntPtr ant, IntPtr ret);
    // Pack = 4: TOKEN_PRIVILEGES e {DWORD; LUID; DWORD} sem padding. Com o alinhamento padrao o long cai
    // no offset 8 em vez de 4, o kernel le lixo e devolve STATUS_PRIVILEGE_NOT_HELD (0xC0000061). Medido.
    [StructLayout(LayoutKind.Sequential, Pack = 4)] struct TP { public int Count; public long Luid; public int Attr; }
    public static int Purge() {
        IntPtr tok;
        if (!OpenProcessToken(GetCurrentProcess(), 0x28, out tok)) return -1;      // TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY
        TP tp; tp.Count = 1; tp.Attr = 2;                                          // SE_PRIVILEGE_ENABLED
        LookupPrivilegeValue(null, "SeProfileSingleProcessPrivilege", out tp.Luid);
        AdjustTokenPrivileges(tok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
        int cmd = 4;                                                               // MemoryPurgeStandbyList
        return NtSetSystemInformation(80, ref cmd, 4);                             // SystemMemoryListInformation
    }
}
'@
$rc = [Standby]::Purge()
$depois = [int]((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024)
$log = Join-Path $env:USERPROFILE 'mywiniso-standby.log'
Add-Content -LiteralPath $log -Value ("{0}  livre {1} MB, standby {2} MB -> purge rc=0x{3:X8}, livre depois {4} MB" -f (Get-Date -Format 'dd/MM HH:mm'), $livreMB, $standbyMB, $rc, $depois)
# o log não cresce sem parar: fica com as últimas 200 linhas
$linhas = Get-Content -LiteralPath $log
if ($linhas.Count -gt 200) { $linhas[-200..-1] | Set-Content -LiteralPath $log }
