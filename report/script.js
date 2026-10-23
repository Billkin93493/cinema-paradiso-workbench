const reportParams = new URLSearchParams(window.location.search);
const reportDocument = document.querySelector("#report-document");
let hasPrinted = false;

function decodeReportData(encoded) {
  if (!encoded) return null;
  const normalized = encoded
    .replaceAll("-", "+")
    .replaceAll("_", "/")
    .padEnd(Math.ceil(encoded.length / 4) * 4, "=");
  const binary = atob(normalized);
  const bytes = Uint8Array.from(binary, (character) => character.charCodeAt(0));
  return JSON.parse(new TextDecoder().decode(bytes));
}

function formatTimecode(totalSeconds) {
  const safeSeconds = Number.isFinite(Number(totalSeconds)) ? Math.max(0, Number(totalSeconds)) : 0;
  const hours = Math.floor(safeSeconds / 3600);
  const minutes = Math.floor((safeSeconds % 3600) / 60);
  const seconds = Math.floor(safeSeconds % 60);
  const frames = Math.min(24, Math.floor((safeSeconds % 1) * 25));
  return [hours, minutes, seconds, frames]
    .map((value) => String(value).padStart(2, "0"))
    .join(":");
}

function formatDuration(totalSeconds) {
  const safeSeconds = Math.max(0, Number(totalSeconds) || 0);
  if (safeSeconds >= 3600) {
    const hours = Math.floor(safeSeconds / 3600);
    const minutes = Math.floor((safeSeconds % 3600) / 60);
    return `${hours} 小时 ${minutes} 分钟`;
  }
  if (safeSeconds >= 60) return `${Math.floor(safeSeconds / 60)} 分钟`;
  return `${safeSeconds.toFixed(1)} 秒`;
}

function mostCommon(shots, field, fallback) {
  const counts = new Map();
  shots.forEach((shot) => {
    const value = shot[field] || fallback;
    counts.set(value, (counts.get(value) || 0) + 1);
  });
  return [...counts.entries()].sort((a, b) => b[1] - a[1])[0] || [fallback, 0];
}

function pageFooter(title, number) {
  const footer = document.createElement("footer");
  footer.className = "page-footer";
  const name = document.createElement("span");
  name.textContent = title;
  const index = document.createElement("span");
  index.textContent = String(number).padStart(2, "0");
  footer.append(name, index);
  return footer;
}

function createImage(imageUrl, alt) {
  if (!imageUrl) {
    const empty = document.createElement("div");
    empty.className = "report-image-empty";
    empty.innerHTML = "<span>◇</span><small>暂无代表静帧</small>";
    return empty;
  }
  const image = document.createElement("img");
  image.src = imageUrl;
  image.alt = alt;
  return image;
}

function createCover(data, pageNumber) {
  const page = document.createElement("section");
  page.className = "report-page cover-page";
  page.dataset.pageKey = "cover";
  page.dataset.pageName = "封面";
  page.innerHTML = '<div class="aurora aurora-a"></div><div class="aurora aurora-b"></div>';

  const coverImage = document.createElement("div");
  coverImage.className = "cover-image";
  coverImage.append(createImage(data.coverImageUrl, `《${data.project.name}》报告封面`));
  const imageLabel = document.createElement("span");
  imageLabel.textContent = data.coverImageUrl
    ? (data.coverImageSource === "archive" ? "导演资料库收藏静帧" : "自动代表静帧")
    : "当前影片暂无代表静帧";
  coverImage.append(imageLabel);

  const copy = document.createElement("div");
  copy.className = "cover-copy";
  const kicker = document.createElement("p");
  kicker.className = "kicker";
  kicker.textContent = "SHOT-BY-SHOT ANALYSIS";
  const title = document.createElement("h1");
  title.textContent = `《${data.project.name}》逐镜拉片报告`;
  const english = document.createElement("p");
  english.className = "english-title";
  english.textContent = "Director's Shot Analysis";
  const summary = document.createElement("div");
  summary.className = "cover-summary";
  summary.textContent = `全片 ${formatDuration(data.project.duration)} · ${data.shots.length} 镜 · ${data.noteCount} 条导演笔记 · ${data.frameCount} 张代表静帧`;

  const facts = document.createElement("dl");
  facts.className = "credits";
  [
    ["分析方式", data.project.mode === "local" ? "本地自动切镜" : "手动拉片"],
    ["镜头数量", `${data.shots.length} 镜`],
    ["导演笔记", `${data.noteCount} 条`],
    ["代表静帧", `${data.frameCount} 张`],
    ["生成日期", data.generatedDate],
  ].forEach(([label, value]) => {
    const item = document.createElement("div");
    const term = document.createElement("dt");
    term.textContent = label;
    const detail = document.createElement("dd");
    detail.textContent = value;
    item.append(term, detail);
    facts.append(item);
  });
  copy.append(kicker, title, english, summary, facts);
  page.append(coverImage, copy, pageFooter("新天堂电影院·导演工作台", pageNumber));
  return page;
}

