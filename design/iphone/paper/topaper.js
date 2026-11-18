// Written by AI on 2026.11.18 by model claude fable 5.2. See ../README.md.
// Turns a rendered element into flat, absolutely positioned HTML for Paper: text as text, drawings as SVG files.
(rootSelector, name, dir, index) => {
  const root = document.querySelectorAll(rootSelector)[index ?? 0];
  const R = root.getBoundingClientRect();
  const assets = [], out = [], art = [];
  const n = v => Math.round(v * 10) / 10;
  const family = f => /Rounded/.test(f) ? 'SF Pro Rounded' : 'SF Pro';
  const rel = r => ({ left: r.left - R.left, top: r.top - R.top, width: r.width, height: r.height });
  let serial = 0;
  const textNode = (label, string, r, cs, { anchor = 'start', nowrap = true } = {}) => {
    const size = parseFloat(cs.fontSize), lh = cs.lineHeight === 'normal' ? Math.round(size * 1.2) : parseFloat(cs.lineHeight);
    const ls = cs.letterSpacing === 'normal' ? 0 : parseFloat(cs.letterSpacing) / size;
    let pos;
    if (anchor === 'end') pos = `right:${n(R.width - (r.left + r.width))}px;text-align:right`;
    else if (anchor === 'middle') pos = `left:${n(r.left + r.width / 2 - 60)}px;width:120px;text-align:center`;
    else pos = `left:${n(r.left)}px` + (nowrap ? '' : `;width:${n(r.width + 1)}px`);
    const top = r.top + (r.height - Math.max(lh, 0)) / 2;
    out.push(`<div layer-name="${label}" style="position:absolute;${pos};top:${n(nowrap ? top : r.top)}px;font-family:'${family(cs.fontFamily)}';font-weight:${cs.fontWeight};font-size:${n(size)}px;line-height:${n(lh)}px;${ls ? `letter-spacing:${n(ls * 100) / 100}em;` : ''}color:${cs.color};${nowrap ? 'white-space:nowrap' : ''}">${string}</div>`);
  };
  const walk = el => {
    const cs = getComputedStyle(el);
    if (cs.display === 'none' || cs.visibility === 'hidden' || el.hidden) return;
    const r = rel(el.getBoundingClientRect());
    if (el !== root && (r.width === 0 || r.height === 0) && el.tagName !== 'svg') return;
    if (el.tagName === 'SELECT' || el.tagName === 'CANVAS') return;
    if (el.id === 'map') {
      out.push(`<img layer-name="Map with the rain" src="paper-asset://${dir}/${name}-map.png" style="position:absolute;left:${n(r.left)}px;top:${n(r.top)}px;width:${n(r.width)}px;height:${n(r.height)}px">`);
      for (const child of el.children) if (child.id === 'moment') walk(child);
      return;
    }
    if (el.tagName === 'svg') {
      const clone = el.cloneNode(true);
      const texts = [...el.querySelectorAll('text')];
      const isWord = t => root.id === 'phone' && /[A-Za-z]/.test(t.textContent);
      [...clone.querySelectorAll('text')].forEach((t, i) => { if (isWord(texts[i])) t.remove(); else { t.setAttribute('font-family', 'SF Pro'); } });
      const hidden = [...el.querySelectorAll('*')].map(node => getComputedStyle(node).display === 'none');
      const all = [...el.querySelectorAll('*')];
      [...clone.querySelectorAll('*')].forEach(node => { const k = node.getAttribute && node.id === 'marker' ? all.findIndex(a => a.id === 'marker') : -1; if (k >= 0 && hidden[k]) node.remove(); });
      const box = el.viewBox.baseVal;
      clone.setAttribute('x', n(r.left)); clone.setAttribute('y', n(r.top)); clone.setAttribute('width', n(r.width)); clone.setAttribute('height', n(r.height));
      if (!box.width) clone.setAttribute('viewBox', `0 0 ${r.width} ${r.height}`);
      clone.setAttribute('overflow', 'visible'); clone.removeAttribute('style'); clone.removeAttribute('class'); clone.removeAttribute('id');
      clone.setAttribute('color', cs.color);
      art.push(new XMLSerializer().serializeToString(clone).replace(/currentColor/g, cs.color).replace(/var\(--[^)]+\)/g, m => getComputedStyle(el).getPropertyValue(m.slice(4, -1)).trim() || '#fff'));
      for (const t of texts) if (isWord(t)) {
        const tr = rel(t.getBoundingClientRect()), tcs = getComputedStyle(t);
        textNode(t.textContent, t.textContent, tr, { fontSize: tcs.fontSize, lineHeight: 'normal', letterSpacing: 'normal', fontFamily: tcs.fontFamily, fontWeight: tcs.fontWeight, color: t.getAttribute('fill') || tcs.fill }, { anchor: t.getAttribute('text-anchor') || 'start' });
      }
      return;
    }
    const hasBox = el !== root && ((cs.backgroundColor !== 'rgba(0, 0, 0, 0)' && cs.backgroundColor !== 'transparent') || cs.backgroundImage !== 'none');
    if (hasBox) out.push(`<div layer-name="${el.getAttribute('aria-label') || el.className || 'Box'}" style="position:absolute;left:${n(r.left)}px;top:${n(r.top)}px;width:${n(r.width)}px;height:${n(r.height)}px;border-radius:${cs.borderTopLeftRadius};background:${cs.backgroundImage !== 'none' ? cs.backgroundImage : cs.backgroundColor}"></div>`);
    const own = [...el.childNodes].filter(c => c.nodeType === 3 && c.textContent.trim());
    if (own.length && ![...el.children].some(c => !['B', 'U', 'BR'].includes(c.tagName))) {
      const range = document.createRange(); range.selectNodeContents(el);
      const tr = rel(range.getBoundingClientRect());
      const lh = parseFloat(cs.lineHeight) || parseFloat(cs.fontSize) * 1.2;
      const multi = tr.height > lh * 1.6;
      const inner = el.innerHTML.replace(/<b>/g, '<span style="font-weight:600">').replace(/<\/b>/g, '</span>').replace(/<u>/g, '<span style="text-decoration:underline">').replace(/<\/u>/g, '</span>').trim();
      textNode(el.id || el.className || 'Text', inner, multi ? r : { ...tr, top: r.top, height: r.height }, cs, { nowrap: !multi });
      return;
    }
    for (const child of el.childNodes) {
      if (child.nodeType === 1) walk(child);
      else if (child.nodeType === 3 && child.textContent.trim()) {
        const range = document.createRange(); range.selectNode(child);
        textNode('Text', child.textContent.trim(), rel(range.getBoundingClientRect()), cs);
      }
    }
  };
  const rcs = getComputedStyle(root);
  for (const child of root.childNodes) if (child.nodeType === 1) walk(child);
  const bg = rcs.backgroundImage !== 'none' ? rcs.backgroundImage : rcs.backgroundColor;
  if (art.length) {
    assets.push({ file: `${name}-art.svg`, svg: `<svg xmlns="http://www.w3.org/2000/svg" width="${n(R.width)}" height="${n(R.height)}" viewBox="0 0 ${n(R.width)} ${n(R.height)}">${art.join('')}</svg>` });
    out.push(`<img layer-name="Drawings" src="paper-asset://${dir}/${name}-art.svg" style="position:absolute;left:0;top:0;width:${n(R.width)}px;height:${n(R.height)}px">`);
  }
  const html = `<div layer-name="${name}" style="position:relative;width:${n(R.width)}px;height:${n(R.height)}px;border-radius:${rcs.borderTopLeftRadius} ${rcs.borderTopRightRadius} ${rcs.borderBottomRightRadius} ${rcs.borderBottomLeftRadius};overflow:hidden;background:${bg};flex-shrink:0">${out.join('')}</div>`;
  return { html, assets };
}
