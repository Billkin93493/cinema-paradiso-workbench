const { app, BrowserWindow, dialog, ipcMain } = require("electron");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const { pathToFileURL } = require("node:url");

const VIDEO_EXTENSIONS = ["mp4", "mov", "m4v", "webm", "mkv", "avi"];

app.setName("新天堂电影院·导演工作台");

function projectRecordPath() {
  return path.join(app.getPath("userData"), "recent-project.json");
}

function inspirationCollectionsPath() {
  return path.join(app.getPath("userData"), "inspiration-collections.json");
}

function inspirationMembershipsPath() {
  return path.join(app.getPath("userData"), "inspiration-memberships.json");
}

function inspirationNotesPath() {
  return path.join(app.getPath("userData"), "inspiration-notes.json");
}

function readInspirationCollections() {
  try {
    const records = JSON.parse(fs.readFileSync(inspirationCollectionsPath(), "utf8"));
    if (!Array.isArray(records)) return [];
    return records.sort((a, b) => String(b.lastUsedAt).localeCompare(String(a.lastUsedAt)));
  } catch {
    return [];
  }
}

function writeInspirationCollections(records) {
  fs.mkdirSync(path.dirname(inspirationCollectionsPath()), { recursive: true });
  fs.writeFileSync(
    inspirationCollectionsPath(),
    JSON.stringify(records, null, 2),
    "utf8"
  );
}

function readInspirationMemberships() {
  try {
    const records = JSON.parse(fs.readFileSync(inspirationMembershipsPath(), "utf8"));
    if (!Array.isArray(records)) return [];
    return records.sort((a, b) => String(b.addedAt).localeCompare(String(a.addedAt)));
  } catch {
    return [];
  }
}

function writeInspirationMemberships(records) {
  fs.mkdirSync(path.dirname(inspirationMembershipsPath()), { recursive: true });
  fs.writeFileSync(
    inspirationMembershipsPath(),
    JSON.stringify(records, null, 2),
    "utf8"
  );
}

function readInspirationNotes() {
  try {
    const records = JSON.parse(fs.readFileSync(inspirationNotesPath(), "utf8"));
    if (!Array.isArray(records)) return [];
    return records.sort((a, b) => String(b.updatedAt).localeCompare(String(a.updatedAt)));
  } catch {
    return [];
  }
}

function writeInspirationNotes(records) {
  fs.mkdirSync(path.dirname(inspirationNotesPath()), { recursive: true });
  fs.writeFileSync(
    inspirationNotesPath(),
    JSON.stringify(records, null, 2),
    "utf8"
  );
}

function normalizedCollectionInput(payload) {
  return {
    name: String(payload?.name || "").trim(),
    description: String(payload?.description || "").trim(),
  };
}

function hasDuplicateCollectionName(records, name, ignoredId = "") {
  return records.some((record) => (
    record.id !== ignoredId
    && String(record.name).localeCompare(name, undefined, { sensitivity: "base" }) === 0
  ));
}

function readRecentProject() {
  try {
    const project = JSON.parse(fs.readFileSync(projectRecordPath(), "utf8"));
    if (!project.filePath || !fs.existsSync(project.filePath)) {
      return null;
    }
    return {
      ...project,
      fileUrl: pathToFileURL(project.filePath).href,
    };
  } catch {
    return null;
  }
}

function writeRecentProject(project) {
  const storedProject = {
    name: project.name,
    filePath: project.filePath,
    size: project.size,
    duration: project.duration || 0,
    analysis: project.analysis || null,
    updatedAt: new Date().toISOString(),
  };
  fs.mkdirSync(path.dirname(projectRecordPath()), { recursive: true });
  fs.writeFileSync(projectRecordPath(), JSON.stringify(storedProject, null, 2), "utf8");
  return {
    ...storedProject,
    fileUrl: pathToFileURL(storedProject.filePath).href,
  };
}

function createWindow() {
  const window = new BrowserWindow({
    width: 1440,
    height: 920,
    minWidth: 1180,
    minHeight: 760,
    backgroundColor: "#080b11",
    title: "新天堂电影院·导演工作台",
    titleBarStyle: "hiddenInset",
    trafficLightPosition: { x: 18, y: 17 },
    show: false,
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });

  window.loadFile(path.join(__dirname, "..", "preview", "index.html"));
  window.once("ready-to-show", () => window.show());

  window.webContents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith("file://")) {
      return {
        action: "allow",
        overrideBrowserWindowOptions: {
          width: 1280,
          height: 860,
          backgroundColor: "#080910",
          webPreferences: {
            contextIsolation: true,
            nodeIntegration: false,
            sandbox: true,
          },
        },
      };
    }
    return { action: "deny" };
  });
}

ipcMain.handle("video:select", async () => {
  const result = await dialog.showOpenDialog({
    title: "选择要拉片的影片",
    properties: ["openFile"],
    filters: [
      {
        name: "影片文件",
        extensions: VIDEO_EXTENSIONS,
      },
    ],
  });

  if (result.canceled || !result.filePaths[0]) {
    return null;
  }

  const filePath = result.filePaths[0];
  const stats = fs.statSync(filePath);
  const project = writeRecentProject({
    name: path.parse(filePath).name,
    filePath,
    size: stats.size,
    duration: 0,
  });

  return project;
});

ipcMain.handle("project:recent", () => readRecentProject());

ipcMain.handle("project:update", (_event, updates) => {
  const current = readRecentProject();
  if (!current) {
    return null;
  }
  return writeRecentProject({
    ...current,
    duration: Number(updates.duration) || current.duration || 0,
  });
});

