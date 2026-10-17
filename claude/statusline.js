// Status line do Alexandre.
// ◆ Opus 5 · ▲ high · ◐ contexto 140k de 250k · ◈ 62% 03:01
//
// Node em vez de PowerShell: 70 ms por execucao contra 247 ms. Com o
// refreshInterval de 30 s isso importa — a linha roda a vida toda da sessao.
//
// Icones sao glifos geometricos (nao emoji): herdam a cor ANSI. Emoji ignora cor.
// SO O CONTEXTO muda de cor conforme enche. Cada outro campo tem cor propria.

const fs = require('fs');
const os = require('os');
const path = require('path');

const E = '\x1b';
const LARANJA  = `${E}[38;5;172m`;
const CIANO    = `${E}[38;5;80m`;
const CINZA    = `${E}[38;5;245m`;
const VERDE    = `${E}[38;5;71m`;
const AMARELO  = `${E}[38;5;179m`;
const VERMELHO = `${E}[38;5;167m`;
const NEGRITO  = `${E}[1m`;
const RESET    = `${E}[0m`;

const ICO_MODELO  = '◆'; // losango cheio
const ICO_ESFORCO = '▲'; // triangulo
const ICO_RAPIDO  = '▸'; // seta pequena
const ICO_TEMPO   = '◈'; // losango vazado (janela de 5h)
const ICO_SEMANA  = '▦'; // quadriculado (janela semanal)
const ICO_ALERTA  = '■'; // quadrado cheio

// Contexto: um circulo so, que vai enchendo.
const CIRCULO = ['○', '◔', '◐', '◕', '●'];

// ---------- estado da sessao (stdin) ----------
let dados = null;
try {
    const bruto = fs.readFileSync(0, 'utf8');
    if (bruto && bruto.trim()) dados = JSON.parse(bruto);
} catch (_) { }

const partes = [];
const limpa = (t) => String(t == null ? '' : t).replace(/[\x00-\x1F]/g, '');

// ---------- modelo: cada familia com a sua cor ----------
// Opus e Fable sao os que ele usa; ganham as cores mais fortes, para dar pra
// distinguir de relance qual esta valendo sem ler o nome.
const CORES_MODELO = [
    [/opus/i,   `${E}[38;5;141m`], // roxo
    [/fable/i,  `${E}[38;5;213m`], // rosa
    [/sonnet/i, `${E}[38;5;74m`],  // azul
    [/haiku/i,  `${E}[38;5;108m`], // verde acinzentado
];

const m = dados && dados.model;
const modelo = (m && (m.display_name || m.id)) || 'modelo?';
const idModelo = `${(m && m.display_name) || ''} ${(m && m.id) || ''}`;
const corModelo = (CORES_MODELO.find(([re]) => re.test(idModelo)) || [null, CIANO])[1];
partes.push(`${corModelo}${ICO_MODELO} ${limpa(modelo)}${RESET}`);

// ---------- esforco: cor propria (verde no alto, amarelo quando cai) ----------
if (dados && dados.effort && dados.effort.level) {
    const nivel = String(dados.effort.level).toLowerCase().replace(/[^a-z]/g, '');
    if (nivel) {
        const cor = ['high', 'xhigh', 'max'].includes(nivel) ? VERDE : AMARELO;
        partes.push(`${cor}${ICO_ESFORCO} ${nivel}${RESET}`);
    }
}
if (dados && dados.fast_mode === true) partes.push(`${AMARELO}${ICO_RAPIDO} rapido${RESET}`);

// ---------- contexto: o UNICO campo que troca de cor conforme aperta ----------
const ctx = dados && dados.context_window;
let pct = null;
if (ctx) {
    if (ctx.used_percentage != null) {
        pct = Number(ctx.used_percentage);
    } else if (ctx.current_usage && ctx.context_window_size > 0) {
        // Mesma formula do used_percentage: so entrada, sem output.
        const u = ctx.current_usage;
        const entrada = Number(u.input_tokens || 0)
            + Number(u.cache_creation_input_tokens || 0)
            + Number(u.cache_read_input_tokens || 0);
        pct = (entrada / Number(ctx.context_window_size)) * 100;
    }
}

// Janela em que o auto-compact dispara, lida do settings.json (a mesma que o
// setup.ps1 grava). O Claude manda context_window_size = 1M, mas com
// autoCompactWindow = 250k a sessao compacta nos 250k; mostrar "de 1M" enganava.
// Valor por modelo (modelSettings) vence o global, igual ao Claude.
function janelaCompactacao(idModelo) {
    try {
        const cfg = JSON.parse(fs.readFileSync(path.join(os.homedir(), '.claude', 'settings.json'), 'utf8'));
        const porModelo = cfg.modelSettings && cfg.modelSettings[idModelo];
        return Number((porModelo && porModelo.autoCompactWindow) || cfg.autoCompactWindow) || 0;
    } catch (_) { return 0; }
}

