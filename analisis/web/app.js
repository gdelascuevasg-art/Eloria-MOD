// Panel de análisis de Eloria: solo lee de la API local (eloria.py).
const $ = id => document.getElementById(id);
const estado = { pj: null, personajes: [] };

const corto = n => {
  n = Number(n || 0);
  for (const [d, s] of [[1e9, 'kkk'], [1e6, 'kk'], [1e3, 'k']])
    if (Math.abs(n) >= d) return (n / d).toFixed(1).replace(/\.0$/, '') + s;
  return n.toFixed(0);
};
const hora = t => new Date(t * 1000).toLocaleString('es-ES', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' });
const durac = s => s >= 3600 ? (s / 3600).toFixed(1) + ' h' : Math.round(s / 60) + ' min';
const hace = s => s < 90 ? 'ahora' : s < 3600 ? `hace ${Math.round(s / 60)} min` : s < 86400 ? `hace ${Math.round(s / 3600)} h` : `hace ${Math.round(s / 86400)} d`;
const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const api = async (ruta, params = {}) => {
  const q = new URLSearchParams(params).toString();
  const r = await fetch('/api/' + ruta + (q ? '?' + q : ''));
  return r.json();
};

async function cargarResumen() {
  const r = await api('resumen');
  estado.personajes = r.personajes;
  if (!estado.pj && r.personajes.length) {
    const reciente = [...r.personajes].sort((a, b) => (b.ultimo || 0) - (a.ultimo || 0))[0];
    estado.pj = reciente.pj;
  }
  $('tarjetas').innerHTML = r.personajes.map(p => {
    const on = p.ultimo && r.ahora - p.ultimo < 120;
    return `<div class="tarjeta ${p.pj === estado.pj ? 'sel' : ''}" data-pj="${esc(p.pj)}">
      <h3>${esc(p.pj)} <span class="punto ${on ? 'on' : ''}" title="${on ? 'grabando' : 'sin datos recientes'}"></span></h3>
      <div class="sub">${p.nivel ? 'nivel ' + p.nivel.toLocaleString('es-ES') : ''} ${p.zona ? '· ' + esc(p.zona) : ''} · ${p.ultimo ? hace(r.ahora - p.ultimo) : 'sin datos'}</div>
      <div class="kv">
        <span>XP 1 h</span><span>${corto(p.xp_h_1h)}</span>
        <span>RAW 1 h</span><span>${corto(p.raw_h_1h)}</span>
        <span>XP 24 h</span><span>${corto(p.xp_24h)}</span>
        <span>Caza 24 h</span><span>${durac(p.caza_24h)}</span>
        <span>Muertes 24 h</span><span class="${p.muertes_24h ? 'malo' : ''}">${p.muertes_24h}</span>
      </div></div>`;
  }).join('') || '<div class="vacio">Todavía no hay datos. Carga el mod en el cliente y espera un minuto.</div>';
  document.querySelectorAll('.tarjeta').forEach(el => el.onclick = () => { estado.pj = el.dataset.pj; refrescar(); });
  $('conclusiones').innerHTML = r.conclusiones.map(c => `<li>${esc(c)}</li>`).join('') || '<li class="vacio">Aún no hay sesiones de 15 min o más.</li>';
}

function grafica(puntos, campo) {
  const W = 1100, H = 260, L = 64, R = 16, T = 12, B = 28;
  const pts = puntos.filter(p => p[campo] != null);
  if (pts.length < 2) { $('grafica').innerHTML = '<div class="vacio">Sin datos en este rango.</div>'; return; }
  const t0 = pts[0].t, t1 = pts[pts.length - 1].t;
  const vals = pts.map(p => p[campo]);
  const lo = campo === 'nivel' ? Math.min(...vals) : 0, hi = Math.max(...vals) || 1;
  const X = t => L + (t - t0) / Math.max(t1 - t0, 1) * (W - L - R);
  const Y = v => T + (1 - (v - lo) / Math.max(hi - lo, 1)) * (H - T - B);
  let d = '', prev = null;
  for (const p of pts) {   // hueco en la línea si faltan datos más de 30 min
    d += (prev && p.t - prev.t <= 1800 ? 'L' : 'M') + X(p.t).toFixed(1) + ' ' + Y(p[campo]).toFixed(1);
    prev = p;
  }
  const ticksY = [0, .25, .5, .75, 1].map(f => lo + f * (hi - lo));
  const nT = 6, ticksX = Array.from({ length: nT + 1 }, (_, i) => t0 + i * (t1 - t0) / nT);
  const fmt = campo === 'nivel' ? v => Math.round(v).toLocaleString('es-ES') : campo === 'kills_min' ? v => v.toFixed(0) : corto;
  $('grafica').innerHTML = `<svg viewBox="0 0 ${W} ${H}" width="100%" role="img" aria-label="${campo}">
    ${ticksY.map(v => `<line x1="${L}" x2="${W - R}" y1="${Y(v)}" y2="${Y(v)}" stroke="var(--line)"/><text x="${L - 8}" y="${Y(v) + 4}" text-anchor="end">${fmt(v)}</text>`).join('')}
    ${ticksX.map((t, i) => `<text x="${X(t)}" y="${H - 8}" text-anchor="${i === 0 ? 'start' : i === nT ? 'end' : 'middle'}">${hora(t)}</text>`).join('')}
    <path d="${d}" fill="none" stroke="var(--accent)" stroke-width="1.6"/>
    <rect id="zonaTip" x="${L}" y="${T}" width="${W - L - R}" height="${H - T - B}" fill="transparent"/>
  </svg>`;
  const svg = $('grafica').querySelector('svg'), tip = $('tip');
  $('zonaTip').onmousemove = e => {
    const r = svg.getBoundingClientRect(), x = (e.clientX - r.left) / r.width * W;
    const t = t0 + (x - L) / (W - L - R) * (t1 - t0);
    const p = pts.reduce((a, b) => Math.abs(b.t - t) < Math.abs(a.t - t) ? b : a);
    tip.style.display = 'block'; tip.style.left = e.clientX + 12 + 'px'; tip.style.top = e.clientY - 30 + 'px';
    tip.textContent = `${hora(p.t)} · ${fmt(p[campo])}`;
  };
  $('zonaTip').onmouseleave = () => tip.style.display = 'none';
}

function barras(el, lista, total) {
  const max = Math.max(...lista.map(x => x.valor), 1);
  el.innerHTML = lista.length ? lista.map(x => `<div class="barra"><span>${esc(x.nombre)}</span>
    <div class="pista"><div class="relleno" style="width:${(x.valor / max * 100).toFixed(1)}%"></div></div>
    <span class="val">${total ? Math.round(x.valor * 100 / total) + '%' : corto(x.valor)}</span></div>`).join('')
    : '<div class="vacio">Sin daño registrado (lo graba el recolector nuevo).</div>';
}

async function cargarDetalle() {
  const pj = estado.pj;
  const horas = $('rango').value, campo = $('metrica').value;
  $('tituloSerie').textContent = `${$('metrica').selectedOptions[0].text} · ${pj || ''}`;
  if (!pj) return;
  const paso = horas <= 24 ? 600 : horas <= 168 ? 1800 : 7200;
  const [serie, ses, dano, muertes, buffs] = await Promise.all([
    api('serie', { pj, horas, paso }), api('sesiones', { pj, horas }), api('dano', { pj, horas }),
    api('muertes', { pj, horas }), api('buffs', { pj, horas }),
  ]);
  grafica(serie, campo);
  $('sesiones').innerHTML = `<tr><th>Inicio</th><th class="izq">Zona</th><th>Duración</th><th>Activo</th><th>XP/h</th><th>RAW/h</th><th>Mult.</th><th>Kills/min</th><th>Niveles</th><th>Muertes</th></tr>` +
    (ses.map(s => `<tr><td>${hora(s.inicio)}</td><td class="izq">${esc(s.zona)}</td><td>${durac(s.duracion)}</td>
      <td>${Math.round(s.activo * 100 / s.duracion)}%</td><td>${corto(s.xp_h)}</td><td>${corto(s.raw_h)}</td>
      <td>${s.mult ? 'x' + s.mult.toFixed(1) : '-'}</td><td>${s.kills_min.toFixed(0)}</td>
      <td>${s.nivel_ini && s.nivel_fin ? s.nivel_ini + ' → ' + s.nivel_fin : '-'}</td>
      <td class="${s.muertes ? 'malo' : ''}">${s.muertes}</td></tr>`).join('') || '<tr><td colspan="10" class="vacio">Sin sesiones en este rango.</td></tr>');
  barras($('elementos'), dano.elementos, dano.total);
  barras($('origenes'), dano.origenes, dano.total);
  $('muertes').innerHTML = '<tr><th>Cuándo</th><th class="izq">Personaje</th><th class="izq">Zona</th><th>Nivel</th></tr>' +
    (muertes.map(m => `<tr><td>${hora(m.t)}</td><td class="izq">${esc(m.pj)}</td><td class="izq">${esc(m.zona)}</td><td>${m.nivel ?? '-'}</td></tr>`).join('') || '<tr><td colspan="4" class="vacio">Ninguna.</td></tr>');
  $('buffs').innerHTML = '<tr><th>Cuándo</th><th class="izq">Personaje</th><th class="izq">Poción</th></tr>' +
    (buffs.slice(0, 40).map(b => `<tr><td>${hora(b.t)}</td><td class="izq">${esc(b.pj)}</td><td class="izq">${esc(b.nombre)}</td></tr>`).join('') || '<tr><td colspan="3" class="vacio">Ninguna.</td></tr>');
}

async function refrescar() {
  try {
    await cargarResumen();
    await cargarDetalle();
    $('estado').textContent = 'actualizado ' + new Date().toLocaleTimeString('es-ES');
  } catch (e) {
    $('estado').textContent = 'sin conexión con eloria.py';
  }
}

$('rango').onchange = $('metrica').onchange = cargarDetalle;
$('btnImportar').onclick = async () => {
  $('estado').textContent = 'importando…';
  await fetch('/api/importar', { method: 'POST' });
  refrescar();
};
refrescar();
setInterval(refrescar, 60000);