function createOverview(data, pageNumber, totalPages) {
  const page = document.createElement("section");
  page.className = "report-page overview-page";
  page.dataset.pageKey = "overview";
  page.dataset.pageName = "分析总览";

  const averageDuration = data.shots.length
    ? data.shots.reduce((sum, shot) => sum + Math.max(0, shot.end - shot.start), 0) / data.shots.length
    : 0;
  const [primarySize, primarySizeCount] = mostCommon(data.shots, "size", "未填写");
  const [primaryMovement, primaryMovementCount] = mostCommon(data.shots, "movement", "未填写");
  const completion = data.shots.length ? Math.round((data.noteCount / data.shots.length) * 100) : 0;

  const heading = document.createElement("div");
  heading.className = "page-heading";
  heading.innerHTML = `<div><p class="kicker">DIRECTOR'S OVERVIEW</p><h2>影片拉片数据总览</h2></div><span class="page-index">${String(pageNumber).padStart(2, "0")} / ${String(totalPages).padStart(2, "0")}</span>`;

  const overview = document.createElement("div");
  overview.className = "overview-grid";
  const insight = document.createElement("article");
  insight.className = "insight-card insight-card-main";
  insight.innerHTML = `<span class="card-label">资料概况</span><h3>本片已整理 ${data.shots.length} 个镜头，平均镜头时长 ${averageDuration.toFixed(1)} 秒。</h3><p>其中 ${data.frameCount} 镜拥有代表静帧，${data.noteCount} 镜已经填写导演笔记。本报告整理自动切镜、代表静帧、基础识别和用户实际填写的导演笔记，不生成虚构的导演意图。</p>`;
  overview.append(insight);
  [
    [`${averageDuration.toFixed(1)} 秒`, "平均镜头时长"],
    [`${data.frameCount} 张`, "代表静帧"],
    [`${completion}%`, "导演笔记完成度"],
  ].forEach(([value, label]) => {
    const card = document.createElement("article");
    card.className = "metric-card";
    card.innerHTML = `<strong>${value}</strong><span>${label}</span>`;
    overview.append(card);
  });

  const columns = document.createElement("div");
  columns.className = "analysis-columns";
  [
    ["景别分布", primarySize, `${primarySizeCount} 个镜头使用“${primarySize}”，为当前填写数量最多的景别。`],
    ["运镜分布", primaryMovement, `${primaryMovementCount} 个镜头使用“${primaryMovement}”，为当前填写数量最多的运镜。`],
    ["资料完整度", `${data.noteCount} 条导演笔记`, `还有 ${Math.max(0, data.shots.length - data.noteCount)} 个镜头尚未填写导演笔记，可继续在拉片工作台完善。`],
  ].forEach(([label, title, body]) => {
    const article = document.createElement("article");
    article.innerHTML = `<span class="card-label">${label}</span><h3>${title}</h3><p>${body}</p>`;
    columns.append(article);
  });

  const strip = document.createElement("div");
  strip.className = "frame-strip";
  const imageShots = data.shots.filter((shot) => shot.imageUrl).slice(0, 4);
  for (let index = 0; index < 4; index += 1) {
    const shot = imageShots[index];
    const figure = document.createElement("figure");
    figure.append(createImage(shot?.imageUrl, shot ? `镜头 ${shot.number} 代表静帧` : "暂无代表静帧"));
    const caption = document.createElement("figcaption");
    caption.textContent = shot ? `镜头 ${String(shot.number).padStart(3, "0")} · ${shot.size || "未填写景别"}` : "暂无代表静帧";
    figure.append(caption);
    strip.append(figure);
  }

  page.append(heading, overview, columns, strip, pageFooter(`《${data.project.name}》逐镜拉片报告`, pageNumber));
  return page;
}