if (pct != null && !Number.isNaN(pct)) {
    const janela = Number(ctx.context_window_size) || 0;
    // Token exato quando o Claude manda o uso; senao, a porcentagem (passos de 1% = 10k em 1M).
    const u = ctx.current_usage;
    const tokens = u
        ? Number(u.input_tokens || 0) + Number(u.cache_creation_input_tokens || 0) + Number(u.cache_read_input_tokens || 0)
        : Math.round((pct / 100) * janela);

    // O alvo e onde a sessao compacta, nao o tamanho da janela do modelo.
    const compacta = janelaCompactacao(m && m.id);
    const alvo = compacta > 0 && (janela === 0 || compacta < janela) ? compacta : janela;
    const p = alvo > 0 ? Math.round((tokens / alvo) * 100) : Math.round(pct);

    let nivel;
    if      (p >= 90) nivel = 3;   // vai compactar
    else if (p >= 75) nivel = 2;   // perto de compactar
    else if (p >= 50) nivel = 1;   // atencao
    else              nivel = 0;   // tranquilo

    const cor = [VERDE, AMARELO, LARANJA, VERMELHO][nivel];
    // O circulo enche meio passo antes, para ter os cinco estagios.
    const ico = CIRCULO[nivel === 0 ? (p >= 25 ? 1 : 0) : nivel + 1];

    const k = (n) => n >= 1000000 ? `${+(n / 1000000).toFixed(1)}M` : `${Math.round(n / 1000)}k`;
    const texto = alvo > 0 ? `contexto ${k(tokens)} de ${k(alvo)}` : `contexto ${p}%`;
    const aviso = compacta > 0 && compacta < janela ? ['', '', ' — perto de compactar', ' — compactando'] : ['', '', ' — pesado', ' — LIMPA A SESSAO'];

    if (nivel === 3)      partes.push(`${cor}${NEGRITO}${ico} ${texto}${aviso[3]}${RESET}`);
    else if (nivel === 2) partes.push(`${cor}${ico} ${texto}${aviso[2]}${RESET}`);
    else                  partes.push(`${cor}${ico} ${texto}${RESET}`);
}

// ---------- janela de 5h: quanto ja foi e quanto falta pra virar ----------
const j = dados && dados.rate_limits && dados.rate_limits.five_hour;
if (j && j.used_percentage != null) {
    const r = Math.round(Number(j.used_percentage));

    // Cor propria: cinza tranquilo, amarelo apertando, vermelho no fim.
    const cor = r >= 85 ? VERMELHO : r >= 70 ? AMARELO : CINZA;
    const ico = r >= 85 ? ICO_ALERTA : ICO_TEMPO;

    // Relogio regressivo HH:MM. Arredonda o minuto em curso pra cima, senao
    // mostraria 03:00 durante os ultimos 59 segundos antes de virar.
    let falta = '';
    if (j.resets_at != null) {
        const seg = Math.round(Number(j.resets_at) - Date.now() / 1000);
        if (seg > 0) {
            const min = Math.ceil(seg / 60);
            const hh = String(Math.floor(min / 60)).padStart(2, '0');
            const mm = String(min % 60).padStart(2, '0');
            falta = ` ${hh}:${mm}`;
        }
    }

    partes.push(`${cor}${ico} ${r}%${falta}${RESET}`);
}

// ---------- janela semanal: quanto ja foi e quanto falta pra virar ----------
const sem = dados && dados.rate_limits && dados.rate_limits.seven_day;
if (sem && sem.used_percentage != null) {
    const r = Math.round(Number(sem.used_percentage));
    // Mesma regra de cor da janela de 5h; o x troca para Sonnet a partir de 75%.
    const cor = r >= 85 ? VERMELHO : r >= 70 ? AMARELO : CINZA;
    const ico = r >= 85 ? ICO_ALERTA : ICO_SEMANA;
    let falta = '';
    if (sem.resets_at != null) {
        const seg = Math.round(Number(sem.resets_at) - Date.now() / 1000);
        if (seg > 0) {
            const h = Math.ceil(seg / 3600);
            falta = h >= 24 ? ` ${Math.floor(h / 24)}d${String(h % 24).padStart(2, '0')}h` : ` ${h}h`;
        }
    }
    partes.push(`${cor}${ico} semana ${r}%${falta}${RESET}`);
}

process.stdout.write(partes.join(`${CINZA} · ${RESET}`));
