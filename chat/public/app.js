/* TruERP Chat frontend — plain JS, SSE streaming, localStorage persistence. */

const LS = {
  provider: "tc.provider",
  model: "tc.model",
  keys: "tc.keys",
  baseUrl: "tc.baseUrl",
  system: "tc.system",
  messages: "tc.messages",
  tools: "tc.tools",
};

const $ = (id) => document.getElementById(id);

const state = {
  providers: [],
  provider: localStorage.getItem(LS.provider) || "gemini",
  model: localStorage.getItem(LS.model) || "",
  keys: JSON.parse(localStorage.getItem(LS.keys) || "{}"),
  baseUrl: localStorage.getItem(LS.baseUrl) || "",
  system: localStorage.getItem(LS.system) || "",
  messages: JSON.parse(localStorage.getItem(LS.messages) || "[]"),
  enabledTools: JSON.parse(localStorage.getItem(LS.tools) || "null"), // null = all
  allTools: null,
  sending: false,
  abort: null,
};

/* ---------- tiny markdown renderer ---------- */
function esc(s) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}
function inline(s) {
  return s
    .replace(/`([^`]+)`/g, (_, c) => `<code>${c}</code>`)
    .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
    .replace(/\*([^*\n]+)\*/g, "<em>$1</em>")
    .replace(/\[([^\]]+)\]\((https?:[^)\s]+)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>');
}
function md(src) {
  const blocks = [];
  let text = esc(src).replace(/```(\w*)\n?([\s\S]*?)```/g, (_, lang, code) => {
    blocks.push(`<pre><code>${code.replace(/\n$/, "")}</code></pre>`);
    return `@@TCB_${blocks.length - 1}@@`;
  });

  const lines = text.split("\n");
  const out = [];
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    // pipe table
    if (/^\s*\|.*\|\s*$/.test(line) && /^\s*\|[\s:|-]+\|\s*$/.test(lines[i + 1] || "")) {
      const rows = [];
      const header = line.split("|").slice(1, -1).map((c) => c.trim());
      i += 2;
      while (i < lines.length && /^\s*\|.*\|\s*$/.test(lines[i])) {
        rows.push(lines[i].split("|").slice(1, -1).map((c) => c.trim()));
        i++;
      }
      out.push(
        `<table><thead><tr>${header.map((c) => `<th>${inline(c)}</th>`).join("")}</tr></thead>` +
          `<tbody>${rows.map((r) => `<tr>${r.map((c) => `<td>${inline(c)}</td>`).join("")}</tr>`).join("")}</tbody></table>`,
      );
      continue;
    }
    // unordered list
    if (/^\s*[-*]\s+/.test(line)) {
      const items = [];
      while (i < lines.length && /^\s*[-*]\s+/.test(lines[i])) {
        items.push(lines[i].replace(/^\s*[-*]\s+/, ""));
        i++;
      }
      out.push(`<ul>${items.map((it) => `<li>${inline(it)}</li>`).join("")}</ul>`);
      continue;
    }
    // ordered list
    if (/^\s*\d+[.)]\s+/.test(line)) {
      const items = [];
      while (i < lines.length && /^\s*\d+[.)]\s+/.test(lines[i])) {
        items.push(lines[i].replace(/^\s*\d+[.)]\s+/, ""));
        i++;
      }
      out.push(`<ol>${items.map((it) => `<li>${inline(it)}</li>`).join("")}</ol>`);
      continue;
    }
    // heading
    const h = line.match(/^(#{1,4})\s+(.*)$/);
    if (h) {
      const lvl = Math.min(h[1].length + 2, 6);
      out.push(`<h${lvl}>${inline(h[2])}</h${lvl}>`);
      i++;
      continue;
    }
    // code-block placeholder — emit raw
    if (/^@@TCB_\d+@@\s*$/.test(line)) {
      out.push(line);
      i++;
      continue;
    }
    out.push(line.trim() === "" ? "" : `<p>${inline(line)}</p>`);
    i++;
  }
  return out.join("\n").replace(/@@TCB_(\d+)@@/g, (_, n) => blocks[Number(n)] ?? "");
}

/* ---------- rendering ---------- */
const transcript = $("transcript");

function scrollBottom() {
  transcript.scrollTop = transcript.scrollHeight;
}

function el(tag, cls, html) {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (html !== undefined) e.innerHTML = html;
  return e;
}

function fmtCell(v) {
  if (v === null || v === undefined) return "";
  if (typeof v === "object") return JSON.stringify(v).slice(0, 120);
  return String(v);
}

/** Render a tool result: flat objects → key/value table, arrays of objects → table, else pretty JSON. */
function toolResultHtml(raw) {
  if (!raw) return "<pre>(empty)</pre>";
  let data;
  try {
    data = JSON.parse(raw);
  } catch {
    return `<pre>${esc(raw)}</pre>`;
  }
  if (data === null || typeof data !== "object") return `<pre>${esc(fmtCell(data))}</pre>`;
  if (Array.isArray(data)) {
    if (data.length && data.every((x) => x && typeof x === "object" && !Array.isArray(x))) {
      const keys = [...new Set(data.flatMap((o) => Object.keys(o)))].slice(0, 12);
      const rows = data.slice(0, 50);
      const more = data.length > 50 ? `<div class="t-more">… ${data.length - 50} more rows</div>` : "";
      return (
        `<table><thead><tr>${keys.map((k) => `<th>${esc(k)}</th>`).join("")}</tr></thead>` +
        `<tbody>${rows.map((o) => `<tr>${keys.map((k) => `<td>${esc(fmtCell(o[k]))}</td>`).join("")}</tr>`).join("")}</tbody></table>${more}`
      );
    }
    return `<pre>${esc(JSON.stringify(data, null, 2))}</pre>`;
  }
  const rows = Object.entries(data)
    .map(([k, v]) => `<tr><td>${esc(k)}</td><td>${esc(fmtCell(v))}</td></tr>`)
    .join("");
  return `<table class="kv"><tbody>${rows}</tbody></table>`;
}

function toolCard(call, result, isError) {
  const card = el("details", "tool-card" + (isError ? " err" : ""));
  const summary = el("summary", "", `<span class="tool-name">${esc(call.name)}</span>`);
  summary.appendChild(el("span", "", esc(JSON.stringify(call.args || {})).slice(0, 120)));
  card.appendChild(summary);
  const body = el("div", "tool-body");
  body.innerHTML = result === undefined || result === null ? "<pre>(running…)</pre>" : toolResultHtml(result);
  card.appendChild(body);
  return card;
}

function renderAll() {
  transcript.innerHTML = "";
  const toolResults = new Map();
  for (const m of state.messages) {
    if (m.role === "tool") toolResults.set(m.toolCallId, m);
  }
  for (const m of state.messages) {
    if (m.role === "user") {
      transcript.appendChild(el("div", "msg user", esc(m.content)));
    } else if (m.role === "error") {
      transcript.appendChild(el("div", "msg error", esc(m.content)));
    } else if (m.role === "assistant") {
      const wrap = el("div", "msg assistant");
      if (m.content) wrap.appendChild(el("div", "md", md(m.content)));
      if (!m.content && !(m.toolCalls || []).length)
        wrap.appendChild(el("div", "empty", "(empty response)"));
      for (const c of m.toolCalls || []) {
        const res = toolResults.get(c.id);
        wrap.appendChild(toolCard(c, res?.content, res && /^(Error|error)/.test(res.content)));
      }
      transcript.appendChild(wrap);
    }
  }
  scrollBottom();
}

/* ---------- config panel ---------- */
async function loadProviders() {
  const res = await fetch("/api/providers");
  state.providers = await res.json();
  const sel = $("provider");
  sel.innerHTML = "";
  for (const p of state.providers) {
    const o = el("option", "", esc(p.label));
    o.value = p.id;
    sel.appendChild(o);
  }
  if (!state.providers.some((p) => p.id === state.provider)) {
    state.provider = state.providers[0]?.id || "gemini";
  }
  sel.value = state.provider;
  syncProviderUI();
}

function currentProvider() {
  return state.providers.find((p) => p.id === state.provider);
}

function syncProviderUI() {
  const p = currentProvider();
  $("apikey-field").classList.toggle("hidden", !p?.needsKey);
  $("baseurl-field").classList.toggle("hidden", state.provider !== "ollama");
  $("apikey").value = state.keys[state.provider] || "";
  $("apikey-env").textContent = p?.envKey && !state.keys[state.provider] ? `(or set ${p.envKey})` : "";
  if (state.provider === "ollama" && state.baseUrl) $("baseurl").value = state.baseUrl;
  refreshModels();
}

const CUSTOM_MODEL = "__custom__";

function effectiveModel() {
  const sel = $("model");
  if (sel.value === CUSTOM_MODEL) return $("model-custom").value.trim();
  return sel.value;
}

function populateModelSelect(models) {
  const sel = $("model");
  const p = currentProvider();
  const wanted = state.model || p?.defaultModel || "";
  sel.innerHTML = "";
  for (const m of models) {
    const o = el("option", "", esc(m.label && m.label !== m.id ? `${m.id} — ${m.label}` : m.id));
    o.value = m.id;
    sel.appendChild(o);
  }
  const custom = el("option", "", "Custom…");
  custom.value = CUSTOM_MODEL;
  sel.appendChild(custom);

  const listed = models.some((m) => m.id === wanted);
  if (wanted && listed) {
    sel.value = wanted;
    $("model-custom").classList.add("hidden");
  } else if (models.length && !wanted) {
    const dflt = p?.defaultModel;
    sel.value = dflt && models.some((m) => m.id === dflt) ? dflt : models[0].id;
    $("model-custom").classList.add("hidden");
  } else {
    // wanted model not in the live list (or list empty) → free-text entry
    sel.value = CUSTOM_MODEL;
    $("model-custom").classList.remove("hidden");
    $("model-custom").value = wanted === CUSTOM_MODEL ? "" : wanted;
  }
}

let modelFetchTimer;
function refreshModels() {
  clearTimeout(modelFetchTimer);
  modelFetchTimer = setTimeout(async () => {
    if (!currentProvider()) return;
    try {
      const q = state.provider === "ollama" && $("baseurl").value
        ? `?provider=${state.provider}&baseUrl=${encodeURIComponent($("baseurl").value.replace(/\/+$/, "") + "/v1")}`
        : `?provider=${state.provider}`;
      const res = await fetch(`/api/models${q}`, {
        headers: { "x-api-key": state.keys[state.provider] || "" },
      });
      populateModelSelect(res.ok ? await res.json() : []);
    } catch {
      populateModelSelect([]);
    }
  }, 300);
}

async function checkHealth() {
  const dot = $("mcp-status");
  try {
    const res = await fetch("/api/health");
    const data = await res.json();
    if (data.ok) {
      dot.className = "status-dot ok";
      dot.title = `MCP connected — ${data.toolCount} tools`;
      $("tools-count").textContent = `all ${data.toolCount}`;
    } else {
      dot.className = "status-dot err";
      dot.title = data.error || "MCP error";
    }
  } catch (e) {
    dot.className = "status-dot err";
    dot.title = String(e);
  }
}

/* ---------- tools panel ---------- */
async function openToolsPanel() {
  $("tools-panel").classList.remove("hidden");
  if (!state.allTools) {
    try {
      const res = await fetch("/api/tools");
      state.allTools = res.ok ? await res.json() : [];
    } catch {
      state.allTools = [];
    }
  }
  renderToolsList();
  updateToolsCount();
}

function renderToolsList() {
  const q = ($("tools-search").value || "").toLowerCase();
  const list = $("tools-list");
  list.innerHTML = "";
  const enabled = state.enabledTools ? new Set(state.enabledTools) : null;
  for (const t of state.allTools || []) {
    if (q && !t.name.toLowerCase().includes(q) && !(t.description || "").toLowerCase().includes(q))
      continue;
    const row = el("label", "tool-row");
    const cb = el("input");
    cb.type = "checkbox";
    cb.checked = enabled ? enabled.has(t.name) : true;
    cb.onchange = () => {
      if (state.enabledTools === null) {
        state.enabledTools = (state.allTools || []).map((x) => x.name);
        if (!cb.checked) state.enabledTools = state.enabledTools.filter((n) => n !== t.name);
      } else if (cb.checked) {
        state.enabledTools.push(t.name);
      } else {
        state.enabledTools = state.enabledTools.filter((n) => n !== t.name);
      }
      localStorage.setItem(LS.tools, JSON.stringify(state.enabledTools));
      updateToolsCount();
    };
    row.appendChild(cb);
    const txt = el("div");
    txt.appendChild(el("div", "t-name", esc(t.name)));
    if (t.description) txt.appendChild(el("div", "t-desc", esc(t.description.slice(0, 140))));
    row.appendChild(txt);
    list.appendChild(row);
  }
}

function updateToolsCount() {
  const total = state.allTools?.length ?? 0;
  $("tools-count").textContent =
    state.enabledTools === null ? `all ${total}` : `${state.enabledTools.length}/${total}`;
}

/* ---------- sending ---------- */
function setSending(v) {
  state.sending = v;
  $("send").classList.toggle("hidden", v);
  $("stop").classList.toggle("hidden", !v);
  $("input").disabled = v;
}

function persistMessages() {
  localStorage.setItem(LS.messages, JSON.stringify(state.messages));
}

async function send() {
  const text = $("input").value.trim();
  if (!text || state.sending) return;
  const p = currentProvider();
  const model = effectiveModel() || p?.defaultModel;
  state.model = model;
  localStorage.setItem(LS.model, model);

  const userMsg = { role: "user", content: text };
  state.messages.push(userMsg);
  transcript.appendChild(el("div", "msg user", esc(text)));
  $("input").value = "";
  scrollBottom();
  setSending(true);

  let pendingEl = null;
  const showPending = () => {
    if (pendingEl) return;
    pendingEl = el("div", "msg assistant pending", '<span class="spinner"></span> thinking…');
    transcript.appendChild(pendingEl);
    scrollBottom();
  };
  const dropPending = () => {
    pendingEl?.remove();
    pendingEl = null;
  };
  showPending();

  const ctrl = new AbortController();
  state.abort = ctrl;

  let assistantEl = null;
  let assistantText = "";
  const liveCards = new Map();

  const newAssistantBubble = () => {
    assistantEl = el("div", "msg assistant");
    assistantEl._md = el("div", "md", "");
    assistantEl.appendChild(assistantEl._md);
    transcript.appendChild(assistantEl);
    assistantText = "";
  };

  try {
    const res = await fetch("/api/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      signal: ctrl.signal,
      body: JSON.stringify({
        provider: state.provider,
        model,
        apiKey: state.keys[state.provider] || undefined,
        baseUrl:
          state.provider === "ollama" && $("baseurl").value
            ? $("baseurl").value.replace(/\/+$/, "") + "/v1"
            : undefined,
        system: $("system").value || undefined,
        // Exclude display-only error markers from the provider payload.
        messages: state.messages.filter((m) => m.role !== "error"),
        tools: state.enabledTools ?? undefined,
      }),
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({ error: res.statusText }));
      throw new Error(err.error || res.statusText);
    }

    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let buf = "";

    const handle = (ev) => {
      switch (ev.type) {
        case "append":
          // assistant/tool transcript message — keep pending up between turns
          state.messages.push(ev.message);
          break;
        case "token":
          dropPending();
          if (!assistantEl) newAssistantBubble();
          assistantText += ev.text;
          assistantEl._md.innerHTML = md(assistantText);
          scrollBottom();
          break;
        case "tool_call": {
          dropPending();
          assistantEl = null; // next token starts a fresh bubble
          const card = toolCard({ name: ev.name, args: ev.args }, null);
          card.open = true;
          liveCards.set(ev.id, card);
          transcript.appendChild(card);
          scrollBottom();
          break;
        }
        case "tool_result": {
          const card = liveCards.get(ev.id);
          if (card) {
            card.querySelector(".tool-body").innerHTML = toolResultHtml(ev.preview || "");
            card.open = false;
            if (ev.isError) card.classList.add("err");
          }
          showPending(); // waiting for the model's follow-up reply
          scrollBottom();
          break;
        }
        case "error":
          dropPending();
          state.messages.push({ role: "error", content: ev.error });
          transcript.appendChild(el("div", "msg error", esc(ev.error)));
          scrollBottom();
          break;
        case "done":
          dropPending();
          break;
      }
    };

    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      buf += decoder.decode(value, { stream: true });
      const parts = buf.split("\n\n");
      buf = parts.pop() || "";
      for (const part of parts) {
        const line = part.trim();
        if (!line.startsWith("data:")) continue;
        try {
          handle(JSON.parse(line.slice(5)));
        } catch {
          /* ignore malformed event */
        }
      }
    }
  } catch (e) {
    dropPending();
    if (e.name !== "AbortError") {
      const errText = String(e.message || e);
      state.messages.push({ role: "error", content: errText });
      transcript.appendChild(el("div", "msg error", esc(errText)));
    }
  } finally {
    dropPending();
    setSending(false);
    persistMessages();
    renderAll();
  }
}

/* ---------- wiring ---------- */
$("composer").addEventListener("submit", (e) => {
  e.preventDefault();
  send();
});
$("input").addEventListener("keydown", (e) => {
  if (e.key === "Enter" && !e.shiftKey) {
    e.preventDefault();
    send();
  }
});
$("stop").addEventListener("click", () => state.abort?.abort());
$("provider").addEventListener("change", (e) => {
  state.provider = e.target.value;
  localStorage.setItem(LS.provider, state.provider);
  state.model = "";
  localStorage.removeItem(LS.model);
  $("model-custom").value = "";
  syncProviderUI();
});
$("apikey").addEventListener("input", (e) => {
  state.keys[state.provider] = e.target.value.trim();
  localStorage.setItem(LS.keys, JSON.stringify(state.keys));
  refreshModels();
});
$("baseurl").addEventListener("input", (e) => {
  state.baseUrl = e.target.value.trim();
  localStorage.setItem(LS.baseUrl, state.baseUrl);
  refreshModels();
});
$("model").addEventListener("change", (e) => {
  const custom = e.target.value === CUSTOM_MODEL;
  $("model-custom").classList.toggle("hidden", !custom);
  if (!custom) {
    state.model = e.target.value;
    localStorage.setItem(LS.model, state.model);
  }
});
$("model-custom").addEventListener("change", (e) => {
  state.model = e.target.value.trim();
  localStorage.setItem(LS.model, state.model);
});
$("system").addEventListener("input", (e) => {
  state.system = e.target.value;
  localStorage.setItem(LS.system, state.system);
});
$("new-chat").addEventListener("click", () => {
  state.messages = [];
  persistMessages();
  renderAll();
});
$("tools-btn").addEventListener("click", openToolsPanel);
$("tools-close").addEventListener("click", () => $("tools-panel").classList.add("hidden"));
$("tools-search").addEventListener("input", renderToolsList);
$("tools-all").addEventListener("click", () => {
  state.enabledTools = null;
  localStorage.setItem(LS.tools, "null");
  renderToolsList();
  updateToolsCount();
});
$("tools-none").addEventListener("click", () => {
  state.enabledTools = [];
  localStorage.setItem(LS.tools, "[]");
  renderToolsList();
  updateToolsCount();
});

$("system").value = state.system;
if (state.baseUrl) $("baseurl").value = state.baseUrl;

loadProviders().then(checkHealth);
renderAll();
setInterval(checkHealth, 30_000);
