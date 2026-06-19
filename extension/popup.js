const content = document.getElementById("content");
const API = window.SCICHECK_API_BASE;
const DOI_RE = /10\.\d{4,9}\/[^\s"'<>?#]+/;

// Injected into the active tab to find a DOI on the page.
function detectDoiInPage() {
  const re = /10\.\d{4,9}\/[^\s"'<>?#]+/;
  const metaSel = 'meta[name="citation_doi"], meta[name="dc.identifier"], meta[name="DC.Identifier"], meta[name="prism.doi"]';
  for (const m of document.querySelectorAll(metaSel)) {
    const hit = (m.content || "").match(re);
    if (hit) return hit[0];
  }
  const link = document.querySelector('a[href*="doi.org/10."]');
  if (link) { const hit = link.href.match(re); if (hit) return hit[0]; }
  const url = location.href.match(re);
  if (url) return url[0];
  const text = (document.body && document.body.innerText || "").match(re);
  return text ? text[0] : null;
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
}

function render(data) {
  if (data.retracted) {
    content.innerHTML = `<p class="retracted">⚠ RETRACTED article</p>`;
  } else {
    content.innerHTML = "";
  }
  const grade = document.createElement("div");
  grade.className = "grade-row";
  grade.innerHTML = `
    <div class="grade ${data.color}">${data.grade}</div>
    <div><div class="score">${data.score}/100</div><div class="muted">${escapeHtml(data.summary || "")}</div></div>`;
  content.appendChild(grade);

  if (data.title) {
    const t = document.createElement("p");
    t.className = "title";
    t.textContent = data.title;
    content.appendChild(t);
  }

  const ul = document.createElement("ul");
  ul.className = "criteria";
  (data.criteria || []).forEach((c) => {
    const li = document.createElement("li");
    li.innerHTML = `<span>${escapeHtml(c.name)}</span><span>${escapeHtml(c.value || "")}<span class="dot ${c.color}"></span></span>`;
    ul.appendChild(li);
  });
  content.appendChild(ul);

  const link = document.createElement("a");
  link.className = "btn";
  link.href = data.url;
  link.target = "_blank";
  link.textContent = "Full analysis →";
  content.appendChild(link);
}

function message(html) { content.innerHTML = html; }

async function query(doi, attempt = 0) {
  try {
    const res = await fetch(`${API}/api/v1/analysis?doi=${encodeURIComponent(doi)}`, {
      headers: { Accept: "application/json" }
    });
    if (res.status === 422) return message('<p class="muted">No valid DOI found on this page.</p>');
    if (res.status === 404) return message('<p class="muted">This article was not found in our sources.</p>');
    const data = await res.json();
    if (data.state === "ready") return render(data);
    if (data.state === "pending" && attempt < 30) {
      message('<p class="muted">Analyzing this paper…</p>');
      return setTimeout(() => query(doi, attempt + 1), 2000);
    }
    message('<p class="muted">Still working — open the full analysis.</p>');
  } catch (_) {
    message(`<p class="muted">Could not reach SciCheck at ${escapeHtml(API)}.</p>`);
  }
}

async function start() {
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    const [{ result: doi } = {}] = await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      func: detectDoiInPage
    });
    if (doi && DOI_RE.test(doi)) {
      message('<p class="muted">Analyzing this paper…</p>');
      query(doi);
    } else {
      message('<p class="muted">No DOI detected on this page. Open an article page (PubMed, a journal, doi.org…).</p>');
    }
  } catch (_) {
    message('<p class="muted">Could not read this page.</p>');
  }
}

start();
