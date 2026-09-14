(() => {
  const APPS = {
    Notes: `<svg width="12" height="12" viewBox="0 0 12 12"><rect x="1" y="1" width="10" height="10" rx="2.4" fill="#fff"/><rect x="1" y="1" width="10" height="3.4" rx="2.4" fill="#e8c548"/><line x1="3" y1="6.4" x2="9" y2="6.4" stroke="#c9c4b2" stroke-width="1"/><line x1="3" y1="8.6" x2="7.4" y2="8.6" stroke="#c9c4b2" stroke-width="1"/></svg>`,
    Ghostty: `<svg width="12" height="12" viewBox="0 0 12 12"><path d="M6 1 a4.2 4.2 0 0 1 4.2 4.2 V10.6 l-1.4 -1 -1.4 1 -1.4 -1 -1.4 1 -1.4 -1 -1.4 1 V5.2 A4.2 4.2 0 0 1 6 1z" fill="#4c9ee8"/><circle cx="4.5" cy="5.2" r=".9" fill="#0b1420"/><circle cx="7.5" cy="5.2" r=".9" fill="#0b1420"/></svg>`,
    Figma: `<svg width="12" height="12" viewBox="0 0 12 12"><circle cx="7.6" cy="6" r="2.1" fill="#1abcfe"/><path d="M3.4 1.5 h2.4 v4.2 H3.4 a2.1 2.1 0 0 1 0 -4.2z" fill="#f24e1e"/><path d="M3.4 5.9 h2.4 v4.2 H3.4 a2.1 2.1 0 0 1 0 -4.2z" fill="#a259ff"/></svg>`,
    Safari: `<svg width="12" height="12" viewBox="0 0 12 12"><circle cx="6" cy="6" r="5" fill="#1f8fff"/><path d="M8.6 3.4 L6.8 6.8 3.4 8.6 5.2 5.2z" fill="#fff"/><path d="M8.6 3.4 L5.2 5.2 6.8 6.8z" fill="#ff5b45"/></svg>`,
    Slack: `<svg width="12" height="12" viewBox="0 0 12 12"><rect x="5" y="1" width="2" height="4.4" rx="1" fill="#36c5f0"/><rect x="5" y="6.6" width="2" height="4.4" rx="1" fill="#2eb67d"/><rect x="1" y="5" width="4.4" height="2" rx="1" fill="#e01e5a"/><rect x="6.6" y="5" width="4.4" height="2" rx="1" fill="#ecb22e"/></svg>`,
    Finder: `<svg width="12" height="12" viewBox="0 0 12 12"><rect x="1" y="1" width="10" height="10" rx="2.6" fill="#59b0f2"/><path d="M6.6 1 a14 14 0 0 0 -1 5 a14 14 0 0 0 1 5" fill="none" stroke="#1e5f96" stroke-width=".9"/><circle cx="3.8" cy="5" r=".8" fill="#0b1c2b"/><circle cx="8.6" cy="5" r=".8" fill="#0b1c2b"/><path d="M3.4 8 q2.6 1.6 5.2 0" fill="none" stroke="#0b1c2b" stroke-width=".9" stroke-linecap="round"/></svg>`,
    Arc: `<svg width="12" height="12" viewBox="0 0 12 12"><defs><linearGradient id="arcg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ff5a78"/><stop offset="1" stop-color="#8b7bff"/></linearGradient></defs><rect x=".5" y=".5" width="11" height="11" rx="2.8" fill="#fdeef2"/><path d="M3.1 9.1 V7.3 a2.9 2.9 0 0 1 5.8 0 V9.1" fill="none" stroke="url(#arcg)" stroke-width="1.9" stroke-linecap="round"/></svg>`,
  };
  const ICONS = {
    text: `<svg width="11" height="11" viewBox="0 0 12 12"><g stroke="currentColor" stroke-width="1.6" stroke-linecap="round"><line x1="1" y1="2.5" x2="11" y2="2.5"/><line x1="1" y1="6" x2="8" y2="6"/><line x1="1" y1="9.5" x2="10" y2="9.5"/></g></svg>`,
    code: `<img src="media/nvim.png" width="12" height="12" alt="">`,
    color: `<span class="dot" style="background:conic-gradient(#f66,#fc6,#7d6,#6cc,#66f,#c6c,#f66)"></span>`,
    link: `<svg width="11" height="11" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"><path d="M4.5 7.5 L7.5 4.5"/><path d="M5.2 3.2 L6.5 2 a2.2 2.2 0 0 1 3.4 3.4 L8.8 6.8"/><path d="M6.8 8.8 L5.5 10 a2.2 2.2 0 0 1 -3.4 -3.4 L3.2 5.2"/></svg>`,
    files: `<svg width="11" height="11" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.4"><path d="M1.5 3.2 a1 1 0 0 1 1 -1 h2.3 l1.2 1.4 h4 a1 1 0 0 1 1 1 V9 a1 1 0 0 1 -1 1 h-7.5 a1 1 0 0 1 -1 -1 z"/></svg>`,
  };
  const ITEMS = [
    { app: "Arc",     kind: "text",  text: "Your clipboard, remembered.", time: "now" },
    { app: "Ghostty", kind: "code",  text: "git rebase -i origin/main", time: "1m" },
    { app: "Figma",   kind: "color", text: "#FF6B35", time: "3m" },
    { app: "Notes",   kind: "text",  text: "Meet at 9:30 tomorrow — bring the design brief.", time: "8m" },
    { app: "Safari",  kind: "link",  text: "github.com/nathan-poncet/whisk", time: "12m" },
    { app: "Ghostty", kind: "code",  text: "func greet() -> String { \"hi\" }", time: "15m" },
    { app: "Slack",   kind: "text",  text: "plain words about the launch", time: "22m" },
    { app: "Figma",   kind: "color", text: "hsl(150, 45%, 62%)", time: "30m" },
    { app: "Finder",  kind: "files", text: "report.pdf · budget.numbers", time: "41m" },
    { app: "Arc",     kind: "link",  text: "nathan-poncet.github.io/whisk", time: "1h" },
  ];
  const swatch = (t) => {
    if (t.startsWith("#")) return t;
    const m = t.match(/hsl\(([^)]*)\)/); return m ? `hsl(${m[1]})` : "#7fd8a4";
  };
  const state = { q: "", apps: new Set(), kinds: new Set(), sel: 0 };
  const el = (id) => document.getElementById(id);
  const matches = (item) => {
    if (state.apps.size && !state.apps.has(item.app)) return false;
    if (state.kinds.size && !state.kinds.has(item.kind)) return false;
    return state.q.toLowerCase().split(/\s+/).filter(Boolean).every((w) => {
      if (w.startsWith("app:")) return item.app.toLowerCase().includes(w.slice(4));
      if (w.startsWith("type:")) return item.kind.startsWith(w.slice(5));
      return item.text.toLowerCase().includes(w) || item.app.toLowerCase().includes(w);
    });
  };
  const render = () => {
    const found = ITEMS.filter(matches);
    state.sel = Math.min(state.sel, Math.max(0, found.length - 1));
    // Facets narrow each other, but an active chip is never hidden.
    const inAppScope = ITEMS.filter((i) => !state.apps.size || state.apps.has(i.app));
    const kindsAvail = [...new Set(inAppScope.map((i) => i.kind))];
    state.kinds.forEach((k) => { if (!kindsAvail.includes(k)) kindsAvail.push(k); });
    const inKindScope = ITEMS.filter((i) => !state.kinds.size || state.kinds.has(i.kind));
    const appsAvail = new Set(inKindScope.map((i) => i.app));
    state.apps.forEach((a) => appsAvail.add(a));
    el("try-chips").innerHTML =
      Object.keys(APPS).filter((a) => appsAvail.has(a)).map((a) =>
        `<button type="button" class="chip ${state.apps.has(a) ? "active" : ""}" data-app="${a}" aria-pressed="${state.apps.has(a)}">` +
        `${APPS[a]}${a}</button>`).join("") +
      `<span style="width:1px;background:rgba(255,255,255,.25);margin:2px 3px"></span>` +
      kindsAvail.map((k) =>
        `<button type="button" class="chip ${state.kinds.has(k) ? "active" : ""}" data-kind="${k}" aria-pressed="${state.kinds.has(k)}">${ICONS[k] || ""}${k}</button>`).join("");
    el("try-rail").innerHTML = found.map((i, n) => {
      const body = i.kind === "color"
        ? `<div class="swatch" style="background:${swatch(i.text)}"></div><div class="body mono">${i.text}</div>`
        : `<div class="body ${i.kind === "code" ? "mono" : ""}">${i.text}</div>`;
      return `<div class="tcard ${n === state.sel ? "selected" : ""}" data-n="${n}" role="button" tabindex="0" aria-label="Paste ${i.kind} from ${i.app}: ${i.text.replaceAll('"', '&quot;')}">` +
        `<div class="head">${APPS[i.app]}${i.app}</div>` +
        body + `<div class="foot"><span>${i.time}</span><span>${i.kind}</span></div></div>`;
    }).join("") || `<div style="color:var(--muted);font-size:13px;padding:30px 60px">No matches</div>`;
    el("try-count").textContent = `${found.length} item${found.length === 1 ? "" : "s"}`;
  };
  const paste = () => {
    const found = ITEMS.filter(matches);
    const item = found[state.sel];
    if (!item) return;
    el("note-text").textContent += (el("note-text").textContent ? " " : "") + item.text;
  };
  const clearNote = () => { el("note-text").textContent = ""; };
  el("note-clear").addEventListener("click", (e) => { clearNote(); e.stopPropagation(); });
  el("try-input").addEventListener("input", (e) => { state.q = e.target.value; state.sel = 0; render(); });
  document.addEventListener("click", (e) => {
    const chip = e.target.closest(".chip");
    if (chip && chip.dataset.app) {
      state.apps.has(chip.dataset.app) ? state.apps.delete(chip.dataset.app) : state.apps.add(chip.dataset.app);
      state.sel = 0; render(); document.querySelector(`[data-app="${chip.dataset.app}"]`)?.focus({ preventScroll: true }); return;
    }
    if (chip && chip.dataset.kind) {
      state.kinds.has(chip.dataset.kind) ? state.kinds.delete(chip.dataset.kind) : state.kinds.add(chip.dataset.kind);
      state.sel = 0; render(); document.querySelector(`[data-kind="${chip.dataset.kind}"]`)?.focus({ preventScroll: true }); return;
    }
    const card = e.target.closest(".tcard");
    if (card) { state.sel = Number(card.dataset.n); render(); paste(); }
  });
  el("try-rail").addEventListener("keydown", (e) => {
    const card = e.target.closest(".tcard");
    if (!card) return;
    if (e.key === "Enter" || e.key === " ") { e.preventDefault(); state.sel = Number(card.dataset.n); paste(); }
    if (e.key === "ArrowRight" || e.key === "ArrowLeft") {
      e.preventDefault();
      const next = e.key === "ArrowRight" ? card.nextElementSibling : card.previousElementSibling;
      if (next) next.focus();
    }
  });
  el("copy-brew").addEventListener("click", async (e) => {
    const button = e.currentTarget;
    try {
      await navigator.clipboard.writeText(el("brew-cmd").textContent);
      button.textContent = "Copied!";
    } catch { button.textContent = "Select to copy"; const range = document.createRange(); range.selectNodeContents(el("brew-cmd")); const selection = getSelection(); selection.removeAllRanges(); selection.addRange(range); }
    setTimeout(() => { button.textContent = "Copy"; }, 1800);
  });
  render();

  // Live star count on the hero button; silence on any failure.
  fetch("https://api.github.com/repos/nathan-poncet/whisk")
    .then((r) => (r.ok ? r.json() : null))
    .then((repo) => {
      if (!repo || typeof repo.stargazers_count !== "number") return;
      const badge = el("gh-stars");
      badge.textContent = repo.stargazers_count.toLocaleString("en-US");
      badge.hidden = false;
    })
    .catch(() => {});

})();