ipcMain.handle("project:save-analysis", (_event, analysis) => {
  const current = readRecentProject();
  if (!current) {
    return null;
  }
  return writeRecentProject({
    ...current,
    analysis,
  });
});

ipcMain.handle("inspiration-collections:list", () => readInspirationCollections());

ipcMain.handle("inspiration-collections:create", (_event, payload) => {
  const input = normalizedCollectionInput(payload);
  if (!input.name || !input.description) {
    return { error: "请填写收藏夹名称和一句说明" };
  }
  const records = readInspirationCollections();
  if (hasDuplicateCollectionName(records, input.name)) {
    return { error: "已经有同名收藏夹，请换一个名称" };
  }
  const now = new Date().toISOString();
  const record = {
    id: crypto.randomUUID(),
    name: input.name,
    description: input.description,
    createdAt: now,
    updatedAt: now,
    lastUsedAt: now,
  };
  records.push(record);
  writeInspirationCollections(records);
  return record;
});

ipcMain.handle("inspiration-collections:update", (_event, payload) => {
  const input = normalizedCollectionInput(payload);
  const id = String(payload?.id || "");
  const records = readInspirationCollections();
  const index = records.findIndex((record) => record.id === id);
  if (index < 0) return { error: "没有找到这个收藏夹" };
  if (!input.name || !input.description) {
    return { error: "请填写收藏夹名称和一句说明" };
  }
  if (hasDuplicateCollectionName(records, input.name, id)) {
    return { error: "已经有同名收藏夹，请换一个名称" };
  }
  const now = new Date().toISOString();
  records[index] = {
    ...records[index],
    name: input.name,
    description: input.description,
    updatedAt: now,
    lastUsedAt: now,
  };
  writeInspirationCollections(records);
  return records[index];
});

ipcMain.handle("inspiration-collections:delete", (_event, payload) => {
  const id = String(payload?.id || "");
  const records = readInspirationCollections();
  if (!records.some((record) => record.id === id)) {
    return { error: "没有找到这个收藏夹" };
  }
  writeInspirationCollections(records.filter((record) => record.id !== id));
  writeInspirationMemberships(
    readInspirationMemberships().filter((record) => record.collectionId !== id)
  );
  writeInspirationNotes(
    readInspirationNotes()
      .map((record) => ({
        ...record,
        collectionIds: (record.collectionIds || []).filter((collectionId) => collectionId !== id),
      }))
      .filter((record) => record.collectionIds.length)
  );
  return { deleted: true, id };
});

ipcMain.handle("inspiration-collections:touch", (_event, payload) => {
  const id = String(payload?.id || "");
  const records = readInspirationCollections();
  const index = records.findIndex((record) => record.id === id);
  if (index < 0) return null;
  records[index] = {
    ...records[index],
    lastUsedAt: new Date().toISOString(),
  };
  writeInspirationCollections(records);
  return records[index];
});

ipcMain.handle("inspiration-memberships:list", () => readInspirationMemberships());

ipcMain.handle("inspiration-memberships:add-archive", (_event, payload) => {
  const collectionId = String(payload?.collectionId || "");
  const itemType = String(payload?.itemType || "");
  const itemId = String(payload?.itemId || "");
  const collections = readInspirationCollections();
  if (!collections.some((collection) => collection.id === collectionId)) {
    return { error: "没有找到这个收藏夹" };
  }
  if (!["frame", "clip"].includes(itemType) || !itemId) {
    return { error: "这份资料暂时不能加入收藏夹" };
  }
  const records = readInspirationMemberships();
  const existing = records.find((record) => (
    record.collectionId === collectionId
    && record.itemType === itemType
    && record.itemId === itemId
  ));
  if (existing) return { ...existing, alreadyExists: true };

  const record = {
    id: crypto.randomUUID(),
    collectionId,
    itemType,
    itemId,
    addedAt: new Date().toISOString(),
  };
  records.push(record);
  writeInspirationMemberships(records);

  const collectionIndex = collections.findIndex((collection) => collection.id === collectionId);
  collections[collectionIndex] = {
    ...collections[collectionIndex],
    lastUsedAt: record.addedAt,
  };
  writeInspirationCollections(collections);
  return record;
});

ipcMain.handle("inspiration-notes:list", () => readInspirationNotes());

ipcMain.handle("inspiration-notes:upsert", (_event, payload) => {
  const collections = readInspirationCollections();
  const validCollectionIds = [...new Set(
    (Array.isArray(payload?.collectionIds) ? payload.collectionIds : [])
      .map((id) => String(id || ""))
      .filter((id) => collections.some((collection) => collection.id === id))
  )];
  const rawTitle = String(payload?.title || "").trim();
  const body = String(payload?.body || "").trim();
  if (!rawTitle && !body) return { error: "请写下标题或正文" };
  if (!validCollectionIds.length) return { error: "请至少选择一个收藏夹" };

  const records = readInspirationNotes();
  const id = String(payload?.id || "");
  const index = records.findIndex((record) => record.id === id);
  const now = new Date().toISOString();
  const record = {
    id: index >= 0 ? records[index].id : crypto.randomUUID(),
    title: rawTitle || "未命名文字",
    body,
    collectionIds: validCollectionIds,
    createdAt: index >= 0 ? records[index].createdAt : now,
    updatedAt: now,
  };
  if (index >= 0) {
    records[index] = record;
  } else {
    records.push(record);
  }
  writeInspirationNotes(records);

  validCollectionIds.forEach((collectionId) => {
    const collectionIndex = collections.findIndex((collection) => collection.id === collectionId);
    if (collectionIndex >= 0) collections[collectionIndex].lastUsedAt = now;
  });
  writeInspirationCollections(collections);
  return record;
});

app.whenReady().then(() => {
  createWindow();

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});