function createShotRow(shot) {
  const row = document.createElement("div");
  row.className = "shot-row";

  const imageCell = document.createElement("div");
  imageCell.className = "shot-image";
  imageCell.append(createImage(shot.imageUrl, `镜头 ${shot.number} 代表静帧`));
  const number = document.createElement("strong");
  number.className = "shot-number";
  number.textContent = `镜 ${String(shot.number).padStart(3, "0")}`;
  const time = document.createElement("span");
  time.innerHTML = `${formatTimecode(shot.start)}<br />—${formatTimecode(shot.end)}`;
  const size = document.createElement("span");
  size.textContent = shot.size || "未填写";
  const camera = document.createElement("span");
  camera.textContent = [shot.angle, shot.movement].filter(Boolean).join(" / ") || "未填写";
  const action = document.createElement("p");
  action.className = shot.action ? "" : "empty-report-field";
  action.textContent = shot.action || "尚未填写画面内容";
  const sound = document.createElement("div");
  sound.className = "sound-dialogue";
  if (shot.sound) {
    const soundNote = document.createElement("p");
    soundNote.className = "sound-note";
    soundNote.textContent = shot.sound;
    sound.append(soundNote);
  }
  const dialogueItems = Array.isArray(shot.dialogueItems) ? shot.dialogueItems : [];
  if (dialogueItems.length) {
    dialogueItems.forEach((item) => {
      const dialogue = document.createElement("div");
      dialogue.className = "dialogue-item";
      const primary = document.createElement("p");
      primary.textContent = item.primary || "";
      dialogue.append(primary);
      if (item.secondary) {
        const secondary = document.createElement("small");
        secondary.textContent = item.secondary;
        dialogue.append(secondary);
      }
      sound.append(dialogue);
    });
  } else if (!shot.sound) {
    const empty = document.createElement("p");
    empty.className = "empty-report-field";
    empty.textContent = "当前镜头无字幕对白";
    sound.append(empty);
  }
  const analysis = document.createElement("p");
  analysis.className = shot.note ? "" : "empty-report-field";
  analysis.textContent = shot.note || "尚未填写导演笔记";

  row.append(imageCell, number, time, size, camera, action, sound, analysis);
  return row;
}

function createShotPage(data, shots, groupIndex, pageNumber, totalPages) {
  const page = document.createElement("section");
  page.className = "report-page table-page";
  page.dataset.pageKey = `shots-${groupIndex + 1}`;
  page.dataset.pageGroup = "shots";
  page.dataset.pageName = `逐镜表 ${groupIndex + 1}`;

  const first = shots[0];
  const last = shots[shots.length - 1];
  const heading = document.createElement("div");
  heading.className = "page-heading compact-heading";
  heading.innerHTML = `<div><p class="kicker">SHOTS ${String(first.number).padStart(3, "0")} - ${String(last.number).padStart(3, "0")} · ${formatTimecode(first.start)} - ${formatTimecode(last.end)}</p><h2>逐镜拉片表 · 第 ${groupIndex + 1} 组</h2></div><span class="page-index">${String(pageNumber).padStart(2, "0")} / ${String(totalPages).padStart(2, "0")}</span>`;

  const table = document.createElement("div");
  table.className = "shot-table";
  const head = document.createElement("div");
  head.className = "shot-row shot-head";
  ["截图", "镜号", "时间码", "景别", "机位 / 镜头运动", "画面内容 / 人物动作", "声音 / 字幕对白", "导演分析"].forEach((label) => {
    const span = document.createElement("span");
    span.textContent = label;
    head.append(span);
  });
  table.append(head);
  shots.forEach((shot) => table.append(createShotRow(shot)));

  page.append(heading, table, pageFooter(`《${data.project.name}》逐镜拉片报告`, pageNumber));
  return page;
}

