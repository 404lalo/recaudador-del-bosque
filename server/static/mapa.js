// Mapa del nivel (vista desde arriba del corredor) con zoom y arrastre.
// Coordenadas del juego: el jugador avanza hacia -Z y se mueve a los lados en X.
// En el mapa: avanzar = hacia la derecha, X = arriba/abajo.
const NS = "http://www.w3.org/2000/svg";

function el(tag, attrs, parent) {
  const e = document.createElementNS(NS, tag);
  for (const k in attrs || {}) e.setAttribute(k, attrs[k]);
  if (parent) parent.appendChild(e);
  return e;
}
function P(x, z) { return [-z, x]; }  // mundo -> mapa

function crearMapa(svg, plano) {
  const capas = {};
  for (const n of ["suelo", "calor", "ruta", "objetos", "eventos", "jugador", "etiquetas"]) {
    capas[n] = el("g", { class: "capa-" + n }, svg);
  }
  const half = plano.half || 14, z0 = plano.start_z ?? 6, z1 = plano.end_z ?? -150;
  const pw = plano.path_w || 4;
  // Suelo del corredor y camino.
  el("rect", { x: -z0 - 4, y: -half, width: (z0 - z1) + 8, height: half * 2, class: "m-suelo", rx: 1 }, capas.suelo);
  el("rect", { x: -z0 - 4, y: -pw / 2, width: (z0 - z1) + 8, height: pw, class: "m-camino" }, capas.suelo);
  // Rejilla cada 10 m.
  for (let z = Math.ceil(z0 / 10) * 10; z >= z1 - 4; z -= 10) {
    el("line", { x1: -z, y1: -half, x2: -z, y2: half, class: "m-rejilla" }, capas.suelo);
  }
  // Plataformas.
  for (const p of plano.plataformas || []) {
    const [cx, cy] = P(p.x, p.z);
    const r = el("rect", { x: cx - p.d / 2, y: cy - p.w / 2, width: p.d, height: p.w, rx: 0.3,
      class: "m-plataforma" + (p.movil ? " movil" : "") }, capas.objetos);
    r.dataset.tip = `Plataforma · altura ${p.h.toFixed(1)} m${p.movil ? " · móvil" : ""}`;
  }
  // Zona del depredador y arco final.
  if (plano.depredador_z != null) {
    el("line", { x1: -plano.depredador_z, y1: -half, x2: -plano.depredador_z, y2: half, class: "m-depredador" }, capas.objetos);
    el("text", { x: -plano.depredador_z + 0.6, y: -half + 1.6, class: "m-txt m-txt-mal" }, capas.etiquetas).textContent = "Depredador";
  }
  el("line", { x1: -z1, y1: -3.2, x2: -z1, y2: 3.2, class: "m-arco" }, capas.objetos);
  el("text", { x: -z1 + 0.8, y: 0.5, class: "m-txt" }, capas.etiquetas).textContent = "Arco final";
  el("circle", { cx: -z0, cy: 0, r: 0.7, class: "m-inicio" }, capas.objetos);
  el("text", { x: -z0 - 0.4, y: -1.2, class: "m-txt", "text-anchor": "end" }, capas.etiquetas).textContent = "Inicio";
  // Animales.
  const animales = {};
  for (const a of plano.animales || []) {
    const [cx, cy] = P(a.x, a.z);
    const g = el("g", { class: "m-animal" }, capas.objetos);
    el("circle", { cx, cy, r: 1.0 }, g);
    const t = el("text", { x: cx, y: cy + (cy < 0 ? -1.6 : 2.4), class: "m-txt", "text-anchor": "middle" }, capas.etiquetas);
    t.textContent = a.nombre;
    g.dataset.tip = a.nombre;
    animales[a.nombre] = g;
  }
  // Bellotas.
  const bellotas = {};
  for (const b of plano.bellotas || []) {
    const [cx, cy] = P(b.x, b.z);
    const d = el("path", { d: `M${cx} ${cy - 0.9} L${cx + 0.7} ${cy} L${cx} ${cy + 0.9} L${cx - 0.7} ${cy} Z`, class: "m-bellota" }, capas.objetos);
    d.dataset.tip = "Bellota dorada";
    bellotas[b.id] = d;
  }

  // ---- zoom y arrastre (viewBox en metros)
  const fit = { x: -z0 - 8, y: -half - 3, w: (z0 - z1) + 16, h: half * 2 + 6 };
  let vb = { ...fit };
  const aplicar = () => svg.setAttribute("viewBox", `${vb.x} ${vb.y} ${vb.w} ${vb.h}`);
  const zoom = (f, cx, cy) => {
    cx = cx ?? vb.x + vb.w / 2; cy = cy ?? vb.y + vb.h / 2;
    const w = Math.min(fit.w * 2, Math.max(12, vb.w * f));
    const k = w / vb.w;
    vb = { x: cx - (cx - vb.x) * k, y: cy - (cy - vb.y) * k, w, h: vb.h * k };
    aplicar();
  };
  const ajustar = () => { vb = { ...fit }; aplicar(); };
  svg.setAttribute("preserveAspectRatio", "xMidYMid meet");
  // Alto del mapa según la forma del nivel (son corredores largos).
  const ajustarAlto = () => {
    const ancho = svg.getBoundingClientRect().width || 900;
    svg.style.height = Math.round(Math.min(440, Math.max(240, ancho * fit.h / fit.w * 1.6))) + "px";
  };
  ajustarAlto();
  window.addEventListener("resize", ajustarAlto);
  ajustar();
  const punto = (ev) => {
    const r = svg.getBoundingClientRect();
    const s = Math.max(vb.w / r.width, vb.h / r.height);
    const ox = (r.width * s - vb.w) / 2, oy = (r.height * s - vb.h) / 2;
    return [vb.x - ox + (ev.clientX - r.left) * s, vb.y - oy + (ev.clientY - r.top) * s, s];
  };
  svg.addEventListener("wheel", (ev) => {
    ev.preventDefault();
    const [x, y] = punto(ev);
    zoom(ev.deltaY > 0 ? 1.15 : 1 / 1.15, x, y);
  }, { passive: false });
  // Arrastrar (ratón o un dedo) mueve el mapa; dos dedos hacen zoom (pellizco).
  const dedos = new Map();
  let arrastre = null, pellizco = null;
  const reiniciar = () => {
    const ps = [...dedos.values()];
    arrastre = ps.length === 1 ? { x: ps[0].clientX, y: ps[0].clientY, vb: { ...vb } } : null;
    pellizco = ps.length >= 2
      ? { d: Math.hypot(ps[0].clientX - ps[1].clientX, ps[0].clientY - ps[1].clientY) || 1 }
      : null;
  };
  svg.addEventListener("pointerdown", (ev) => {
    dedos.set(ev.pointerId, ev);
    svg.setPointerCapture(ev.pointerId);
    reiniciar();
  });
  svg.addEventListener("pointermove", (ev) => {
    if (!dedos.has(ev.pointerId)) return;
    dedos.set(ev.pointerId, ev);
    if (pellizco) {
      const [a, b] = [...dedos.values()];
      const d = Math.hypot(a.clientX - b.clientX, a.clientY - b.clientY) || 1;
      const centro = { clientX: (a.clientX + b.clientX) / 2, clientY: (a.clientY + b.clientY) / 2 };
      const [x, y] = punto(centro);
      zoom(pellizco.d / d, x, y);
      pellizco.d = d;
    } else if (arrastre) {
      const s = punto(ev)[2];
      vb.x = arrastre.vb.x - (ev.clientX - arrastre.x) * s;
      vb.y = arrastre.vb.y - (ev.clientY - arrastre.y) * s;
      aplicar();
    }
  });
  const soltar = (ev) => { dedos.delete(ev.pointerId); reiniciar(); };
  svg.addEventListener("pointerup", soltar);
  svg.addEventListener("pointercancel", soltar);
  return { svg, capas, animales, bellotas, zoom, ajustar, el, P };
}

// Tooltip simple para cualquier elemento con data-tip.
(function () {
  const tip = document.createElement("div");
  tip.className = "tooltip";
  document.addEventListener("DOMContentLoaded", () => document.body.appendChild(tip));
  // pointermove (ratón) y pointerdown (tocar en el celular, donde no hay "hover").
  const mostrar = (ev) => {
    const t = ev.target.closest ? ev.target.closest("[data-tip]") : null;
    if (!t) { tip.style.opacity = 0; return; }
    tip.textContent = t.dataset.tip;
    tip.style.opacity = 1;
    tip.style.left = Math.min(window.innerWidth - tip.offsetWidth - 12, ev.clientX + 14) + "px";
    tip.style.top = (ev.clientY + 16) + "px";
  };
  document.addEventListener("pointermove", mostrar);
  document.addEventListener("pointerdown", mostrar);
})();
