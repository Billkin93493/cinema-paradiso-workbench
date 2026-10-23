const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("cinemaDesktop", {
  selectVideo: () => ipcRenderer.invoke("video:select"),
  getRecentProject: () => ipcRenderer.invoke("project:recent"),
  updateProject: (updates) => ipcRenderer.invoke("project:update", updates),
  saveAnalysis: (analysis) => ipcRenderer.invoke("project:save-analysis", analysis),
  getInspirationCollections: () => ipcRenderer.invoke("inspiration-collections:list"),
  createInspirationCollection: (collection) => (
    ipcRenderer.invoke("inspiration-collections:create", collection)
  ),
  updateInspirationCollection: (collection) => (
    ipcRenderer.invoke("inspiration-collections:update", collection)
  ),
  deleteInspirationCollection: (collection) => (
    ipcRenderer.invoke("inspiration-collections:delete", collection)
  ),
  touchInspirationCollection: (collection) => (
    ipcRenderer.invoke("inspiration-collections:touch", collection)
  ),
  getInspirationMemberships: () => ipcRenderer.invoke("inspiration-memberships:list"),
  addArchiveRecordToInspiration: (membership) => (
    ipcRenderer.invoke("inspiration-memberships:add-archive", membership)
  ),
  getInspirationNotes: () => ipcRenderer.invoke("inspiration-notes:list"),
  upsertInspirationNote: (note) => ipcRenderer.invoke("inspiration-notes:upsert", note),
});