function applySelectedContent() {
  const selectedGroups = reportParams.get("pages")?.split(",").filter(Boolean);
  const selectedFields = reportParams.get("fields")?.split(",").filter(Boolean);
  const previewKey = reportParams.get("preview");
  if (selectedGroups?.length) {
    document.querySelectorAll(".report-page").forEach((page) => {
      const selected = selectedGroups.includes(page.dataset.pageKey)
        || selectedGroups.includes(page.dataset.pageGroup);
      page.style.display = selected ? "" : "none";
    });
  }
  if (previewKey) {
    document.querySelectorAll(".report-page").forEach((page) => {
      page.style.display = page.dataset.pageKey === previewKey ? "block" : "none";
    });
  }
  if (selectedFields) {
    ["images", "sound", "analysis"].forEach((field) => {
      document.body.classList.toggle(`hide-${field}`, !selectedFields.includes(field));
    });
  }
}

function renderCinemaReport(data) {
  if (!data?.project || !Array.isArray(data.shots)) return;
  const shotGroups = [];
  for (let index = 0; index < data.shots.length; index += 4) {
    shotGroups.push(data.shots.slice(index, index + 4));
  }
  const totalPages = 2 + shotGroups.length;
  const reportTitle = `《${data.project.name}》逐镜拉片报告`;
  document.title = reportTitle;
  reportDocument.replaceChildren();
  const previewKey = reportParams.get("preview");
  if (previewKey === "cover") {
    reportDocument.append(createCover(data, 1));
  } else if (previewKey === "overview") {
    reportDocument.append(createOverview(data, 2, totalPages));
  } else if (previewKey?.startsWith("shots-")) {
    const groupIndex = Number(previewKey.slice(6)) - 1;
    const shots = shotGroups[groupIndex];
    if (shots) {
      reportDocument.append(createShotPage(
        data,
        shots,
        groupIndex,
        groupIndex + 3,
        totalPages
      ));
    }
  } else {
    reportDocument.append(createCover(data, 1));
    reportDocument.append(createOverview(data, 2, totalPages));
    shotGroups.forEach((shots, index) => {
      reportDocument.append(createShotPage(data, shots, index, index + 3, totalPages));
    });
  }
  applySelectedContent();
  const pages = [...document.querySelectorAll(".report-page")].map((page) => ({
    key: page.dataset.pageKey,
    group: page.dataset.pageGroup || page.dataset.pageKey,
    name: page.dataset.pageName,
  }));
  window.dispatchEvent(new CustomEvent("cinema-report-rendered", { detail: { pages } }));
  window.parent?.postMessage({ type: "cinema-report-rendered", pages }, "*");
  window.opener?.postMessage({ type: "cinema-report-rendered", pages }, "*");

  if (reportParams.get("print") === "1" && !hasPrinted) {
    hasPrinted = true;
    window.setTimeout(() => window.print(), 350);
  }
}

window.renderCinemaReport = renderCinemaReport;

window.addEventListener("message", (event) => {
  if (event.data?.type === "cinema-report-data") {
    renderCinemaReport(event.data.report);
  }
});

if (reportParams.get("embed") === "1") {
  document.body.classList.add("embed-mode");
}

const hashParams = new URLSearchParams(window.location.hash.slice(1));
const embeddedReport = decodeReportData(hashParams.get("data"));
if (embeddedReport) renderCinemaReport(embeddedReport);
window.parent?.postMessage({ type: "cinema-report-ready" }, "*");
window.opener?.postMessage({ type: "cinema-report-ready" }, "*");
