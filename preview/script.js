const pageNames = {
  library: "影片库",
  workbench: "拉片工作台",
  archive: "导演资料库",
  inspiration: "灵感板",
  export: "导出中心",
  settings: "个人设置",
};

const navItems = document.querySelectorAll(".nav-item");
const pages = document.querySelectorAll(".page");
const pageTitle = document.querySelector("#page-title");
const toast = document.querySelector(".toast");
let toastTimer;
let currentLocalProject = null;
let manualAnalysis = null;
let selectedManualShotKey = null;
let manualSaveTimer;
let isLocalAnalyzing = false;
let archiveFrames = [];
let archiveClips = [];
let activeArchiveFilter = "all";
let archiveSearchQuery = "";
let activeArchiveProject = "all";
let activeArchiveTag = "all";
let archiveSortMode = "newest";
let archiveBulkMode = false;
let archiveSelectedRecords = new Set();
let activeArchiveRecord = null;
let archiveDraftTags = [];
let pendingArchiveTarget = null;
let customClipIn = null;
let customClipOut = null;
let activeClipPlaybackEnd = null;
let activeClipPlaybackContinue = false;
let isGeneratingRepresentativeFrames = false;
let isResumingLocalAnalysisAssets = false;
let isBasicSceneAnalyzing = false;
let aiTranslationConfigured = false;
let isAITranslationRunning = false;
let cloudSubtitleConfigured = false;
let isCloudSubtitleRunning = false;
let activeWorkbenchSideTab = "analysis";
let activeInspirationCollection = "all";
let activeInspirationFilter = "all";
let inspirationBulkMode = false;
let activeInspirationCard = null;
let inspirationCollections = [];
let inspirationMemberships = [];
let inspirationNotes = [];
let inspirationImages = [];
let editingInspirationCollectionId = null;
let editingInspirationNoteId = null;
let noteSaveTimer;
let noteSaveQueue = Promise.resolve();
let inspirationPreviewNoteSaveTimer;
let pendingInspirationPreviewNoteSave = null;
let inspirationPreviewNoteSaveQueue = Promise.resolve();
let draggedArchiveRecord = null;
let draggedLibraryProject = null;
let inspirationSourceReturnState = null;
let projectLibrary = [];
let librarySearchQuery = "";
let activeProjectCategory = "all";
let libraryExpanded = false;
let timelineZoom = 1;
let moveCutDraft = null;
let isPlayerFullscreen = false;
let playerChromeHideTimer = null;
let lastVideoErrorFilePath = "";
let activeStructureNodeId = "root";
let editingStructureNodeId = null;
let structureBoardSaveTimer;
let structureNodeDrag = null;

const libraryCategoryColorCycle = ["blue", "violet", "cyan"];
const defaultLibraryCategories = [
  { id: "feature", name: "剧情长片", color: "blue", builtIn: true },
  { id: "ad", name: "广告参考", color: "violet", builtIn: true },
  { id: "short", name: "短片研究", color: "cyan", builtIn: true },
];
const defaultLibraryCategoryIds = new Set(defaultLibraryCategories.map((category) => category.id));
const libraryCategoryStorageKey = "cinema-paradiso-project-categories";
const removedLibraryProjectsStorageKey = "cinema-paradiso-removed-library-projects";
const newUserGuideStorageKey = "cinema-paradiso-new-user-guide-seen-v1";
const lightAccountStorageKey = "cinema-paradiso-light-account-profile";
let libraryCategories = defaultLibraryCategories.map((category) => ({ ...category }));
let removedLibraryProjectPaths = new Set(readRemovedLibraryProjectPaths());
let lightAccountProfile = readLightAccountProfile();

const openingSplash = document.querySelector("#opening-splash");
const launchScreen = document.querySelector("#launch-screen");
const launchContinueButton = document.querySelector("#launch-continue");
const launchNewProjectButton = document.querySelector("#launch-new-project");
const launchGuideButton = document.querySelector("#launch-guide");
const launchSkipButton = document.querySelector("#launch-skip");
const newUserGuideOverlay = document.querySelector("#new-user-guide-overlay");
const guideCloseButton = document.querySelector("#guide-close");
const guideLaterButton = document.querySelector("#guide-later");
const guideDoneButton = document.querySelector("#guide-done");
const appShell = document.querySelector(".app-shell");
const analysisPanel = document.querySelector(".analysis-panel");
const globalSearchInput = document.querySelector("#global-search-input");
const libraryPage = document.querySelector("#library-page");
const projectGrid = document.querySelector("#project-grid");
const viewAllProjectsButton = document.querySelector("#view-all-projects");
const libraryCategoryList = document.querySelector("#library-category-list");
const addLibraryCategoryButton = document.querySelector("#add-library-category");
const addLibraryCategoryInlineButton = document.querySelector("#add-library-category-inline");
const libraryCategoryOverview = document.querySelector("#library-category-overview");
const libraryCategoryTitle = document.querySelector("#library-category-title");
const libraryCategoryDescription = document.querySelector("#library-category-description");
const librarySectionTitle = document.querySelector("#library-section-title");
const librarySectionDescription = document.querySelector("#library-section-description");
const backToLibraryButton = document.querySelector("#back-to-library");
const libraryCategoryEditorOverlay = document.querySelector("#library-category-editor-overlay");
const libraryCategoryEditorClose = document.querySelector("#library-category-editor-close");
const libraryCategoryEditorCancel = document.querySelector("#library-category-editor-cancel");
const libraryCategoryForm = document.querySelector("#library-category-form");
const libraryCategoryNameInput = document.querySelector("#library-category-name");
const libraryCategoryError = document.querySelector("#library-category-error");
const continueCover = document.querySelector("#continue-cover");
const continueCoverPlaceholder = document.querySelector("#continue-cover-placeholder");
const continueFilmType = document.querySelector("#continue-film-type");
const continueProgressLabel = document.querySelector("#continue-progress-label");
const continueUpdatedLabel = document.querySelector("#continue-updated-label");
const continueProgressBar = document.querySelector("#continue-progress-bar");
const localVideo = document.querySelector("#local-video");
const videoStage = document.querySelector(".video-stage");
const mainFrame = document.querySelector("#main-frame");
const currentTimeLabel = document.querySelector(".player-controls .timecode");
const totalTimeLabel = document.querySelector(".player-controls .timecode.muted");
const playerScrubber = document.querySelector(".scrubber");
const playerScrubberProgress = playerScrubber?.querySelector("span");
const playerScrubberHandle = playerScrubber?.querySelector("i");
const playerSkipBack = document.querySelector("#player-skip-back");
const playerFrameBack = document.querySelector("#player-frame-back");
const playerFrameForward = document.querySelector("#player-frame-forward");
const playerSkipForward = document.querySelector("#player-skip-forward");
const playerSpeedButton = document.querySelector("#player-speed");
const playerFullscreenButton = document.querySelector("#player-fullscreen");
const timelineZoomOutButton = document.querySelector("#timeline-zoom-out");
const timelineZoomInButton = document.querySelector("#timeline-zoom-in");
const timelineZoomLabel = document.querySelector("#timeline-zoom-label");
const shotStrip = document.querySelector("#shot-strip");
const timelineSummary = document.querySelector("#timeline-summary");
const shotInInput = document.querySelector("#shot-in");
const shotOutInput = document.querySelector("#shot-out");
const shotDurationInput = document.querySelector("#shot-duration");
const shotAngleSelect = document.querySelector("#shot-angle");
const shotMovementSelect = document.querySelector("#shot-movement");
const directorNote = document.querySelector("#director-note");
const openStructureBoardButton = document.querySelector("#open-structure-board");
const structureBoardPreview = document.querySelector("#structure-board-preview");
const structureBoardMiniCanvas = document.querySelector("#structure-board-mini-canvas");
const structureBoardEmpty = document.querySelector("#structure-board-empty");
const structureBoardOverlay = document.querySelector("#structure-board-overlay");
const structureBoardClose = document.querySelector("#structure-board-close");
const structureBoardDone = document.querySelector("#structure-board-done");
const structureBoardTitle = document.querySelector("#structure-board-title");
const structureBoardSubtitle = document.querySelector("#structure-board-subtitle");
const structureBoardCanvas = document.querySelector("#structure-board-canvas");
const structureBoardSaveState = document.querySelector("#structure-board-save-state");
const structureAddTopicButton = document.querySelector("#structure-add-topic");
const structureAddBranchButton = document.querySelector("#structure-add-branch");
const structureRenameNodeButton = document.querySelector("#structure-rename-node");
const structureAutoLayoutButton = document.querySelector("#structure-auto-layout");
const analysisShotLabel = document.querySelector("#analysis-shot-label");
const directorAnalysisTab = document.querySelector("#director-analysis-tab");
const basicSceneTab = document.querySelector("#basic-scene-tab");
const subtitleDialogueTab = document.querySelector("#subtitle-dialogue-tab");
const directorAnalysisPanel = document.querySelector("#director-analysis-panel");
const basicScenePanel = document.querySelector("#basic-scene-panel");
const subtitleDialoguePanel = document.querySelector("#subtitle-dialogue-panel");
const basicSceneSummary = document.querySelector("#basic-scene-summary");
const basicSceneOverall = document.querySelector("#basic-scene-overall");
const analyzeBasicScenesButton = document.querySelector("#analyze-basic-scenes");
const basicSceneProgress = document.querySelector("#basic-scene-progress");
const basicSceneProgressPercent = document.querySelector("#basic-scene-progress-percent");
const basicSceneProgressBar = document.querySelector("#basic-scene-progress-bar");
const basicSceneSaveState = document.querySelector("#basic-scene-save-state");
const subtitleTabCount = document.querySelector("#subtitle-tab-count");
const subtitleDialogueCount = document.querySelector("#subtitle-dialogue-count");
const subtitleLanguageState = document.querySelector("#subtitle-language-state");
const subtitleSource = document.querySelector("#subtitle-source");
const subtitleDialogueList = document.querySelector("#subtitle-dialogue-list");
const subtitleDialogueEmpty = document.querySelector("#subtitle-dialogue-empty");
const retryReadSubtitlesButton = document.querySelector("#retry-read-subtitles");
const subtitleSaveState = document.querySelector("#subtitle-save-state");
const saveState = document.querySelector(".save-state");
const syncCard = document.querySelector(".sync-card");
const syncIcon = document.querySelector(".sync-icon");
const syncTitle = document.querySelector(".sync-card strong");
const syncDetail = document.querySelector(".sync-card small");
const analysisChoice = document.querySelector("#analysis-choice");
const analysisChoiceFilm = document.querySelector("#analysis-choice-film");
const startLocalAnalysisButton = document.querySelector("#start-local-analysis");
const startManualAnalysisButton = document.querySelector("#start-manual-analysis");
const analysisProgress = document.querySelector("#analysis-progress");
const analysisProgressDetail = document.querySelector("#analysis-progress-detail");
const analysisProgressPercent = document.querySelector("#analysis-progress-percent");
const analysisProgressBar = document.querySelector("#analysis-progress-bar");
const favoriteFrameButton = document.querySelector("#favorite-frame");
const representativeFrameStatus = document.querySelector("#representative-frame-status");
const setRepresentativeFrameButton = document.querySelector("#set-representative-frame");
const archiveSearchInput = document.querySelector("#archive-search-input");
const archiveEmpty = document.querySelector("#archive-empty");
const archiveFrameCount = document.querySelector("#archive-frame-count");
const archiveClipCount = document.querySelector("#archive-clip-count");
const archiveProjectCount = document.querySelector("#archive-project-count");
const archiveTagCount = document.querySelector("#archive-tag-count");
const memoryGrid = document.querySelector("#memory-grid");
const archiveMoreFiltersButton = document.querySelector("#archive-more-filters");
const archiveFilterPanel = document.querySelector("#archive-filter-panel");
const archiveProjectFilter = document.querySelector("#archive-project-filter");
const archiveSort = document.querySelector("#archive-sort");
const archiveTagFilters = document.querySelector("#archive-tag-filters");
const archiveClearFilters = document.querySelector("#archive-clear-filters");
const archiveOrderLabel = document.querySelector("#archive-order-label");
const archiveBulkButton = document.querySelector("#archive-bulk-button");
const archiveBulkBar = document.querySelector("#archive-bulk-bar");
const archiveSelectedCount = document.querySelector("#archive-selected-count");
const archiveBulkCommonTags = document.querySelector("#archive-bulk-common-tags");
const archiveBulkTagInput = document.querySelector("#archive-bulk-tag-input");
const archiveBulkAddTag = document.querySelector("#archive-bulk-add-tag");
const archiveBulkRemoveTag = document.querySelector("#archive-bulk-remove-tag");
const archiveBulkFinish = document.querySelector("#archive-bulk-finish");
const archiveDetailOverlay = document.querySelector("#archive-detail-overlay");
const archiveDetailClose = document.querySelector("#archive-detail-close");
const archiveDetailImage = document.querySelector("#archive-detail-image");
const archiveDetailType = document.querySelector("#archive-detail-type");
const archiveDetailTitle = document.querySelector("#archive-detail-title");
const archiveDetailMeta = document.querySelector("#archive-detail-meta");
const archiveDetailNote = document.querySelector("#archive-detail-note");
const archiveCurrentTags = document.querySelector("#archive-current-tags");
const archiveCommonTags = document.querySelector("#archive-common-tags");
const archiveCustomTagInput = document.querySelector("#archive-custom-tag-input");
const archiveAddCustomTag = document.querySelector("#archive-add-custom-tag");
const archiveReturnSource = document.querySelector("#archive-return-source");
const archiveSaveTags = document.querySelector("#archive-save-tags");
const archiveCurrentClipButton = document.querySelector("#archive-current-clip");
const currentClipSummary = document.querySelector("#current-clip-summary");
const toggleClipRangeButton = document.querySelector("#toggle-clip-range");
const clipRangePanel = document.querySelector("#clip-range-panel");
const clipInTime = document.querySelector("#clip-in-time");
const clipOutTime = document.querySelector("#clip-out-time");
const clipRangeDuration = document.querySelector("#clip-range-duration");
const clipRangeHint = document.querySelector("#clip-range-hint");
const setClipInButton = document.querySelector("#set-clip-in");
const setClipOutButton = document.querySelector("#set-clip-out");
const saveCustomClipButton = document.querySelector("#save-custom-clip");
const createBackupPreviewButton = document.querySelector("#preview-create-backup");
const restoreBackupPreviewButton = document.querySelector("#preview-restore-backup");
const restorePreviewOverlay = document.querySelector("#restore-preview-overlay");
const restorePreviewClose = document.querySelector("#restore-preview-close");
const restorePreviewCancel = document.querySelector("#restore-preview-cancel");
const restorePreviewConfirm = document.querySelector("#restore-preview-confirm");
const restoreBackupDate = document.querySelector("#restore-backup-date");
const restoreBackupName = document.querySelector("#restore-backup-name");
const restoreProjectCount = document.querySelector("#restore-project-count");
const restoreFrameCount = document.querySelector("#restore-frame-count");
const restoreClipCount = document.querySelector("#restore-clip-count");
const restoreShotCount = document.querySelector("#restore-shot-count");
const restoreCollectionCount = document.querySelector("#restore-collection-count");
const restoreInspirationCount = document.querySelector("#restore-inspiration-count");
const restoreNoteCount = document.querySelector("#restore-note-count");
const restorePreviewDescription = document.querySelector("#restore-preview-description");
const backupHistoryIcon = document.querySelector("#backup-history-icon");
const backupHistoryTitle = document.querySelector("#backup-history-title");
const backupHistoryDetail = document.querySelector("#backup-history-detail");
const accountStatusPill = document.querySelector("#account-status-pill");
const accountCardSummary = document.querySelector("#account-card-summary");
const openAccountDialogButton = document.querySelector("#open-account-dialog");
const clearAccountProfileButton = document.querySelector("#clear-account-profile");
const accountOverlay = document.querySelector("#account-overlay");
const accountDialogClose = document.querySelector("#account-dialog-close");
const accountDialogCancel = document.querySelector("#account-dialog-cancel");
const accountForm = document.querySelector("#account-form");
const accountDisplayNameInput = document.querySelector("#account-display-name");
const accountEmailInput = document.querySelector("#account-email");
const accountFormError = document.querySelector("#account-form-error");
const userCardTitle = document.querySelector(".user-card strong");
const userCardDetail = document.querySelector(".user-card small");
const projectOverviewOverlay = document.querySelector("#project-overview-overlay");
const projectOverviewClose = document.querySelector("#project-overview-close");
const projectOverviewCancel = document.querySelector("#project-overview-cancel");
const projectOverviewContinue = document.querySelector("#project-overview-continue");
const overviewShotCount = document.querySelector("#overview-shot-count");
const overviewFrameCount = document.querySelector("#overview-frame-count");
const overviewClipCount = document.querySelector("#overview-clip-count");
const overviewNoteProgress = document.querySelector("#overview-note-progress");
const overviewStatus = document.querySelector("#overview-status");
const overviewStatusDetail = document.querySelector("#overview-status-detail");
const overviewUpdated = document.querySelector("#overview-updated");
const moveCutOverlay = document.querySelector("#move-cut-overlay");
const moveCutClose = document.querySelector("#move-cut-close");
const moveCutCancel = document.querySelector("#move-cut-cancel");
const moveCutConfirm = document.querySelector("#move-cut-confirm");
const moveCutSlider = document.querySelector("#move-cut-slider");
const moveCutTimeInput = document.querySelector("#move-cut-time-input");
const moveCutUsePlayhead = document.querySelector("#move-cut-use-playhead");
const moveCutRange = document.querySelector("#move-cut-range");
const moveCutHint = document.querySelector("#move-cut-hint");
const openCloudSubtitleButton = document.querySelector("#open-cloud-subtitle");
const cloudSubtitleOverlay = document.querySelector("#cloud-subtitle-overlay");
const cloudSubtitleClose = document.querySelector("#cloud-subtitle-close");
const cancelCloudSubtitleButton = document.querySelector("#cancel-cloud-subtitle");
const saveCloudSubtitleButton = document.querySelector("#save-cloud-subtitle");
const removeCloudSubtitleKeyButton = document.querySelector("#remove-cloud-subtitle-key");
const cloudSubtitleKeyInput = document.querySelector("#cloud-subtitle-key");
const cloudSubtitleStatus = document.querySelector("#cloud-subtitle-status");
const cloudProviderState = document.querySelector("#cloud-provider-state");
const cloudKeyHint = document.querySelector("#cloud-key-hint");
const startCloudSubtitleButton = document.querySelector("#start-cloud-subtitle");
const cloudSubtitleTaskTitle = document.querySelector("#cloud-subtitle-task-title");
const cloudSubtitleTaskDetail = document.querySelector("#cloud-subtitle-task-detail");
const cloudSubtitleProgress = document.querySelector("#cloud-subtitle-progress");
const cloudSubtitleProgressLabel = document.querySelector("#cloud-subtitle-progress-label");
const cloudSubtitleProgressPercent = document.querySelector("#cloud-subtitle-progress-percent");
const cloudSubtitleProgressBar = document.querySelector("#cloud-subtitle-progress-bar");
const cloudSubtitleError = document.querySelector("#cloud-subtitle-error");
const openAITranslationButton = document.querySelector("#open-ai-translation");
const aiTranslationOverlay = document.querySelector("#ai-translation-overlay");
const aiTranslationClose = document.querySelector("#ai-translation-close");
const cancelAITranslationButton = document.querySelector("#cancel-ai-translation");
const saveAITranslationButton = document.querySelector("#save-ai-translation");
const removeAITranslationKeyButton = document.querySelector("#remove-ai-translation-key");
const aiTranslationKeyInput = document.querySelector("#ai-translation-key");
const aiTranslationStatus = document.querySelector("#ai-translation-status");
const aiProviderState = document.querySelector("#ai-provider-state");
const aiKeyHint = document.querySelector("#ai-key-hint");
const startAITranslationButton = document.querySelector("#start-ai-translation");
const aiTranslationTaskTitle = document.querySelector("#ai-translation-task-title");
const aiTranslationTaskDetail = document.querySelector("#ai-translation-task-detail");
const aiTranslationProgress = document.querySelector("#ai-translation-progress");
const aiTranslationProgressLabel = document.querySelector("#ai-translation-progress-label");
const aiTranslationProgressPercent = document.querySelector("#ai-translation-progress-percent");
const aiTranslationProgressBar = document.querySelector("#ai-translation-progress-bar");
const aiTranslationError = document.querySelector("#ai-translation-error");
const inspirationLayout = document.querySelector("#inspiration-layout");
const collectionList = document.querySelector("#collection-list");
const inspirationWorkspace = document.querySelector(".inspiration-workspace");
const inspirationMasonry = document.querySelector("#inspiration-masonry");
const inspirationEmpty = document.querySelector("#inspiration-empty");
const inspirationSearchInput = document.querySelector("#inspiration-search-input");
const inspirationResultCount = document.querySelector("#inspiration-result-count");
const inspirationCollectionTitle = document.querySelector("#inspiration-collection-title");
const inspirationCollectionDescription = document.querySelector("#inspiration-collection-description");
const inspirationBulkButton = document.querySelector("#inspiration-bulk-button");
const inspirationBulkBar = document.querySelector("#inspiration-bulk-bar");
const inspirationSelectedCount = document.querySelector("#inspiration-selected-count");
const inspirationImageInput = document.querySelector("#inspiration-image-input");
const inspirationPreviewOverlay = document.querySelector("#inspiration-preview-overlay");
const inspirationPreviewClose = document.querySelector("#inspiration-preview-close");
const inspirationPreviewMedia = document.querySelector("#inspiration-preview-media");
const inspirationPreviewImage = document.querySelector("#inspiration-preview-image");
const inspirationPreviewPlay = document.querySelector("#inspiration-preview-play");
const inspirationPreviewType = document.querySelector("#inspiration-preview-type");
const inspirationPreviewTitle = document.querySelector("#inspiration-preview-title");
const inspirationPreviewMeta = document.querySelector("#inspiration-preview-meta");
const inspirationPreviewNote = document.querySelector("#inspiration-preview-note");
const inspirationPreviewCollectionList = document.querySelector("#inspiration-preview-collection-list");
const inspirationReturnSource = document.querySelector("#inspiration-return-source");
const inspirationRemoveCard = document.querySelector("#inspiration-remove-card");
const manageInspirationCollectionButton = document.querySelector("#manage-inspiration-collection");
const noteEditorOverlay = document.querySelector("#note-editor-overlay");
const noteEditorClose = document.querySelector("#note-editor-close");
const noteEditorTitle = document.querySelector("#note-editor-title");
const noteTitleInput = document.querySelector("#note-title-input");
const noteBodyInput = document.querySelector("#note-body-input");
const noteCollectionOptions = document.querySelector("#note-collection-options");
const noteSaveState = document.querySelector("#note-save-state");
const finishNoteEditorButton = document.querySelector("#finish-note-editor");
const collectionEditorOverlay = document.querySelector("#collection-editor-overlay");
const collectionEditorClose = document.querySelector("#collection-editor-close");
const collectionEditorForm = document.querySelector("#collection-editor-form");
const collectionEditorTitle = document.querySelector("#collection-editor-title");
const collectionEditorIntro = document.querySelector("#collection-editor-intro");
const collectionNameInput = document.querySelector("#collection-name-input");
const collectionDescriptionInput = document.querySelector("#collection-description-input");
const collectionNameCount = document.querySelector("#collection-name-count");
const collectionDescriptionCount = document.querySelector("#collection-description-count");
const collectionEditorError = document.querySelector("#collection-editor-error");
const cancelCollectionEditorButton = document.querySelector("#cancel-collection-editor");
const saveInspirationCollectionButton = document.querySelector("#save-inspiration-collection");
const deleteInspirationCollectionButton = document.querySelector("#delete-inspiration-collection");
const collectionDeleteOverlay = document.querySelector("#collection-delete-overlay");
const cancelCollectionDeleteButton = document.querySelector("#cancel-collection-delete");
const confirmCollectionDeleteButton = document.querySelector("#confirm-collection-delete");
const archiveCollectionDrop = document.querySelector("#archive-collection-drop");
const archiveDropList = document.querySelector("#archive-drop-list");

function showToast(message) {
  toast.textContent = message;
  toast.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.remove("show"), 1800);
}

function hasSeenNewUserGuide() {
  try {
    return localStorage.getItem(newUserGuideStorageKey) === "true";
  } catch {
    return false;
  }
}

function rememberNewUserGuide() {
  try {
    localStorage.setItem(newUserGuideStorageKey, "true");
  } catch {
    // 本地记忆失败时不影响用户继续使用软件。
  }
}

function readLightAccountProfile() {
  try {
    const stored = localStorage.getItem(lightAccountStorageKey);
    const profile = stored ? JSON.parse(stored) : null;
    const displayName = String(profile?.displayName || "").trim();
    const email = String(profile?.email || "").trim();
    if (!displayName || !email) return null;
    return {
      displayName,
      email,
      updatedAt: profile.updatedAt || new Date().toISOString(),
    };
  } catch {
    return null;
  }
}

function saveLightAccountProfile(profile) {
  lightAccountProfile = {
    displayName: String(profile.displayName || "").trim(),
    email: String(profile.email || "").trim(),
    updatedAt: new Date().toISOString(),
  };
  try {
    localStorage.setItem(lightAccountStorageKey, JSON.stringify(lightAccountProfile));
  } catch {
    showToast("本机账号没有保存成功，请稍后再试");
  }
  renderLightAccountProfile();
}

function clearLightAccountProfile() {
  lightAccountProfile = null;
  try {
    localStorage.removeItem(lightAccountStorageKey);
  } catch {
    // 本机账号状态清理失败时，不影响拉片资料使用。
  }
  renderLightAccountProfile();
}

function renderLightAccountProfile() {
  const hasProfile = Boolean(lightAccountProfile?.displayName && lightAccountProfile?.email);
  if (accountStatusPill) {
    accountStatusPill.textContent = hasProfile ? "本机已设置" : "可选登录";
    accountStatusPill.classList.toggle("ready", hasProfile);
    accountStatusPill.classList.toggle("later", !hasProfile);
  }
  if (accountCardSummary) {
    accountCardSummary.textContent = hasProfile
      ? `当前本机账号：${lightAccountProfile.displayName} · ${lightAccountProfile.email}。未来接入云端后，可继续升级为正式登录。`
      : "不登录也能完整使用本机拉片。登录入口先作为轻账号地基，后续用于云端备份、换机恢复和会员能力。";
  }
  if (openAccountDialogButton) {
    openAccountDialogButton.textContent = hasProfile ? "修改本机轻账号" : "设置本机轻账号";
  }
  if (clearAccountProfileButton) {
    clearAccountProfileButton.hidden = !hasProfile;
  }
  if (userCardTitle) {
    userCardTitle.textContent = hasProfile ? lightAccountProfile.displayName : "我的工作台";
  }
  if (userCardDetail) {
    userCardDetail.textContent = hasProfile ? "本机轻账号" : "个人空间";
  }
}

function openAccountDialog() {
  if (!accountOverlay) return;
  if (accountDisplayNameInput) accountDisplayNameInput.value = lightAccountProfile?.displayName || "";
  if (accountEmailInput) accountEmailInput.value = lightAccountProfile?.email || "";
  if (accountFormError) {
    accountFormError.hidden = true;
    accountFormError.textContent = "";
  }
  accountOverlay.hidden = false;
  window.setTimeout(() => (accountDisplayNameInput || accountEmailInput)?.focus(), 30);
}

function closeAccountDialog() {
  if (accountOverlay) accountOverlay.hidden = true;
}

function isValidEmail(value) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(value || "").trim());
}

function showLaunchScreen() {
  if (!launchScreen) return;
  launchScreen.hidden = false;
  window.requestAnimationFrame(() => {
    launchScreen.classList.add("is-visible");
  });
}

function closeLaunchScreen({ openGuide = false, rememberGuide = false } = {}) {
  if (launchScreen) {
    launchScreen.classList.remove("is-visible");
    window.setTimeout(() => {
      launchScreen.hidden = true;
    }, 260);
  }
  if (openGuide) {
    window.setTimeout(() => openNewUserGuide({ remember: rememberGuide }), 300);
  }
}

function finishOpeningSplash() {
  if (!openingSplash) {
    showLaunchScreen();
    return;
  }
  openingSplash.classList.add("is-finished");
  window.setTimeout(() => {
    openingSplash.hidden = true;
    showLaunchScreen();
  }, 620);
}

function initializeOpeningExperience() {
  window.setTimeout(finishOpeningSplash, 2300);
}

function openNewUserGuide({ remember = false } = {}) {
  if (remember) rememberNewUserGuide();
  openPage("library");
  if (newUserGuideOverlay) newUserGuideOverlay.hidden = false;
}

function closeNewUserGuide({ remember = true } = {}) {
  if (remember) rememberNewUserGuide();
  if (newUserGuideOverlay) newUserGuideOverlay.hidden = true;
}

function shouldShowFirstGuide() {
  return !hasSeenNewUserGuide();
}

async function handleLaunchContinue() {
  const openGuide = shouldShowFirstGuide();
  closeLaunchScreen({ openGuide, rememberGuide: openGuide });
  const project = currentLocalProject || currentLibraryProjects()[0];
  if (project && !project.demo) {
    await openLibraryProject(project);
    return;
  }
  openPage("library");
}

async function handleGuideAction(action) {
  closeNewUserGuide();
  if (action === "new-project") {
    await importLocalVideo();
    return;
  }
  if (action === "continue") {
    const project = currentLocalProject || currentLibraryProjects()[0];
    if (project) {
      await openLibraryProject(project);
      return;
    }
    openPage("library");
    return;
  }
  if (["workbench", "archive", "export"].includes(action)) {
    openPage(action);
  }
}

const demoLibraryProjects = [
  {
    name: "潮汐之后",
    filePath: "/preview/潮汐之后.mov",
    fileUrl: "",
    duration: 7458,
    updatedAt: "2026-06-08T21:36:00.000Z",
    analysis: {
      mode: "local",
      cutPoints: Array.from({ length: 187 }, (_, index) => index * 40).concat(7458),
      shotData: {
        "shot-0": {
          size: "中景",
          angle: "平视",
          movement: "固定",
          note: "正在整理“咖啡馆重逢”段落的人物调度与声音关系。",
        },
      },
    },
    cover: "./assets/still-07.png",
    demo: true,
  },
  {
    name: "雨幕计划",
    filePath: "/preview/雨幕计划.mov",
    fileUrl: "",
    duration: 96,
    updatedAt: "2026-06-08T18:10:00.000Z",
    analysis: { mode: "manual", cutPoints: [0, 12, 25, 44, 70, 96], shotData: {} },
    cover: "./assets/still-05.png",
    demo: true,
  },
  {
    name: "无人知晓的房间",
    filePath: "/preview/无人知晓的房间.mov",
    fileUrl: "",
    duration: 1122,
    updatedAt: "2026-06-07T22:40:00.000Z",
    analysis: { mode: "manual", cutPoints: [0, 140, 260, 480, 760, 1122], shotData: {} },
    cover: "./assets/still-09.png",
    demo: true,
  },
];

function formatLibraryDate(value) {
  const date = value ? new Date(value) : null;
  if (!date || Number.isNaN(date.getTime())) return "暂无记录";
  const now = new Date();
  const isToday = date.toDateString() === now.toDateString();
  const time = date.toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit" });
  return isToday ? `今天 ${time}` : `${date.toLocaleDateString("zh-CN")} ${time}`;
}

function shotsForProject(project) {
  const points = Array.isArray(project?.analysis?.cutPoints)
    ? project.analysis.cutPoints.map(Number).filter(Number.isFinite).sort((a, b) => a - b)
    : [];
  return points.length >= 2
    ? points.slice(0, -1).map((start, index) => ({
        key: shotKey(start),
        index,
        start,
        end: points[index + 1],
      }))
    : [];
}

function statsForProject(project) {
  const shots = shotsForProject(project);
  const shotData = project?.analysis?.shotData || {};
  const noteCount = shots.filter((shot) => String(shotData[shot.key]?.note || "").trim()).length;
  const frames = archiveFrames.filter((record) => record.sourceFilePath === project?.filePath);
  const clips = archiveClips.filter((record) => record.sourceFilePath === project?.filePath);
  const progress = shots.length
    ? Math.max(8, Math.min(100, Math.round((noteCount / shots.length) * 100)))
    : project?.analysis ? 20 : 0;
  return {
    shots,
    shotCount: shots.length,
    noteCount,
    frameCount: frames.length,
    clipCount: clips.length,
    progress,
  };
}

function coverForProject(project) {
  if (project?.cover) return project.cover;
  const representative = Object.values(project?.analysis?.representativeFrames || {})
    .find((frame) => frame?.imageUrl);
  if (representative?.imageUrl) return cacheBustedImageUrl(representative.imageUrl, representative.updatedAt);
  const frame = archiveFrames.find((record) => record.sourceFilePath === project?.filePath);
  if (frame?.imageUrl) return frame.imageUrl;
  const clip = archiveClips.find((record) => record.sourceFilePath === project?.filePath);
  return clip?.imageUrl || "";
}

function currentLibraryProjects() {
  const records = projectLibrary.length ? [...projectLibrary] : [...demoLibraryProjects];
  if (currentLocalProject && !records.some((project) => project.filePath === currentLocalProject.filePath)) {
    records.unshift(currentLocalProject);
  }
  return records
    .filter((project) => !isRemovedLibraryProject(project))
    .sort((a, b) => String(b.updatedAt || "").localeCompare(String(a.updatedAt || "")));
}

function normalizeLibraryCategory(category, index = 0) {
  const id = String(category?.id || "").trim();
  const name = String(category?.name || category?.label || "").trim();
  if (!id || !name) return null;
  const color = libraryCategoryColorCycle.includes(category?.color)
    ? category.color
    : libraryCategoryColorCycle[index % libraryCategoryColorCycle.length];
  return {
    id,
    name,
    color,
    builtIn: Boolean(category?.builtIn || defaultLibraryCategoryIds.has(id)),
  };
}

function mergeLibraryCategories(records = []) {
  const merged = new Map();
  defaultLibraryCategories.forEach((category) => {
    merged.set(category.id, { ...category });
  });
  records.forEach((record, index) => {
    const category = normalizeLibraryCategory(record, index + defaultLibraryCategories.length);
    if (!category) return;
    const existing = merged.get(category.id);
    merged.set(category.id, existing ? { ...existing, ...category, builtIn: existing.builtIn || category.builtIn } : category);
  });
  return Array.from(merged.values());
}

function readLocalLibraryCategories() {
  try {
    const stored = localStorage.getItem(libraryCategoryStorageKey);
    const records = stored ? JSON.parse(stored) : [];
    return Array.isArray(records) ? records : [];
  } catch {
    return [];
  }
}

function saveLocalLibraryCategories(records = libraryCategories) {
  try {
    const customCategories = records.filter((category) => !defaultLibraryCategoryIds.has(category.id));
    localStorage.setItem(libraryCategoryStorageKey, JSON.stringify(customCategories));
  } catch {
    // 本地预览环境保存失败时，不影响当前页面继续使用。
  }
}

function readRemovedLibraryProjectPaths() {
  try {
    const stored = localStorage.getItem(removedLibraryProjectsStorageKey);
    const records = stored ? JSON.parse(stored) : [];
    return Array.isArray(records) ? records.filter(Boolean) : [];
  } catch {
    return [];
  }
}

function saveRemovedLibraryProjectPaths() {
  try {
    localStorage.setItem(
      removedLibraryProjectsStorageKey,
      JSON.stringify(Array.from(removedLibraryProjectPaths))
    );
  } catch {
    // 本地预览环境保存失败时，不影响当前页面继续使用。
  }
}

function isRemovedLibraryProject(project) {
  return Boolean(project?.filePath && removedLibraryProjectPaths.has(project.filePath));
}

function rememberRemovedLibraryProject(project) {
  if (!project?.filePath) return;
  removedLibraryProjectPaths.add(project.filePath);
  saveRemovedLibraryProjectPaths();
}

function restoreRemovedLibraryProject(project) {
  if (!project?.filePath || !removedLibraryProjectPaths.has(project.filePath)) return;
  removedLibraryProjectPaths.delete(project.filePath);
  saveRemovedLibraryProjectPaths();
}

function projectCategoryById(categoryId) {
  return libraryCategories.find((category) => category.id === categoryId);
}

function libraryCategoryLabel(category) {
  return projectCategoryById(category)?.name || "未分类";
}

function currentLibraryCategoryButtons() {
  return libraryCategoryList
    ? Array.from(libraryCategoryList.querySelectorAll("[data-library-category]"))
    : [];
}

function bindLibraryCategoryButton(button, categoryId) {
  button.addEventListener("click", () => {
    openLibraryCategory(categoryId);
  });
  button.addEventListener("dragenter", (event) => {
    if (!draggedLibraryProject) return;
    event.preventDefault();
    button.classList.add("drag-over");
  });
  button.addEventListener("dragover", (event) => {
    if (!draggedLibraryProject) return;
    event.preventDefault();
    button.classList.add("drag-over");
    event.dataTransfer.dropEffect = "copy";
  });
  button.addEventListener("dragleave", () => {
    button.classList.remove("drag-over");
  });
  button.addEventListener("drop", async (event) => {
    if (!draggedLibraryProject) return;
    event.preventDefault();
    button.classList.remove("drag-over");
    await assignProjectCategory(draggedLibraryProject, categoryId);
  });
}

function renderLibraryCategoryButtons(projects = currentLibraryProjects()) {
  if (!libraryCategoryList) return;
  const counts = projects.reduce((summary, project) => {
    if (project?.category && projectCategoryById(project.category)) {
      summary[project.category] = (summary[project.category] || 0) + 1;
    }
    return summary;
  }, {});

  const buttons = libraryCategories.map((category) => {
    const button = document.createElement("button");
    button.className = "mini-nav";
    button.type = "button";
    button.dataset.libraryCategory = category.id;
    button.classList.toggle("active", activeProjectCategory === category.id);

    const dot = document.createElement("span");
    dot.className = `dot ${category.color || "blue"}`;
    const label = document.createElement("span");
    label.textContent = category.name;
    const count = document.createElement("b");
    count.textContent = String(counts[category.id] || 0);

    button.append(dot, label, count);
    bindLibraryCategoryButton(button, category.id);
    return button;
  });
  libraryCategoryList.replaceChildren(...buttons);
}

function updateLibraryCategoryButtons(projects) {
  renderLibraryCategoryButtons(projects);
}

function finishLibraryProjectDrag(card = null) {
  if (card) card.classList.remove("dragging");
  document.body.classList.remove("library-drag-active");
  currentLibraryCategoryButtons().forEach((button) => button.classList.remove("drag-over"));
  window.setTimeout(() => {
    draggedLibraryProject = null;
  }, 0);
}

function beginLibraryProjectDrag(project, card, event) {
  if (!project || project.demo) {
    event.preventDefault();
    return;
  }
  draggedLibraryProject = project;
  card.classList.add("dragging");
  document.body.classList.add("library-drag-active");
  event.dataTransfer.effectAllowed = "copy";
  event.dataTransfer.setData("text/plain", project.filePath);
}

async function assignProjectCategory(project, category) {
  if (!project || project.demo) {
    showToast("演示项目不能放入分类");
    return;
  }
  if (!projectCategoryById(category)) return;

  const updatedProject = { ...project, category };
  if (window.cinemaDesktop?.updateProjectCategory) {
    const result = await window.cinemaDesktop.updateProjectCategory({
      filePath: project.filePath,
      category,
    });
    if (result?.error) {
      showToast(result.error);
      return;
    }
    projectLibrary = Array.isArray(result?.projects)
      ? result.projects
      : projectLibrary.map((record) => (
          record.filePath === project.filePath ? updatedProject : record
        ));
    if (currentLocalProject?.filePath === project.filePath) {
      currentLocalProject = result?.project || updatedProject;
    }
  } else {
    projectLibrary = projectLibrary.map((record) => (
      record.filePath === project.filePath ? updatedProject : record
    ));
    if (!projectLibrary.some((record) => record.filePath === project.filePath)) {
      projectLibrary.unshift(updatedProject);
    }
    if (currentLocalProject?.filePath === project.filePath) {
      currentLocalProject = updatedProject;
    }
  }

  activeProjectCategory = category;
  librarySearchQuery = "";
  if (globalSearchInput) globalSearchInput.value = "";
  libraryExpanded = true;
  openPage("library", { preserveProjectCategory: true });
  showToast(`已放入「${libraryCategoryLabel(category)}」`);
}

function renderLibraryPageMode(projects, visibleProjects) {
  const category = projectCategoryById(activeProjectCategory);
  const categoryMode = Boolean(category);
  libraryPage?.classList.toggle("library-category-mode", categoryMode);
  const isLibraryPageActive = document.querySelector(".page.active")?.id === "library-page";
  appShell?.classList.toggle("library-search-visible", isLibraryPageActive && !categoryMode);

  if (categoryMode) {
    navItems.forEach((item) => item.classList.toggle("active", false));
    if (pageTitle) pageTitle.textContent = "我的分类";
    if (libraryCategoryOverview) libraryCategoryOverview.hidden = false;
    if (libraryCategoryTitle) libraryCategoryTitle.textContent = category.name;
    if (libraryCategoryDescription) {
      const count = visibleProjects.length;
      libraryCategoryDescription.textContent = count
        ? `${count} 部影片已放入这个分类，点击影片即可继续拉片。`
        : "这个分类还没有影片，把影片库最近项目拖到左侧分类即可加入。";
    }
    if (librarySectionTitle) librarySectionTitle.textContent = `${category.name}影片`;
    if (librarySectionDescription) librarySectionDescription.textContent = "这个分类下的全部影片";
    return;
  }

  if (document.querySelector(".page.active")?.id === "library-page") {
    navItems.forEach((item) => item.classList.toggle("active", item.dataset.page === "library"));
    if (pageTitle) pageTitle.textContent = pageNames.library;
  }
  if (libraryCategoryOverview) libraryCategoryOverview.hidden = true;
  if (librarySectionTitle) librarySectionTitle.textContent = "最近项目";
  if (librarySectionDescription) librarySectionDescription.textContent = "按最近编辑时间排列";
  updateContinueProject(projects[0]);
}

function openLibraryCategory(categoryId) {
  if (!projectCategoryById(categoryId)) return;
  activeProjectCategory = categoryId;
  librarySearchQuery = "";
  libraryExpanded = true;
  if (globalSearchInput) globalSearchInput.value = "";
  openPage("library", { preserveProjectCategory: true });
}

function openLibraryHome() {
  activeProjectCategory = "all";
  libraryExpanded = false;
  renderLibraryProjects();
}

function showLibraryCategoryError(message) {
  if (!libraryCategoryError) return;
  libraryCategoryError.textContent = message;
  libraryCategoryError.hidden = !message;
}

function openLibraryCategoryEditor() {
  showLibraryCategoryError("");
  if (libraryCategoryNameInput) libraryCategoryNameInput.value = "";
  if (libraryCategoryEditorOverlay) libraryCategoryEditorOverlay.hidden = false;
  window.setTimeout(() => libraryCategoryNameInput?.focus(), 80);
}

function closeLibraryCategoryEditor() {
  showLibraryCategoryError("");
  if (libraryCategoryNameInput) libraryCategoryNameInput.value = "";
  if (libraryCategoryEditorOverlay) libraryCategoryEditorOverlay.hidden = true;
}

function localCategoryRecord(name) {
  const now = new Date().toISOString();
  const customCount = libraryCategories.filter((category) => !defaultLibraryCategoryIds.has(category.id)).length;
  return {
    id: `category-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 7)}`,
    name,
    color: libraryCategoryColorCycle[customCount % libraryCategoryColorCycle.length],
    builtIn: false,
    createdAt: now,
    updatedAt: now,
  };
}

async function createLibraryCategory(name) {
  const trimmedName = String(name || "").trim();
  if (!trimmedName) {
    showLibraryCategoryError("请先填写分类名称");
    return;
  }
  const nameExists = libraryCategories.some((category) => category.name === trimmedName);
  if (nameExists) {
    showLibraryCategoryError("这个分类已经存在，换一个名字试试");
    return;
  }

  let createdCategory = null;
  if (window.cinemaDesktop?.createProjectCategory) {
    const result = await window.cinemaDesktop.createProjectCategory({ name: trimmedName });
    if (result?.error) {
      showLibraryCategoryError(result.error);
      return;
    }
    libraryCategories = mergeLibraryCategories(result?.categories || []);
    createdCategory = normalizeLibraryCategory(result?.category);
  } else {
    createdCategory = localCategoryRecord(trimmedName);
    libraryCategories = mergeLibraryCategories([...readLocalLibraryCategories(), createdCategory]);
    saveLocalLibraryCategories(libraryCategories);
  }

  closeLibraryCategoryEditor();
  renderLibraryCategoryButtons(currentLibraryProjects());
  if (createdCategory?.id) {
    openLibraryCategory(createdCategory.id);
    showToast(`已新建「${createdCategory.name}」`);
  }
}

function updateContinueProject(project) {
  const target = project || currentLibraryProjects()[0];
  if (!target) return;
  const stats = statsForProject(target);
  const cover = coverForProject(target);
  document.querySelector(".continue-copy h3").textContent = `《${target.name}》`;
  document.querySelector(".continue-copy .film-meta").textContent = target.demo
    ? "剧情长片 · 124分钟 · 已分析 186 个镜头"
    : `本地影片 · ${target.duration ? formatTimecode(target.duration).slice(0, 8) : "读取中"} · ${stats.shotCount || 0} 个镜头`;
  document.querySelector(".continue-copy .film-note").textContent = stats.noteCount
    ? `已填写 ${stats.noteCount} 条导演笔记，可继续完善镜头分析。`
    : target.analysis?.mode === "local"
      ? "本地分析已经完成，可以进入工作台检查和修正切点。"
      : "影片已导入，可以进入工作台开始播放和手动拉片。";
  if (continueProgressLabel) continueProgressLabel.textContent = `完成度 ${stats.progress}%`;
  if (continueUpdatedLabel) continueUpdatedLabel.textContent = `上次编辑：${formatLibraryDate(target.updatedAt)}`;
  if (continueProgressBar) continueProgressBar.style.width = `${stats.progress}%`;
  if (continueFilmType) continueFilmType.textContent = target.demo ? "演示项目" : "正在拉片";
  if (continueCover) {
    continueCover.hidden = !cover;
    if (cover) continueCover.src = cover;
    continueCover.alt = `《${target.name}》封面`;
  }
  if (continueCoverPlaceholder) {
    continueCoverPlaceholder.hidden = Boolean(cover);
    continueCoverPlaceholder.textContent = target.name.slice(0, 1) || "影";
  }
  const statValues = document.querySelectorAll(".project-stats strong");
  if (statValues[0]) statValues[0].textContent = String(stats.shotCount || (target.demo ? 186 : 0));
  if (statValues[1]) statValues[1].textContent = String(stats.frameCount || (target.demo ? 42 : 0));
  if (statValues[2]) statValues[2].textContent = String(stats.clipCount || (target.demo ? 9 : 0));
}

async function openLibraryProject(project) {
  if (!project) return;
  if (project.demo) {
    openPage("workbench");
    showToast("演示项目仅用于预览，导入本地影片后会显示真实资料");
    return;
  }
  if (currentLocalProject?.filePath === project.filePath) {
    applyLocalProject(currentLocalProject, true);
    return;
  }
  if (window.cinemaDesktop?.openProjectFromLibrary) {
    const opened = await window.cinemaDesktop.openProjectFromLibrary({ filePath: project.filePath });
    if (opened?.error) {
      showToast(opened.error);
      return;
    }
    applyLocalProject(opened, true);
    return;
  }
  showToast("请重新导入这部影片后继续拉片");
}

function closeProjectCardMenus(exceptMenu = null) {
  document.querySelectorAll(".project-card-menu").forEach((menu) => {
    if (menu !== exceptMenu) menu.hidden = true;
  });
}

function clearActiveProjectIfRemoved(project) {
  if (currentLocalProject?.filePath !== project?.filePath) return;
  currentLocalProject = null;
  manualAnalysis = { cutPoints: [], shotData: {} };
  selectedManualShotKey = null;
  appShell.classList.remove("local-project");
  localVideo.pause();
  localVideo.removeAttribute("src");
  localVideo.load();
  videoStage?.classList.remove("has-local-video");
}

async function removeLibraryProject(project) {
  if (!project || project.demo) {
    showToast("演示项目不能从影片库移除");
    return;
  }
  const confirmed = window.confirm(
    `从影片库移除《${project.name}》？\n\n这只会移除软件里的影片记录，不会删除你电脑里的原始影片。`
  );
  if (!confirmed) return;

  if (window.cinemaDesktop?.removeProjectFromLibrary) {
    const result = await window.cinemaDesktop.removeProjectFromLibrary({
      filePath: project.filePath,
    });
    if (result?.error) {
      showToast(result.error);
      return;
    }
    projectLibrary = Array.isArray(result?.projects)
      ? result.projects
      : projectLibrary.filter((record) => record.filePath !== project.filePath);
  } else {
    projectLibrary = projectLibrary.filter((record) => record.filePath !== project.filePath);
  }

  rememberRemovedLibraryProject(project);
  projectLibrary = projectLibrary.filter((record) => record.filePath !== project.filePath);
  clearActiveProjectIfRemoved(project);
  renderLibraryProjects();
  showToast("已从影片库移除，本地原片没有删除");
}

function createLibraryProjectCard(project) {
  const stats = statsForProject(project);
  const cover = coverForProject(project);
  const card = document.createElement("article");
  card.className = "project-card";
  card.tabIndex = 0;
  card.dataset.projectName = project.name;
  card.dataset.category = project.category || "";
  card.dataset.search = [project.name, project.demo ? "演示项目" : "本地影片"].join(" ").toLowerCase();
  card.draggable = !project.demo;

  const poster = document.createElement("div");
  poster.className = "poster-frame";
  if (cover) {
    const image = document.createElement("img");
    image.src = cover;
    image.alt = `《${project.name}》封面`;
    poster.append(image);
  } else {
    const placeholder = document.createElement("span");
    placeholder.className = "library-card-placeholder";
    placeholder.textContent = project.name.slice(0, 1) || "影";
    poster.append(placeholder);
  }
  const duration = document.createElement("span");
  duration.className = "duration";
  duration.textContent = project.duration ? formatTimecode(project.duration).slice(0, 8) : "待读取";
  poster.append(duration);

  const copy = document.createElement("div");
  copy.className = "project-copy";
  const status = document.createElement("span");
  status.className = `status-dot ${stats.shotCount ? "working" : "paused"}`;
  const text = document.createElement("div");
  const title = document.createElement("h3");
  title.textContent = project.name;
  const meta = document.createElement("p");
  const categoryLabel = project.category ? `${libraryCategoryLabel(project.category)} · ` : "";
  meta.textContent = project.demo
    ? "演示项目"
    : `${categoryLabel}${stats.shotCount || 0} 镜 · ${stats.frameCount} 静帧 · ${stats.clipCount} 片段`;
  text.append(title, meta);
  const more = document.createElement("button");
  more.type = "button";
  more.setAttribute("aria-label", "更多");
  more.textContent = "•••";
  const menu = document.createElement("div");
  menu.className = "project-card-menu";
  menu.hidden = true;
  const boardButton = document.createElement("button");
  boardButton.type = "button";
  boardButton.textContent = "预览画板";
  const removeButton = document.createElement("button");
  removeButton.type = "button";
  removeButton.className = "danger";
  removeButton.textContent = "从影片库移除";
  menu.append(boardButton, removeButton);
  copy.append(status, text, more);
  card.append(poster, copy, menu);
  let wasDragged = false;
  card.addEventListener("dragstart", (event) => {
    wasDragged = true;
    beginLibraryProjectDrag(project, card, event);
  });
  card.addEventListener("dragend", () => {
    finishLibraryProjectDrag(card);
    window.setTimeout(() => {
      wasDragged = false;
    }, 80);
  });
  card.addEventListener("click", () => {
    if (wasDragged) return;
    openLibraryProject(project);
  });
  card.addEventListener("keydown", (event) => {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      openLibraryProject(project);
    }
  });
  more.addEventListener("click", (event) => {
    event.stopPropagation();
    const shouldOpen = menu.hidden;
    closeProjectCardMenus(shouldOpen ? menu : null);
    menu.hidden = !shouldOpen;
  });
  more.addEventListener("keydown", (event) => event.stopPropagation());
  menu.addEventListener("click", (event) => event.stopPropagation());
  menu.addEventListener("keydown", (event) => event.stopPropagation());
  boardButton.addEventListener("click", async (event) => {
    event.stopPropagation();
    menu.hidden = true;
    await openProjectStructureBoard(project);
  });
  removeButton.addEventListener("click", async (event) => {
    event.stopPropagation();
    menu.hidden = true;
    await removeLibraryProject(project);
  });
  return card;
}

function renderLibraryProjects() {
  if (!projectGrid) return;
  if (activeProjectCategory !== "all" && !projectCategoryById(activeProjectCategory)) {
    activeProjectCategory = "all";
  }
  const query = librarySearchQuery.trim().toLowerCase();
  const projects = currentLibraryProjects();
  updateLibraryCategoryButtons(projects);
  const visible = projects.filter((project) => {
    const matchesCategory = activeProjectCategory === "all"
      || project.category === activeProjectCategory;
    const filmName = String(project.name || "").toLowerCase();
    return matchesCategory && (!query || filmName.includes(query));
  });
  renderLibraryPageMode(projects, visible);
  const categoryMode = activeProjectCategory !== "all";
  const shouldCollapse = !categoryMode && !libraryExpanded && !query;
  const displayProjects = shouldCollapse ? visible.slice(0, 3) : visible;
  projectGrid.replaceChildren(...displayProjects.map(createLibraryProjectCard));
  if (viewAllProjectsButton) {
    const canExpandDefaultList = !categoryMode && !query && visible.length > 3;
    viewAllProjectsButton.hidden = !canExpandDefaultList;
    viewAllProjectsButton.textContent = libraryExpanded ? "收起 ↑" : "查看全部 →";
  }
  if (!visible.length) {
    const empty = document.createElement("article");
    empty.className = "project-card library-empty-card";
    empty.innerHTML = activeProjectCategory === "all"
      ? "<div><strong>没有找到相关影片</strong><p>换一个影片名试试。</p></div>"
      : "<div><strong>这个分类还没有影片</strong><p>把最近项目拖到左侧分类里即可归档。</p></div>";
    projectGrid.append(empty);
  }
}

async function refreshLibraryCategories() {
  if (window.cinemaDesktop?.getProjectCategories) {
    const records = await window.cinemaDesktop.getProjectCategories();
    libraryCategories = mergeLibraryCategories(Array.isArray(records) ? records : []);
    return;
  }
  libraryCategories = mergeLibraryCategories(readLocalLibraryCategories());
}

async function refreshProjectLibrary() {
  await refreshLibraryCategories();
  if (window.cinemaDesktop?.getProjectLibrary) {
    const records = await window.cinemaDesktop.getProjectLibrary();
    projectLibrary = Array.isArray(records) ? records : [];
  }
  renderLibraryProjects();
}

function closeProjectOverview() {
  if (projectOverviewOverlay) projectOverviewOverlay.hidden = true;
}

function openProjectOverview() {
  const project = currentLocalProject || currentLibraryProjects()[0];
  if (!project) {
    showToast("请先导入一部影片");
    return;
  }
  const stats = statsForProject(project);
  if (overviewShotCount) overviewShotCount.textContent = String(stats.shotCount || 0);
  if (overviewFrameCount) overviewFrameCount.textContent = String(stats.frameCount || 0);
  if (overviewClipCount) overviewClipCount.textContent = String(stats.clipCount || 0);
  if (overviewNoteProgress) overviewNoteProgress.textContent = `${stats.progress}%`;
  if (overviewStatus) {
    overviewStatus.textContent = stats.shotCount
      ? "已建立拉片项目"
      : "已导入，等待开始拉片";
  }
  if (overviewStatusDetail) {
    overviewStatusDetail.textContent = stats.shotCount
      ? `当前已有 ${stats.shotCount} 个镜头，${stats.noteCount} 条导演笔记。`
      : "可以进入工作台选择本地分析，或直接开始手动拉片。";
  }
  if (overviewUpdated) overviewUpdated.textContent = formatLibraryDate(project.updatedAt);
  const title = document.querySelector("#project-overview-title");
  if (title) title.textContent = `《${project.name}》影片总览`;
  if (projectOverviewOverlay) projectOverviewOverlay.hidden = false;
}

function renderAITranslationStatus(configured) {
  aiTranslationConfigured = Boolean(configured);
  openAITranslationButton?.classList.toggle("configured", aiTranslationConfigured);
  const completedTranslation = manualAnalysis?.subtitleTranslation?.status === "complete"
    ? manualAnalysis.subtitleTranslation
    : null;
  if (aiTranslationStatus) {
    aiTranslationStatus.textContent = completedTranslation
      ? `已翻译 · ${completedTranslation.translatedCount || 0} 条中英字幕`
      : aiTranslationConfigured
        ? "已设置 · 点击后手动开始翻译"
        : "未设置 · 只上传英文字幕文字";
  }
  if (aiProviderState) {
    aiProviderState.textContent = aiTranslationConfigured ? "已安全保存" : "未设置";
    aiProviderState.classList.toggle("configured", aiTranslationConfigured);
  }
  if (removeAITranslationKeyButton) removeAITranslationKeyButton.hidden = !aiTranslationConfigured;
  if (aiTranslationKeyInput) {
    aiTranslationKeyInput.placeholder = aiTranslationConfigured
      ? "需要更换时，请填写新的密钥"
      : "在这里填写新密钥";
  }
  if (aiKeyHint) {
    aiKeyHint.textContent = aiTranslationConfigured
      ? "当前密钥已安全保存在这台电脑，不会在这里重新显示。"
      : "密钥只安全保存在这台电脑，不进入项目文件或备份。";
  }
  renderAITranslationTask();
}

function renderCloudSubtitleStatus(configured) {
  cloudSubtitleConfigured = Boolean(configured);
  openCloudSubtitleButton?.classList.toggle("configured", cloudSubtitleConfigured);
  const extraction = manualAnalysis?.cloudSubtitleExtraction;
  if (cloudSubtitleStatus) {
    cloudSubtitleStatus.textContent = extraction?.status === "complete"
      ? `已提取 · ${extraction.cueCount || 0} 条字幕`
      : extraction?.status === "partial"
        ? `部分提取 · ${extraction.cueCount || 0} 条字幕`
        : cloudSubtitleConfigured
          ? "已设置 · 经济模式手动提取"
          : "未设置 · 经济提取";
  }
  if (cloudProviderState) {
    cloudProviderState.textContent = cloudSubtitleConfigured ? "已安全保存" : "未设置";
    cloudProviderState.classList.toggle("configured", cloudSubtitleConfigured);
  }
  if (removeCloudSubtitleKeyButton) removeCloudSubtitleKeyButton.hidden = !cloudSubtitleConfigured;
  if (cloudSubtitleKeyInput) {
    cloudSubtitleKeyInput.placeholder = cloudSubtitleConfigured
      ? "需要更换时，请填写新的 OpenAI 密钥"
      : "在这里填写 OpenAI 密钥";
  }
  if (cloudKeyHint) {
    cloudKeyHint.textContent = cloudSubtitleConfigured
      ? "当前密钥已安全保存在这台电脑，不会在这里重新显示。"
      : "密钥只安全保存在这台电脑，不进入项目文件或备份。";
  }
  renderCloudSubtitleTask();
}

function renderCloudSubtitleTask(errorMessage = "") {
  if (!startCloudSubtitleButton || !cloudSubtitleTaskTitle || !cloudSubtitleTaskDetail) return;
  const extraction = manualAnalysis?.cloudSubtitleExtraction;
  const cueCount = Number(manualAnalysis?.subtitles?.cueCount) || manualAnalysis?.subtitles?.cues?.length || 0;
  let title = "等待导入影片";
  let detail = "导入影片后，可手动开始经济提取。";
  let buttonText = "开始提取";
  let disabled = true;

  if (isCloudSubtitleRunning) {
    title = "正在云端提取画面字幕";
    detail = "请保持网络连接，完成后会自动写入字幕对白。";
    buttonText = "提取中…";
  } else if (!currentLocalProject) {
    title = "尚未导入影片";
  } else if (!cloudSubtitleConfigured) {
    title = "需要先保存 OpenAI 密钥";
    detail = "保存后再点击开始，才会上传压缩字幕画面并产生费用。";
  } else {
    disabled = false;
    if (["complete", "partial"].includes(extraction?.status)) {
      title = `已提取 ${extraction.cueCount || cueCount} 条字幕`;
      detail = extraction?.status === "partial"
        ? "已保存部分字幕，可以重新提取补齐或覆盖。"
        : "字幕已写入当前拉片项目，可重新提取覆盖。";
      buttonText = "重新提取";
    } else if (manualAnalysis?.subtitles?.found) {
      title = `当前已有 ${cueCount} 条字幕`;
      detail = "如果现有字幕不准，可以用经济模式重新提取并覆盖。";
      buttonText = "云端重新提取";
    } else {
      title = "当前影片未读取到可用字幕";
      detail = "点击后只上传压缩后的字幕区域画面，不上传完整原片。";
    }
  }

  cloudSubtitleTaskTitle.textContent = title;
  cloudSubtitleTaskDetail.textContent = detail;
  startCloudSubtitleButton.textContent = buttonText;
  startCloudSubtitleButton.disabled = disabled || isCloudSubtitleRunning;
  if (cloudSubtitleError) {
    cloudSubtitleError.hidden = !errorMessage;
    cloudSubtitleError.textContent = errorMessage;
  }
  if (!isCloudSubtitleRunning && cloudSubtitleProgress) cloudSubtitleProgress.hidden = true;
}

async function refreshCloudSubtitleStatus() {
  if (!window.cinemaDesktop?.getCloudSubtitleSettings) {
    renderCloudSubtitleStatus(cloudSubtitleConfigured);
    return;
  }
  const result = await window.cinemaDesktop.getCloudSubtitleSettings();
  renderCloudSubtitleStatus(result?.configured);
}

async function openCloudSubtitleDialog() {
  await refreshCloudSubtitleStatus();
  if (cloudSubtitleKeyInput) cloudSubtitleKeyInput.value = "";
  if (cloudSubtitleOverlay) cloudSubtitleOverlay.hidden = false;
  renderCloudSubtitleTask();
  window.setTimeout(
    () => (cloudSubtitleConfigured ? startCloudSubtitleButton : cloudSubtitleKeyInput)?.focus(),
    80
  );
}

function closeCloudSubtitleDialog() {
  if (cloudSubtitleKeyInput) cloudSubtitleKeyInput.value = "";
  if (cloudSubtitleOverlay) cloudSubtitleOverlay.hidden = true;
}

async function applyCloudSubtitleResult(result) {
  const cues = (Array.isArray(result?.cues) ? result.cues : [])
    .map((cue) => ({
      start: Number(cue.start),
      end: Number(cue.end),
      text: String(cue.text || "").trim(),
      confidence: Number(cue.confidence) || 0,
      source: "cloud-ocr",
    }))
    .filter((cue) => Number.isFinite(cue.start) && Number.isFinite(cue.end) && cue.end > cue.start && cue.text);
  if (!cues.length) return false;

  const language = inferSubtitleLanguageFromCues(cues);
  const scannedAt = result?.scannedAt || new Date().toISOString();
  manualAnalysis.subtitles = {
    found: true,
    sourceType: "cloud-ocr",
    sourceName: result?.sourceName || "OpenAI 云端画面字幕提取（经济模式）",
    language: result?.language || language.language,
    isChinese: Boolean(result?.isChinese ?? language.isChinese),
    candidateCount: Number(result?.candidateCount) || 1,
    cueCount: cues.length,
    cues,
    scannedAt,
  };
  manualAnalysis.subtitleTranslation = null;
  manualAnalysis.subtitleEdits = null;
  manualAnalysis.cloudSubtitleExtraction = {
    version: 1,
    provider: result?.provider || "openai",
    model: result?.model || "gpt-5-mini",
    status: result?.error ? "partial" : "complete",
    cueCount: cues.length,
    sampledFrameCount: Number(result?.sampledFrameCount) || 0,
    uploadedFrameCount: Number(result?.uploadedFrameCount) || 0,
    extractedAt: scannedAt,
  };
  updateSubtitleAssignments();
  await saveAnalysisToDisk({
    savingDetail: "正在保存云端字幕结果",
    failureDetail: "云端字幕结果没有保存成功，请重试",
  });
  renderCloudSubtitleStatus(cloudSubtitleConfigured);
  renderAITranslationStatus(aiTranslationConfigured);
  renderSubtitleDialoguePanel();
  refreshReportWorkspace();
  setWorkbenchSideTab("subtitles");
  return true;
}

function isEnglishSubtitleResult(subtitles) {
  if (!subtitles?.found || subtitles.isChinese) return false;
  const language = String(subtitles.language || "").toLowerCase();
  if (language === "en" || language.startsWith("en-") || language === "eng") return true;
  const sample = (subtitles.cues || []).slice(0, 40).map((cue) => cue.text || "").join(" ");
  const letters = [...sample].filter((character) => /\p{L}/u.test(character));
  const latinLetters = letters.filter((character) => /\p{Script=Latin}/u.test(character));
  return latinLetters.length >= 10 && latinLetters.length / Math.max(1, letters.length) >= 0.82;
}

function matchingSubtitleTranslation() {
  const subtitles = manualAnalysis?.subtitles;
  const translation = manualAnalysis?.subtitleTranslation;
  if (
    !subtitles
    || !translation
    || translation.sourceName !== subtitles.sourceName
    || translation.cueCount !== subtitles.cues?.length
  ) {
    return null;
  }
  return translation;
}

function matchingSubtitleEdits() {
  const subtitles = manualAnalysis?.subtitles;
  const edits = manualAnalysis?.subtitleEdits;
  if (
    !subtitles
    || !edits
    || edits.sourceName !== subtitles.sourceName
    || edits.cueCount !== subtitles.cues?.length
    || !edits.byCue
    || typeof edits.byCue !== "object"
  ) {
    return null;
  }
  return edits;
}

function ensureSubtitleEdits() {
  const subtitles = manualAnalysis?.subtitles;
  if (!subtitles) return null;
  let edits = matchingSubtitleEdits();
  if (!edits) {
    edits = {
      version: 1,
      sourceName: subtitles.sourceName || "",
      cueCount: subtitles.cues?.length || 0,
      updatedAt: new Date().toISOString(),
      byCue: {},
    };
    manualAnalysis.subtitleEdits = edits;
  }
  return edits;
}

function subtitleTranslationByCueIndex() {
  return new Map(
    (matchingSubtitleTranslation()?.translations || []).map((item) => [
      Number(item.cueIndex),
      String(item.translatedText || ""),
    ])
  );
}

function subtitleCueDisplayValues(cue, cueIndex) {
  const edit = matchingSubtitleEdits()?.byCue?.[String(cueIndex)] || {};
  const translatedText = subtitleTranslationByCueIndex().get(Number(cueIndex)) || "";
  return {
    originalText: Object.prototype.hasOwnProperty.call(edit, "originalText")
      ? String(edit.originalText || "")
      : String(cue?.text || ""),
    translatedText: Object.prototype.hasOwnProperty.call(edit, "translatedText")
      ? String(edit.translatedText || "")
      : translatedText,
  };
}

function isChineseSubtitleSource(subtitles = manualAnalysis?.subtitles) {
  const language = String(subtitles?.language || "").toLowerCase();
  return Boolean(subtitles?.isChinese || language === "zh" || language.startsWith("zh-"));
}

function containsChineseText(text = "") {
  return /[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]/u.test(String(text || ""));
}

function inferSubtitleLanguageFromCues(cues = []) {
  const sample = cues.slice(0, 80).map((cue) => cue.text || "").join("\n");
  const isChinese = containsChineseText(sample);
  return {
    language: isChinese ? "zh" : "",
    isChinese,
  };
}

function setWorkbenchSideTab(tabName) {
  activeWorkbenchSideTab = ["basic", "subtitles"].includes(tabName) ? tabName : "analysis";
  const basicActive = activeWorkbenchSideTab === "basic";
  const subtitlesActive = activeWorkbenchSideTab === "subtitles";
  const analysisActive = !basicActive && !subtitlesActive;
  directorAnalysisTab?.classList.toggle("active", analysisActive);
  basicSceneTab?.classList.toggle("active", basicActive);
  subtitleDialogueTab?.classList.toggle("active", subtitlesActive);
  directorAnalysisTab?.setAttribute("aria-selected", String(analysisActive));
  basicSceneTab?.setAttribute("aria-selected", String(basicActive));
  subtitleDialogueTab?.setAttribute("aria-selected", String(subtitlesActive));
  if (directorAnalysisPanel) directorAnalysisPanel.hidden = !analysisActive;
  if (basicScenePanel) basicScenePanel.hidden = !basicActive;
  if (subtitleDialoguePanel) subtitleDialoguePanel.hidden = !subtitlesActive;
  analysisPanel?.classList.toggle("subtitle-mode", subtitlesActive);
  analysisPanel?.classList.toggle("basic-mode", basicActive);
  if (basicActive) renderBasicScenePanel();
  if (subtitlesActive) renderSubtitleDialoguePanel();
}

function ensureBasicSceneAnalysis() {
  if (!manualAnalysis || typeof manualAnalysis !== "object") return null;
  if (!manualAnalysis.basicSceneAnalysis || typeof manualAnalysis.basicSceneAnalysis !== "object") {
    manualAnalysis.basicSceneAnalysis = { version: 1, byShot: {} };
  }
  if (
    !manualAnalysis.basicSceneAnalysis.byShot
    || typeof manualAnalysis.basicSceneAnalysis.byShot !== "object"
  ) {
    manualAnalysis.basicSceneAnalysis.byShot = {};
  }
  return manualAnalysis.basicSceneAnalysis;
}

function basicSceneConfidenceLabel(field) {
  if (!field?.value) return { text: "等待识别", state: "review" };
  if (field.source === "manual") return { text: "人工确认", state: "confirmed" };
  const percent = Math.round(Math.max(0, Math.min(1, Number(field.confidence) || 0)) * 100);
  return percent >= 75
    ? { text: `高可信 ${percent}%`, state: "" }
    : { text: `建议检查 ${percent}%`, state: "review" };
}

function renderBasicScenePanel() {
  if (!basicScenePanel || !currentLocalProject || !manualAnalysis) return;
  const shot = currentManualShot();
  const result = shot ? manualAnalysis?.basicSceneAnalysis?.byShot?.[shot.key] : null;
  const fields = ["people", "timeOfDay", "setting"];
  const availableFields = fields.map((key) => result?.[key]).filter((field) => field?.value);
  const manualCount = availableFields.filter((field) => field.source === "manual").length;
  const averageConfidence = availableFields.length
    ? availableFields.reduce((sum, field) => sum + (Number(field.confidence) || 0), 0) / availableFields.length
    : 0;

  if (basicSceneSummary) {
    basicSceneSummary.textContent = availableFields.length
      ? `${availableFields.map((field) => field.value).join(" · ")}`
      : "当前镜头等待本机识别";
  }
  if (basicSceneOverall) {
    basicSceneOverall.classList.toggle("confirmed", manualCount > 0);
    basicSceneOverall.textContent = !availableFields.length
      ? "等待识别"
      : manualCount > 0
      ? (manualCount === availableFields.length ? "已人工确认" : "含人工校正")
      : (averageConfidence >= 0.75 ? "自动识别 · 高可信" : "自动识别 · 建议检查");
  }

  fields.forEach((key) => {
    const field = result?.[key];
    const status = basicSceneConfidenceLabel(field);
    const statusElement = basicScenePanel.querySelector(`[data-basic-confidence="${key}"]`);
    if (statusElement) {
      statusElement.textContent = status.text;
      statusElement.classList.toggle("review", status.state === "review");
      statusElement.classList.toggle("confirmed", status.state === "confirmed");
    }
    basicScenePanel.querySelectorAll(`[data-basic-field="${key}"]`).forEach((button) => {
      button.classList.toggle("selected", button.dataset.basicValue === field?.value);
    });
  });

  if (analyzeBasicScenesButton) {
    analyzeBasicScenesButton.disabled = isBasicSceneAnalyzing;
    analyzeBasicScenesButton.textContent = availableFields.length
      ? "✦ 重新识别全部镜头"
      : "✦ 识别全部镜头";
  }
  if (basicSceneSaveState && !isBasicSceneAnalyzing) {
    basicSceneSaveState.textContent = availableFields.length
      ? "修改会自动保存"
      : "可先自动识别，也可以直接人工选择";
  }
}

async function analyzeBasicScenes({
  shots = manualShots(),
  silent = false,
  onProgress = null,
} = {}) {
  if (isBasicSceneAnalyzing || !currentLocalProject || !manualAnalysis) return false;
  if (!window.cinemaDesktop?.analyzeBasicScenes) {
    if (!silent) showToast("当前是网页预览，安装测试版后可进行本机识别");
    return false;
  }

  const framesReady = await ensureRepresentativeFrames({ shots });
  if (!framesReady) return false;
  const frames = shots.flatMap((shot) => {
    const frame = manualAnalysis.representativeFrames?.[shot.key];
    return frame?.imageUrl ? [{
      shotKey: shot.key,
      imageUrl: frame.imageUrl,
    }] : [];
  });
  if (!frames.length) {
    if (!silent) showToast("当前还没有可以识别的代表静帧");
    return false;
  }

  isBasicSceneAnalyzing = true;
  if (basicSceneProgress) basicSceneProgress.hidden = false;
  renderBasicScenePanel();
  try {
    const result = await window.cinemaDesktop.analyzeBasicScenes(frames, (progress) => {
      const percent = Math.max(0, Math.min(100, Number(progress?.percent) || 0));
      if (basicSceneProgressPercent) basicSceneProgressPercent.textContent = `${percent}%`;
      if (basicSceneProgressBar) basicSceneProgressBar.style.width = `${percent}%`;
      onProgress?.(percent);
    });
    if (!result || result.error) {
      if (!silent) showToast(result?.error || "基础识别没有完成，可以直接人工选择");
      return false;
    }

    const sceneAnalysis = ensureBasicSceneAnalysis();
    Object.entries(result).forEach(([key, automaticResult]) => {
      const existing = sceneAnalysis.byShot[key] || {};
      const merged = { shotKey: key };
      ["people", "timeOfDay", "setting"].forEach((fieldKey) => {
        merged[fieldKey] = existing[fieldKey]?.source === "manual"
          ? existing[fieldKey]
          : automaticResult[fieldKey];
      });
      sceneAnalysis.byShot[key] = merged;
    });
    sceneAnalysis.analyzedAt = new Date().toISOString();
    await saveAnalysisToDisk({
      savingDetail: "正在保存基础识别结果",
      failureDetail: "基础识别结果没有保存成功，请重试",
      quiet: silent,
    });
    renderBasicScenePanel();
    if (!silent) showToast(`基础识别完成，共处理 ${Object.keys(result).length} 个镜头`);
    return true;
  } finally {
    isBasicSceneAnalyzing = false;
    if (basicSceneProgress) basicSceneProgress.hidden = true;
    if (basicSceneProgressPercent) basicSceneProgressPercent.textContent = "0%";
    if (basicSceneProgressBar) basicSceneProgressBar.style.width = "0%";
    renderBasicScenePanel();
  }
}

function renderSubtitleDialoguePanel() {
  if (
    !currentLocalProject
    || !manualAnalysis
    || !subtitleDialogueList
    || !subtitleDialogueEmpty
  ) {
    return;
  }

  const subtitles = manualAnalysis.subtitles;
  const assignedShot = manualAnalysis.subtitleAssignments?.byShot?.[selectedManualShotKey];
  const cues = Array.isArray(assignedShot?.cues) ? assignedShot.cues : [];
  const isChinese = isChineseSubtitleSource(subtitles);

  if (subtitleTabCount) subtitleTabCount.textContent = String(cues.length);
  if (subtitleDialogueCount) subtitleDialogueCount.textContent = `${cues.length} 条字幕`;
  if (subtitleLanguageState) {
    subtitleLanguageState.textContent = isChinese
      ? "中文字幕 · 可直接修正"
      : matchingSubtitleTranslation()
        ? "原文 + 中文译文"
        : "原文 · 中文待填写";
  }
  if (subtitleSource) {
    subtitleSource.textContent = subtitles?.found
      ? `字幕来源：${subtitles.sourceName || "影片内置字幕"}`
      : "字幕来源：当前影片未读取到文字字幕";
    subtitleSource.title = subtitles?.sourceName || "";
  }

  subtitleDialogueList.replaceChildren();
  subtitleDialogueEmpty.hidden = cues.length > 0;
  subtitleDialogueList.hidden = cues.length === 0;

  if (!cues.length) {
    const emptyTitle = subtitleDialogueEmpty.querySelector("strong");
    const emptyCopy = subtitleDialogueEmpty.querySelector("p");
    if (retryReadSubtitlesButton) {
      retryReadSubtitlesButton.hidden = Boolean(subtitles?.found);
      retryReadSubtitlesButton.disabled = false;
    }
    if (emptyTitle) {
      emptyTitle.textContent = subtitles?.found
        ? "当前镜头没有字幕对白"
        : "当前影片没有可读取字幕";
    }
    if (emptyCopy) {
      emptyCopy.textContent = subtitles?.found
        ? "切换到其他镜头，即可查看对应时间范围内的字幕。"
        : "可以重新读取已有字幕，也可以使用上方云端提取画面字幕。";
    }
    return;
  }

  cues.forEach((cue, cueOrder) => {
    const values = subtitleCueDisplayValues(cue, cue.cueIndex);
    const card = document.createElement("article");
    card.className = "subtitle-cue-card";
    card.dataset.cueIndex = String(cue.cueIndex);

    const meta = document.createElement("div");
    meta.className = "subtitle-cue-meta";
    const label = document.createElement("span");
    label.textContent = `对白 ${String(cueOrder + 1).padStart(2, "0")}`;
    const time = document.createElement("time");
    time.textContent = `${formatTimecode(cue.start)} — ${formatTimecode(cue.end)}`;
    meta.append(label, time);
    card.append(meta);

    const fields = isChinese
      ? [{ key: "originalText", label: "字幕对白", value: values.originalText }]
      : [
          { key: "originalText", label: "原文", value: values.originalText },
          { key: "translatedText", label: "中文译文", value: values.translatedText },
        ];

    fields.forEach((field) => {
      const fieldLabel = document.createElement("label");
      fieldLabel.append(document.createTextNode(field.label));
      const textarea = document.createElement("textarea");
      textarea.dataset.subtitleField = field.key;
      textarea.value = field.value;
      textarea.placeholder = field.key === "translatedText" ? "可在这里填写或修正中文译文" : "可在这里修正字幕对白";
      textarea.addEventListener("input", () => {
        const edits = ensureSubtitleEdits();
        if (!edits) return;
        const cueKey = String(cue.cueIndex);
        edits.byCue[cueKey] = {
          ...(edits.byCue[cueKey] || {}),
          [field.key]: textarea.value,
          updatedAt: new Date().toISOString(),
        };
        edits.updatedAt = new Date().toISOString();
        updateSubtitleAssignments();
        if (subtitleSaveState) subtitleSaveState.textContent = "正在自动保存…";
        scheduleManualSave();
      });
      fieldLabel.append(textarea);
      card.append(fieldLabel);
    });

    subtitleDialogueList.append(card);
  });

  if (subtitleSaveState) {
    subtitleSaveState.textContent = matchingSubtitleEdits()
      ? "✓ 校正版已自动保存"
      : "修改会自动保存";
  }
}

async function retryReadExistingSubtitles() {
  if (!currentLocalProject || !manualAnalysis) {
    showToast("请先导入一部影片");
    return;
  }

  if (!window.cinemaDesktop?.readSubtitles) {
    showToast("当前是网页预览，安装版会重新读取影片已有字幕");
    return;
  }

  retryReadSubtitlesButton?.setAttribute("disabled", "true");
  if (subtitleSaveState) subtitleSaveState.textContent = "正在重新读取字幕…";
  const subtitleResult = await window.cinemaDesktop.readSubtitles();
  retryReadSubtitlesButton?.removeAttribute("disabled");

  if (!subtitleResult || subtitleResult.error) {
    if (subtitleSaveState) subtitleSaveState.textContent = "字幕读取未完成";
    showToast(subtitleResult?.error || "没有读取到字幕，请检查影片旁边是否有同名字幕文件");
    return;
  }

  manualAnalysis.subtitles = subtitleResult;
  manualAnalysis.subtitleTranslation = null;
  manualAnalysis.subtitleEdits = null;
  updateSubtitleAssignments();
  await saveAnalysisToDisk({
    savingDetail: "正在保存字幕结果",
    failureDetail: "字幕结果没有保存成功，请重试",
  });
  applyLocalProject(currentLocalProject, true);
  setWorkbenchSideTab("subtitles");
  showToast(subtitleResult.found
    ? `已重新读取 ${subtitleResult.cueCount || 0} 条字幕`
    : "还是没有发现已有字幕，请检查字幕文件名和位置");
}

function renderAITranslationTask(errorMessage = "") {
  if (!startAITranslationButton || !aiTranslationTaskTitle || !aiTranslationTaskDetail) return;
  const subtitles = manualAnalysis?.subtitles;
  const translation = matchingSubtitleTranslation();
  const cueCount = Array.isArray(subtitles?.cues) ? subtitles.cues.length : 0;
  let title = "等待导入英文字幕";
  let detail = "导入影片后，可在这里手动开始翻译。";
  let buttonText = "开始翻译";
  let disabled = true;

  if (isAITranslationRunning) {
    title = "正在翻译英文字幕";
    detail = "可以等待在后台完成，请不要关闭软件。";
    buttonText = "翻译中…";
  } else if (!currentLocalProject) {
    title = "尚未导入影片";
  } else if (!subtitles?.found || !cueCount) {
    title = "当前影片没有可读取字幕";
    detail = "请确认影片带有文字字幕，或同文件夹中存在同名字幕文件。";
  } else if (subtitles.isChinese) {
    title = "当前影片已有中文字幕";
    detail = `已读取 ${cueCount} 条中文字幕，无需使用 AI 翻译。`;
  } else if (!isEnglishSubtitleResult(subtitles)) {
    title = "当前字幕未确认是英文";
    detail = "为避免误翻其他语言，本次不会发送字幕。";
  } else if (!aiTranslationConfigured) {
    title = `发现 ${cueCount} 条英文字幕`;
    detail = "请先在上方安全保存 DeepSeek 密钥。";
  } else {
    disabled = false;
    title = translation?.status === "complete"
      ? `已完成 ${translation.translatedCount} 条翻译`
      : translation?.translatedCount
        ? `已翻译 ${translation.translatedCount} / ${cueCount} 条`
        : `发现 ${cueCount} 条英文字幕`;
    detail = translation?.status === "complete"
      ? "中英文结果已保存在当前拉片项目，可以手动重新翻译。"
      : translation?.translatedCount
        ? "部分译文已保存，英文原文完整保留，可以继续重试。"
        : "点击后才会发送字幕文字并产生 DeepSeek 费用。";
    buttonText = translation?.translatedCount ? "重新翻译" : "开始翻译";
  }

  aiTranslationTaskTitle.textContent = title;
  aiTranslationTaskDetail.textContent = detail;
  startAITranslationButton.textContent = buttonText;
  startAITranslationButton.disabled = disabled || isAITranslationRunning;
  if (aiTranslationError) {
    aiTranslationError.hidden = !errorMessage;
    aiTranslationError.textContent = errorMessage;
  }
  if (!isAITranslationRunning && aiTranslationProgress) aiTranslationProgress.hidden = true;
}

async function refreshAITranslationStatus() {
  if (!window.cinemaDesktop?.getAITranslationSettings) {
    renderAITranslationStatus(aiTranslationConfigured);
    return;
  }
  const result = await window.cinemaDesktop.getAITranslationSettings();
  renderAITranslationStatus(result?.configured);
}

async function openAITranslationDialog() {
  await refreshAITranslationStatus();
  if (aiTranslationKeyInput) aiTranslationKeyInput.value = "";
  if (aiTranslationOverlay) aiTranslationOverlay.hidden = false;
  renderAITranslationTask();
  window.setTimeout(
    () => (aiTranslationConfigured ? startAITranslationButton : aiTranslationKeyInput)?.focus(),
    80
  );
}

function closeAITranslationDialog() {
  if (aiTranslationKeyInput) aiTranslationKeyInput.value = "";
  if (aiTranslationOverlay) aiTranslationOverlay.hidden = true;
}

function openPage(page, options = {}) {
  appShell?.classList.toggle("library-search-visible", page === "library");
  if (page === "library" && !options.preserveProjectCategory) {
    activeProjectCategory = "all";
    libraryExpanded = false;
  }
  if (page !== "library") {
    activeProjectCategory = "all";
    libraryExpanded = false;
    renderLibraryCategoryButtons(currentLibraryProjects());
  }
  navItems.forEach((item) => item.classList.toggle("active", item.dataset.page === page));
  pages.forEach((section) => section.classList.toggle("active", section.id === `${page}-page`));
  pageTitle.textContent = pageNames[page];
  if (page === "library") {
    renderLibraryProjects();
  }
  if (page === "workbench") {
    window.setTimeout(() => resumeIncompleteLocalAnalysisAssets(), 0);
  }
  if (page === "export") refreshReportWorkspace();
  if (page === "inspiration") {
    const returnState = inspirationSourceReturnState;
    loadInspirationCollections().then(() => {
      if (!returnState) {
        window.scrollTo({ top: 0, behavior: "smooth" });
        return;
      }
      selectInspirationCollection(returnState.collection, { touch: false });
      selectInspirationFilter(returnState.filter);
      if (inspirationSearchInput) inspirationSearchInput.value = returnState.search;
      updateInspirationResults();
      window.requestAnimationFrame(() => {
        window.scrollTo({ top: returnState.scrollY, behavior: "auto" });
        inspirationSourceReturnState = null;
      });
    });
    return;
  }
  window.scrollTo({ top: 0, behavior: "smooth" });
}

function closeRestorePreview() {
  if (restorePreviewOverlay) restorePreviewOverlay.hidden = true;
}

function formatBackupDate(value) {
  const date = value ? new Date(value) : null;
  if (!date || Number.isNaN(date.getTime())) return "日期未知";
  return new Intl.DateTimeFormat("zh-CN", {
    year: "numeric",
    month: "long",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

function updateBackupHistory(result) {
  if (!result || !backupHistoryTitle || !backupHistoryDetail) return;
  backupHistoryIcon.textContent = "✓";
  backupHistoryTitle.textContent = `最近备份：${formatBackupDate(result.createdAt)}`;
  backupHistoryDetail.textContent = `${result.projectCount || 0} 部影片 · ${result.frameCount || 0} 张静帧 · ${result.clipCount || 0} 个片段 · ${result.collectionCount || 0} 个收藏夹 · ${result.inspirationItemCount || 0} 项灵感`;
}

function showRestorePreview(backup) {
  restoreBackupDate.textContent = formatBackupDate(backup.createdAt);
  restoreBackupName.textContent = backup.fileName || "导演资料备份.cpbak";
  restoreProjectCount.textContent = String(backup.projectCount || 0);
  restoreFrameCount.textContent = String(backup.frameCount || 0);
  restoreClipCount.textContent = String(backup.clipCount || 0);
  restoreShotCount.textContent = String(backup.shotCount || 0);
  restoreCollectionCount.textContent = String(backup.collectionCount || 0);
  restoreInspirationCount.textContent = String(backup.inspirationItemCount || 0);
  restoreNoteCount.textContent = String(backup.noteCount || 0);
  restorePreviewDescription.textContent = "已完成资料完整性检查，请确认是否安全合并恢复。";
  restorePreviewOverlay.hidden = false;
}

createBackupPreviewButton?.addEventListener("click", async () => {
  if (!window.cinemaDesktop?.createLocalBackup) {
    showToast("网页预览：安装版会生成不含原始影片的备份文件");
    return;
  }
  const originalText = createBackupPreviewButton.textContent;
  createBackupPreviewButton.disabled = true;
  createBackupPreviewButton.textContent = "正在整理全部资料…";
  try {
    const result = await window.cinemaDesktop.createLocalBackup();
    if (result?.error) {
      showToast(result.error);
      return;
    }
    if (!result?.cancelled) {
      updateBackupHistory(result);
      showToast(`备份已保存：${result.fileName || "导演资料备份.cpbak"}`);
    }
  } finally {
    createBackupPreviewButton.disabled = false;
    createBackupPreviewButton.textContent = originalText;
  }
});

restoreBackupPreviewButton?.addEventListener("click", async () => {
  if (!window.cinemaDesktop?.selectRestoreBackup) {
    showRestorePreview({
      createdAt: new Date().toISOString(),
      fileName: "新天堂电影院-导演资料备份.cpbak",
      projectCount: 1,
      frameCount: 42,
      clipCount: 9,
      shotCount: 186,
      collectionCount: 4,
      inspirationItemCount: 51,
      noteCount: 8,
    });
    return;
  }
  const result = await window.cinemaDesktop.selectRestoreBackup();
  if (result?.error) {
    showToast(result.error);
    return;
  }
  if (!result?.cancelled) showRestorePreview(result);
});

restorePreviewClose?.addEventListener("click", closeRestorePreview);
restorePreviewCancel?.addEventListener("click", closeRestorePreview);
restorePreviewConfirm?.addEventListener("click", async () => {
  if (!window.cinemaDesktop?.restoreSelectedBackup) {
    closeRestorePreview();
    showToast("网页预览：将安全合并恢复，并跳过重复资料");
    return;
  }
  const originalText = restorePreviewConfirm.textContent;
  restorePreviewConfirm.disabled = true;
  restorePreviewConfirm.textContent = "正在安全恢复…";
  try {
    const result = await window.cinemaDesktop.restoreSelectedBackup();
    if (result?.error) {
      showToast(result.error);
      return;
    }
    closeRestorePreview();
    await loadInspirationCollections();
    const restoredProject = await window.cinemaDesktop.getRecentProject?.();
    if (!currentLocalProject && restoredProject) applyLocalProject(restoredProject, false);
    updateBackupHistory(result);
    const restoredCount = (result?.addedProjects || 0)
      + (result?.addedFrames || 0)
      + (result?.addedClips || 0)
      + (result?.addedCollections || 0)
      + (result?.addedInspirationItems || 0)
      + (result?.addedNotes || 0);
    showToast(`恢复完成：新增 ${restoredCount} 项，跳过 ${result?.skippedItems || 0} 项重复资料`);
  } finally {
    restorePreviewConfirm.disabled = false;
    restorePreviewConfirm.textContent = originalText;
  }
});

restorePreviewOverlay?.addEventListener("click", (event) => {
  if (event.target === restorePreviewOverlay) closeRestorePreview();
});

openAccountDialogButton?.addEventListener("click", openAccountDialog);
accountDialogClose?.addEventListener("click", closeAccountDialog);
accountDialogCancel?.addEventListener("click", closeAccountDialog);
accountOverlay?.addEventListener("click", (event) => {
  if (event.target === accountOverlay) closeAccountDialog();
});

accountForm?.addEventListener("submit", (event) => {
  event.preventDefault();
  const displayName = accountDisplayNameInput?.value.trim() || "";
  const email = accountEmailInput?.value.trim() || "";
  if (!displayName) {
    if (accountFormError) {
      accountFormError.hidden = false;
      accountFormError.textContent = "请先填写一个显示名称";
    }
    accountDisplayNameInput?.focus();
    return;
  }
  if (!isValidEmail(email)) {
    if (accountFormError) {
      accountFormError.hidden = false;
      accountFormError.textContent = "请填写一个有效邮箱，方便未来升级云端账号";
    }
    accountEmailInput?.focus();
    return;
  }
  saveLightAccountProfile({ displayName, email });
  closeAccountDialog();
  showToast("本机轻账号已保存，不影响本地拉片资料");
});

clearAccountProfileButton?.addEventListener("click", () => {
  const confirmed = window.confirm("退出本机轻账号只会清除昵称和邮箱，不会删除任何拉片资料。确认退出？");
  if (!confirmed) return;
  clearLightAccountProfile();
  showToast("已退出本机轻账号，资料仍保留在本机");
});

openCloudSubtitleButton?.addEventListener("click", openCloudSubtitleDialog);
cloudSubtitleClose?.addEventListener("click", closeCloudSubtitleDialog);
cancelCloudSubtitleButton?.addEventListener("click", closeCloudSubtitleDialog);

cloudSubtitleOverlay?.addEventListener("click", (event) => {
  if (event.target === cloudSubtitleOverlay) closeCloudSubtitleDialog();
});

saveCloudSubtitleButton?.addEventListener("click", async () => {
  const key = cloudSubtitleKeyInput?.value.trim() || "";
  if (!key) {
    showToast("请填写 OpenAI 密钥");
    cloudSubtitleKeyInput?.focus();
    return;
  }
  if (!key.startsWith("sk-") || key.length < 20) {
    showToast("这串 OpenAI 密钥格式不正确，请重新检查");
    cloudSubtitleKeyInput?.focus();
    return;
  }

  saveCloudSubtitleButton.disabled = true;
  saveCloudSubtitleButton.textContent = "正在安全保存…";
  try {
    const result = window.cinemaDesktop?.saveCloudSubtitleKey
      ? await window.cinemaDesktop.saveCloudSubtitleKey({ key })
      : { configured: true };
    if (result?.error) {
      showToast(result.error);
      return;
    }
    renderCloudSubtitleStatus(true);
    cloudSubtitleKeyInput.value = "";
    renderCloudSubtitleTask();
    showToast("OpenAI 密钥已安全保存在本机");
  } finally {
    saveCloudSubtitleButton.disabled = false;
    saveCloudSubtitleButton.textContent = "安全保存";
  }
});

startCloudSubtitleButton?.addEventListener("click", async () => {
  if (isCloudSubtitleRunning || !currentLocalProject || !cloudSubtitleConfigured) {
    renderCloudSubtitleTask();
    return;
  }
  if (!window.cinemaDesktop?.extractCloudSubtitles) {
    renderCloudSubtitleTask("当前预览不能连接 OpenAI，请在安装版软件中使用。");
    return;
  }

  isCloudSubtitleRunning = true;
  if (cloudSubtitleProgress) cloudSubtitleProgress.hidden = false;
  if (cloudSubtitleProgressBar) cloudSubtitleProgressBar.style.width = "0%";
  if (cloudSubtitleProgressPercent) cloudSubtitleProgressPercent.textContent = "0%";
  if (cloudSubtitleProgressLabel) cloudSubtitleProgressLabel.textContent = "正在准备字幕关键画面…";
  renderCloudSubtitleTask();

  try {
    const result = await window.cinemaDesktop.extractCloudSubtitles({}, (progress) => {
      const percent = Math.max(0, Math.min(100, Number(progress?.percent) || 0));
      if (cloudSubtitleProgressPercent) cloudSubtitleProgressPercent.textContent = `${percent}%`;
      if (cloudSubtitleProgressBar) cloudSubtitleProgressBar.style.width = `${percent}%`;
      if (cloudSubtitleProgressLabel) {
        cloudSubtitleProgressLabel.textContent = progress?.message
          || `已分析 ${progress?.processed || 0} / ${progress?.total || 0} 张字幕关键画面`;
      }
    });

    const saved = await applyCloudSubtitleResult(result);
    if (saved) {
      renderCloudSubtitleTask(result?.error || "");
      showToast(`云端字幕已写入，共 ${manualAnalysis.subtitles?.cueCount || 0} 条`);
    } else {
      const error = result?.error || "云端没有从画面中读到字幕";
      manualAnalysis.cloudSubtitleExtraction = {
        version: 1,
        provider: result?.provider || "openai",
        model: result?.model || "gpt-5-mini",
        status: "empty",
        cueCount: 0,
        sampledFrameCount: Number(result?.sampledFrameCount) || 0,
        uploadedFrameCount: Number(result?.uploadedFrameCount) || 0,
        extractedAt: result?.scannedAt || new Date().toISOString(),
      };
      await saveAnalysisToDisk({
        savingDetail: "正在保存云端字幕状态",
        failureDetail: "云端字幕状态没有保存成功，请重试",
      });
      renderCloudSubtitleStatus(cloudSubtitleConfigured);
      renderCloudSubtitleTask(error);
      showToast("云端没有提取到可用字幕");
    }
  } catch {
    renderCloudSubtitleTask("网络请求失败，云端字幕提取没有完成。");
    showToast("云端字幕提取未完成");
  } finally {
    isCloudSubtitleRunning = false;
    renderCloudSubtitleTask(cloudSubtitleError?.hidden ? "" : cloudSubtitleError?.textContent || "");
  }
});

removeCloudSubtitleKeyButton?.addEventListener("click", async () => {
  const result = window.cinemaDesktop?.removeCloudSubtitleKey
    ? await window.cinemaDesktop.removeCloudSubtitleKey()
    : { configured: false };
  if (result?.error) {
    showToast(result.error);
    return;
  }
  renderCloudSubtitleStatus(false);
  closeCloudSubtitleDialog();
  showToast("已移除 OpenAI 密钥");
});

openAITranslationButton?.addEventListener("click", openAITranslationDialog);
aiTranslationClose?.addEventListener("click", closeAITranslationDialog);
cancelAITranslationButton?.addEventListener("click", closeAITranslationDialog);

aiTranslationOverlay?.addEventListener("click", (event) => {
  if (event.target === aiTranslationOverlay) closeAITranslationDialog();
});

saveAITranslationButton?.addEventListener("click", async () => {
  const key = aiTranslationKeyInput?.value.trim() || "";
  if (!key) {
    showToast("请填写 DeepSeek 密钥");
    aiTranslationKeyInput?.focus();
    return;
  }
  if (!key.startsWith("sk-") || key.length < 20) {
    showToast("这串密钥格式不正确，请重新检查");
    aiTranslationKeyInput?.focus();
    return;
  }

  saveAITranslationButton.disabled = true;
  saveAITranslationButton.textContent = "正在安全保存…";
  try {
    const result = window.cinemaDesktop?.saveAITranslationKey
      ? await window.cinemaDesktop.saveAITranslationKey({ key })
      : { configured: true };
    if (result?.error) {
      showToast(result.error);
      return;
    }
    renderAITranslationStatus(true);
    aiTranslationKeyInput.value = "";
    renderAITranslationTask();
    showToast("AI 翻译密钥已安全保存在本机");
  } finally {
    saveAITranslationButton.disabled = false;
    saveAITranslationButton.textContent = "安全保存";
  }
});

startAITranslationButton?.addEventListener("click", async () => {
  const subtitles = manualAnalysis?.subtitles;
  const cues = Array.isArray(subtitles?.cues) ? subtitles.cues : [];
  if (
    isAITranslationRunning
    || !currentLocalProject
    || !aiTranslationConfigured
    || !isEnglishSubtitleResult(subtitles)
    || !cues.length
  ) {
    renderAITranslationTask();
    return;
  }
  if (!window.cinemaDesktop?.translateSubtitles) {
    renderAITranslationTask("当前预览不能连接 DeepSeek，请在安装版软件中使用。");
    return;
  }

  isAITranslationRunning = true;
  const translationSourceCues = cues.map((cue, id) => ({
    id,
    text: subtitleCueDisplayValues(cue, id).originalText,
  }));
  if (aiTranslationProgress) aiTranslationProgress.hidden = false;
  if (aiTranslationProgressBar) aiTranslationProgressBar.style.width = "0%";
  if (aiTranslationProgressPercent) aiTranslationProgressPercent.textContent = "0%";
  if (aiTranslationProgressLabel) aiTranslationProgressLabel.textContent = "正在准备英文字幕…";
  renderAITranslationTask();

  try {
    const result = await window.cinemaDesktop.translateSubtitles({
      cues: translationSourceCues,
    }, (progress) => {
      const percent = Math.max(0, Math.min(100, Number(progress?.percent) || 0));
      if (aiTranslationProgressPercent) aiTranslationProgressPercent.textContent = `${percent}%`;
      if (aiTranslationProgressBar) aiTranslationProgressBar.style.width = `${percent}%`;
      if (aiTranslationProgressLabel) {
        aiTranslationProgressLabel.textContent = `已翻译 ${progress?.translated || 0} / ${progress?.total || cues.length} 条`;
      }
    });

    const returnedTranslations = new Map(
      (result?.translations || []).map((item) => [Number(item.id), String(item.text || "").trim()])
    );
    const existing = matchingSubtitleTranslation();
    const existingTranslations = new Map(
      (existing?.translations || [])
        .filter((item) => item.originalText === String(translationSourceCues[item.cueIndex]?.text || ""))
        .map((item) => [Number(item.cueIndex), String(item.translatedText || "").trim()])
    );
    returnedTranslations.forEach((text, id) => {
      if (text) existingTranslations.set(id, text);
    });
    const translations = cues.map((cue, cueIndex) => ({
      cueIndex,
      originalText: String(translationSourceCues[cueIndex]?.text || ""),
      translatedText: existingTranslations.get(cueIndex) || "",
    }));
    const translatedCount = translations.filter((item) => item.translatedText).length;

    if (translatedCount > 0) {
      manualAnalysis.subtitleTranslation = {
        provider: "deepseek",
        model: result?.model || "deepseek-v4-flash",
        sourceName: subtitles.sourceName || "",
        cueCount: cues.length,
        translatedCount,
        status: translatedCount === cues.length ? "complete" : "partial",
        translatedAt: new Date().toISOString(),
        translations,
      };
      updateSubtitleAssignments();
      await saveAnalysisToDisk({
        savingDetail: "正在保存字幕翻译",
        failureDetail: "字幕翻译没有保存成功，请重试",
      });
      renderAITranslationStatus(aiTranslationConfigured);
      renderSubtitleDialoguePanel();
    }

    const error = result?.error || (translatedCount ? "" : "翻译没有返回结果，英文原文已保留");
    renderAITranslationTask(error);
    if (error) {
      showToast(translatedCount ? "部分字幕已翻译，其余可重新尝试" : "翻译未完成，英文原文已保留");
    } else {
      showToast(`已完成 ${translatedCount} 条中英字幕翻译`);
    }
  } catch {
    renderAITranslationTask("网络请求失败，英文原文已保留，可以重新翻译。");
    showToast("翻译未完成，英文原文已保留");
  } finally {
    isAITranslationRunning = false;
    renderAITranslationTask(aiTranslationError?.hidden ? "" : aiTranslationError?.textContent || "");
  }
});

removeAITranslationKeyButton?.addEventListener("click", async () => {
  const result = window.cinemaDesktop?.removeAITranslationKey
    ? await window.cinemaDesktop.removeAITranslationKey()
    : { configured: false };
  if (result?.error) {
    showToast(result.error);
    return;
  }
  renderAITranslationStatus(false);
  closeAITranslationDialog();
  showToast("已移除 AI 翻译密钥");
});

function formatTimecode(totalSeconds) {
  const safeSeconds = Number.isFinite(totalSeconds) ? Math.max(0, totalSeconds) : 0;
  const hours = Math.floor(safeSeconds / 3600);
  const minutes = Math.floor((safeSeconds % 3600) / 60);
  const seconds = Math.floor(safeSeconds % 60);
  const frames = Math.min(24, Math.floor((safeSeconds % 1) * 25));
  return [hours, minutes, seconds, frames]
    .map((value) => String(value).padStart(2, "0"))
    .join(":");
}

function shotKey(time) {
  return `shot-${Math.round(time * 1000)}`;
}

function defaultShotData() {
  return {
    size: "中景",
    angle: "平视",
    movement: "固定",
    note: "",
  };
}

function initializeManualAnalysis(duration) {
  if (!manualAnalysis || typeof manualAnalysis !== "object") {
    manualAnalysis = { cutPoints: [], shotData: {} };
  }
  if (!Array.isArray(manualAnalysis.cutPoints)) manualAnalysis.cutPoints = [];
  if (!manualAnalysis.shotData || typeof manualAnalysis.shotData !== "object") {
    manualAnalysis.shotData = {};
  }
  if (!manualAnalysis.cutConfidence || typeof manualAnalysis.cutConfidence !== "object") {
    manualAnalysis.cutConfidence = {};
  }
  if (!manualAnalysis.representativeFrames || typeof manualAnalysis.representativeFrames !== "object") {
    manualAnalysis.representativeFrames = {};
  }
  ensureStructureBoard();

  let points = [...manualAnalysis.cutPoints, 0];
  if (Number.isFinite(duration) && duration > 0) {
    points = points.filter((point) => Number(point) < duration - 0.12);
    points.push(duration);
  }
  manualAnalysis.cutPoints = points
    .filter((point) => Number.isFinite(Number(point)))
    .map(Number)
    .sort((a, b) => a - b)
    .filter((point, index, allPoints) => index === 0 || Math.abs(point - allPoints[index - 1]) > 0.08);
  updateSubtitleAssignments();
}

function manualShots() {
  if (!manualAnalysis?.cutPoints?.length) return [];
  return manualAnalysis.cutPoints.slice(0, -1).map((start, index) => ({
    key: shotKey(start),
    index,
    start,
    end: manualAnalysis.cutPoints[index + 1],
  }));
}

function buildSubtitleAssignments(shots, subtitleResult) {
  const cues = Array.isArray(subtitleResult?.cues) ? subtitleResult.cues : [];
  const translation = matchingSubtitleTranslation();
  const subtitleEdits = matchingSubtitleEdits();
  const translationByCueIndex = new Map(
    (translation?.translations || []).map((item) => [
      Number(item.cueIndex),
      String(item.translatedText || ""),
    ])
  );
  const editsByCueIndex = subtitleEdits?.byCue || {};
  const byShot = {};
  let assignedCueCount = 0;

  shots.forEach((shot) => {
    const matchingCues = cues.flatMap((cue, cueIndex) => {
      const start = Number(cue?.start);
      const end = Number(cue?.end);
      const edit = editsByCueIndex[String(cueIndex)] || {};
      const text = (
        Object.prototype.hasOwnProperty.call(edit, "originalText")
          ? String(edit.originalText || "")
          : String(cue?.text || "")
      ).trim();
      const translatedText = (
        Object.prototype.hasOwnProperty.call(edit, "translatedText")
          ? String(edit.translatedText || "")
          : translationByCueIndex.get(cueIndex) || ""
      ).trim();
      if (!Number.isFinite(start) || !Number.isFinite(end) || end <= start) return [];
      if (!text && !translatedText) return [];
      const overlapStart = Math.max(shot.start, start);
      const overlapEnd = Math.min(shot.end, end);
      if (overlapEnd <= overlapStart) return [];
      assignedCueCount += 1;
      return [{
        cueIndex,
        start,
        end,
        overlapStart,
        overlapEnd,
        text,
        translatedText,
      }];
    });
    if (!matchingCues.length) return;
    byShot[shot.key] = {
      shotKey: shot.key,
      shotNumber: shot.index + 1,
      start: shot.start,
      end: shot.end,
      text: matchingCues.map((cue) => cue.text).filter(Boolean).join("\n"),
      translatedText: matchingCues.map((cue) => cue.translatedText).filter(Boolean).join("\n"),
      cues: matchingCues,
    };
  });

  return {
    version: 1,
    sourceName: subtitleResult?.sourceName || "",
    language: subtitleResult?.language || "",
    cueCount: cues.length,
    assignedCueCount,
    shotCount: shots.length,
    byShot,
  };
}

function updateSubtitleAssignments() {
  if (!manualAnalysis || typeof manualAnalysis !== "object") return;
  manualAnalysis.subtitleAssignments = buildSubtitleAssignments(
    manualShots(),
    manualAnalysis.subtitles
  );
}

const structureBoardWidth = 1080;
const structureBoardHeight = 620;

function defaultStructureBoardTitle() {
  return currentLocalProject?.name ? `《${currentLocalProject.name}》结构` : "影片结构";
}

function createDefaultStructureBoard() {
  return {
    version: 1,
    updatedAt: new Date().toISOString(),
    nodes: [
      {
        id: "root",
        title: defaultStructureBoardTitle(),
        x: 72,
        y: Math.round(structureBoardHeight / 2),
        parentId: null,
        type: "root",
      },
    ],
  };
}

function ensureStructureBoard() {
  if (!manualAnalysis || typeof manualAnalysis !== "object") return null;
  const existingBoard = manualAnalysis.structureBoard && typeof manualAnalysis.structureBoard === "object"
    ? manualAnalysis.structureBoard
    : createDefaultStructureBoard();
  const nodes = Array.isArray(existingBoard.nodes) ? existingBoard.nodes : [];
  const sanitizedNodes = nodes
    .map((node, index) => ({
      id: String(node?.id || (index === 0 ? "root" : `node-${Date.now()}-${index}`)),
      title: String(node?.title || (index === 0 ? defaultStructureBoardTitle() : "新主题")).slice(0, 60),
      x: Number.isFinite(Number(node?.x)) ? Number(node.x) : 72 + index * 180,
      y: Number.isFinite(Number(node?.y)) ? Number(node.y) : 120 + index * 80,
      parentId: node?.parentId == null ? null : String(node.parentId),
      type: node?.type === "root" ? "root" : "topic",
    }));
  if (!sanitizedNodes.some((node) => node.id === "root")) {
    sanitizedNodes.unshift(createDefaultStructureBoard().nodes[0]);
  }
  sanitizedNodes.forEach((node) => {
    node.x = Math.max(36, Math.min(structureBoardWidth - 190, node.x));
    node.y = Math.max(38, Math.min(structureBoardHeight - 76, node.y));
    if (node.id === "root") {
      node.parentId = null;
      node.type = "root";
    }
  });
  const validIds = new Set(sanitizedNodes.map((node) => node.id));
  sanitizedNodes.forEach((node) => {
    if (node.parentId && !validIds.has(node.parentId)) node.parentId = "root";
  });
  manualAnalysis.structureBoard = {
    ...existingBoard,
    version: 1,
    updatedAt: existingBoard.updatedAt || new Date().toISOString(),
    nodes: sanitizedNodes,
  };
  if (!validIds.has(activeStructureNodeId)) activeStructureNodeId = "root";
  return manualAnalysis.structureBoard;
}

function structureBoardNodes(board = ensureStructureBoard()) {
  return Array.isArray(board?.nodes) ? board.nodes : [];
}

function structureBoardNodeById(nodeId) {
  return structureBoardNodes().find((node) => node.id === nodeId) || null;
}

function appendStructureLines(target, nodes, scale = 1) {
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  svg.setAttribute("viewBox", `0 0 ${structureBoardWidth} ${structureBoardHeight}`);
  svg.setAttribute("aria-hidden", "true");
  nodes.forEach((node) => {
    if (!node.parentId) return;
    const parent = nodes.find((item) => item.id === node.parentId);
    if (!parent) return;
    const line = document.createElementNS("http://www.w3.org/2000/svg", "path");
    const startX = parent.x + 148 * scale;
    const startY = parent.y + 26 * scale;
    const endX = node.x + 16 * scale;
    const endY = node.y + 26 * scale;
    const middleX = startX + Math.max(60, (endX - startX) * 0.48);
    line.setAttribute("d", `M ${startX} ${startY} C ${middleX} ${startY}, ${middleX} ${endY}, ${endX} ${endY}`);
    svg.append(line);
  });
  target.append(svg);
}

function renderStructureBoardPreview() {
  if (!structureBoardMiniCanvas) return;
  const board = ensureStructureBoard();
  const nodes = structureBoardNodes(board);
  structureBoardMiniCanvas.replaceChildren();
  if (!nodes.length) {
    if (structureBoardEmpty) structureBoardEmpty.hidden = false;
    return;
  }
  appendStructureLines(structureBoardMiniCanvas, nodes, 0.52);
  nodes.slice(0, 8).forEach((node) => {
    const item = document.createElement("span");
    item.className = `structure-mini-node${node.type === "root" ? " root" : ""}`;
    item.textContent = node.title;
    item.style.left = `${Math.max(4, Math.min(82, (node.x / structureBoardWidth) * 100))}%`;
    item.style.top = `${Math.max(8, Math.min(78, (node.y / structureBoardHeight) * 100))}%`;
    structureBoardMiniCanvas.append(item);
  });
  if (structureBoardEmpty) {
    structureBoardEmpty.hidden = nodes.length > 1;
  }
}

function renderStructureBoardEditor() {
  const board = ensureStructureBoard();
  const nodes = structureBoardNodes(board);
  if (!structureBoardCanvas) return;
  if (structureBoardTitle) structureBoardTitle.textContent = currentLocalProject?.name || "影片结构画板";
  if (structureBoardSubtitle) {
    structureBoardSubtitle.textContent = "这张画板属于整部影片，所有镜头都会共用这一份结构。";
  }
  structureBoardCanvas.replaceChildren();
  appendStructureLines(structureBoardCanvas, nodes, 1);
  nodes.forEach((node) => {
    const item = document.createElement("div");
    item.role = "button";
    item.tabIndex = 0;
    item.className = `structure-board-node${node.type === "root" ? " root" : ""}`;
    if (node.id === activeStructureNodeId) item.classList.add("selected");
    if (node.id === editingStructureNodeId) item.classList.add("editing");
    item.style.left = `${node.x}px`;
    item.style.top = `${node.y}px`;
    item.dataset.nodeId = node.id;

    if (node.id === editingStructureNodeId) {
      const input = document.createElement("input");
      input.className = "structure-board-node-input";
      input.type = "text";
      input.maxLength = 60;
      input.value = node.title;
      input.setAttribute("aria-label", "输入结构节点内容");
      input.addEventListener("pointerdown", (event) => event.stopPropagation());
      input.addEventListener("click", (event) => event.stopPropagation());
      input.addEventListener("keydown", (event) => {
        event.stopPropagation();
        if (event.key === "Enter") {
          event.preventDefault();
          finishStructureNodeEdit(node.id, input.value);
        }
        if (event.key === "Escape") {
          event.preventDefault();
          cancelStructureNodeEdit();
        }
      });
      input.addEventListener("blur", () => finishStructureNodeEdit(node.id, input.value));
      item.append(input);
      window.setTimeout(() => {
        input.focus();
        input.select();
      }, 0);
    } else {
      item.textContent = node.title;
      item.addEventListener("click", () => {
        activeStructureNodeId = node.id;
        renderStructureBoardEditor();
      });
      item.addEventListener("dblclick", () => editStructureNode(node.id));
      item.addEventListener("keydown", (event) => {
        if (event.key === "Enter") {
          event.preventDefault();
          editStructureNode(node.id);
        }
      });
      item.addEventListener("pointerdown", (event) => beginStructureNodeDrag(event, node.id));
    }
    structureBoardCanvas.append(item);
  });
}

function markStructureBoardChanged(message = "正在自动保存结构画板…") {
  const board = ensureStructureBoard();
  if (!board) return;
  board.updatedAt = new Date().toISOString();
  renderStructureBoardPreview();
  if (structureBoardSaveState) structureBoardSaveState.textContent = message;
  clearTimeout(structureBoardSaveTimer);
  structureBoardSaveTimer = setTimeout(saveStructureBoardNow, 500);
}

async function saveStructureBoardNow() {
  if (!currentLocalProject || !manualAnalysis) return;
  saveCurrentShotEditor();
  const updatedProject = await saveAnalysisToDisk({
    savingDetail: "正在保存结构画板",
    failureDetail: "结构画板没有保存成功，请重试",
    quiet: true,
  });
  if (!updatedProject) {
    if (structureBoardSaveState) structureBoardSaveState.textContent = "保存未完成，请重试";
    return;
  }
  projectLibrary = projectLibrary.map((record) => (
    record.filePath === updatedProject.filePath ? updatedProject : record
  ));
  if (structureBoardSaveState) structureBoardSaveState.textContent = "✓ 结构画板已自动保存";
  renderLibraryProjects();
}

function newStructureNodeId() {
  return `node-${Date.now()}-${Math.round(Math.random() * 10000)}`;
}

function addStructureNode(parentId = "root") {
  const board = ensureStructureBoard();
  if (!board) return;
  const nodes = structureBoardNodes(board);
  const parent = nodes.find((node) => node.id === parentId) || nodes.find((node) => node.id === "root");
  if (!parent) return;
  const childCount = nodes.filter((node) => node.parentId === parent.id).length;
  const node = {
    id: newStructureNodeId(),
    title: parent.id === "root" ? "新主题" : "新分支",
    x: Math.min(structureBoardWidth - 190, parent.x + 230),
    y: Math.max(42, Math.min(structureBoardHeight - 76, parent.y - 78 + childCount * 78)),
    parentId: parent.id,
    type: "topic",
  };
  board.nodes.push(node);
  activeStructureNodeId = node.id;
  editingStructureNodeId = node.id;
  renderStructureBoardEditor();
  markStructureBoardChanged("已添加节点，输入后会自动保存…");
}

function renameStructureNode(nodeId = activeStructureNodeId) {
  editStructureNode(nodeId);
}

function editStructureNode(nodeId = activeStructureNodeId) {
  const node = structureBoardNodeById(nodeId);
  if (!node) return;
  activeStructureNodeId = node.id;
  editingStructureNodeId = node.id;
  renderStructureBoardEditor();
}

function finishStructureNodeEdit(nodeId, value) {
  if (editingStructureNodeId !== nodeId) return;
  const node = structureBoardNodeById(nodeId);
  editingStructureNodeId = null;
  if (!node) {
    renderStructureBoardEditor();
    return;
  }
  const title = String(value || "").trim().slice(0, 60);
  if (!title) {
    renderStructureBoardEditor();
    showToast("节点内容不能为空");
    return;
  }
  if (title === node.title) {
    renderStructureBoardEditor();
    return;
  }
  node.title = title;
  activeStructureNodeId = node.id;
  renderStructureBoardEditor();
  markStructureBoardChanged("已更新节点内容，正在保存…");
}

function cancelStructureNodeEdit() {
  editingStructureNodeId = null;
  renderStructureBoardEditor();
}

function deleteStructureNode(nodeId = activeStructureNodeId) {
  const board = ensureStructureBoard();
  const nodes = structureBoardNodes(board);
  const node = nodes.find((item) => item.id === nodeId);
  if (!node) return;
  if (node.id === "root") {
    showToast("主结构节点不能删除，可以重命名");
    return;
  }
  const removedIds = new Set([node.id]);
  let changed = true;
  while (changed) {
    changed = false;
    nodes.forEach((item) => {
      if (item.parentId && removedIds.has(item.parentId) && !removedIds.has(item.id)) {
        removedIds.add(item.id);
        changed = true;
      }
    });
  }
  board.nodes = nodes.filter((item) => !removedIds.has(item.id));
  activeStructureNodeId = node.parentId && structureBoardNodeById(node.parentId) ? node.parentId : "root";
  renderStructureBoardEditor();
  markStructureBoardChanged(removedIds.size > 1
    ? "已删除节点和下级分支，正在保存…"
    : "已删除节点，正在保存…");
}

function autoLayoutStructureBoard() {
  const board = ensureStructureBoard();
  const nodes = structureBoardNodes(board);
  if (!nodes.length) return;
  const root = nodes.find((node) => node.id === "root") || nodes[0];
  const levels = [[root]];
  for (let levelIndex = 0; levelIndex < levels.length; levelIndex += 1) {
    const nextLevel = [];
    levels[levelIndex].forEach((node) => {
      nextLevel.push(...nodes.filter((item) => item.parentId === node.id));
    });
    if (nextLevel.length) levels.push(nextLevel);
  }
  levels.forEach((level, levelIndex) => {
    level.forEach((node, index) => {
      node.x = 72 + levelIndex * 235;
      node.y = Math.round(((index + 1) * structureBoardHeight) / (level.length + 1)) - 24;
    });
  });
  activeStructureNodeId = activeStructureNodeId || "root";
  renderStructureBoardEditor();
  markStructureBoardChanged("已自动整理，正在保存…");
}

function openStructureBoard() {
  if (!currentLocalProject || !manualAnalysis) {
    showToast("请先打开一部影片");
    return;
  }
  saveCurrentShotEditor();
  ensureStructureBoard();
  renderStructureBoardPreview();
  renderStructureBoardEditor();
  if (structureBoardSaveState) structureBoardSaveState.textContent = "修改会自动保存到当前影片";
  if (structureBoardOverlay) structureBoardOverlay.hidden = false;
}

function closeStructureBoard() {
  editingStructureNodeId = null;
  if (structureBoardOverlay) structureBoardOverlay.hidden = true;
}

async function openProjectStructureBoard(project) {
  if (!project || project.demo) {
    showToast("演示项目没有可编辑画板");
    return;
  }
  await openLibraryProject(project);
  if (currentLocalProject?.filePath !== project.filePath) return;
  openStructureBoard();
}

function beginStructureNodeDrag(event, nodeId) {
  const node = structureBoardNodeById(nodeId);
  if (!node || !structureBoardCanvas) return;
  if (editingStructureNodeId === nodeId || event.target?.closest?.(".structure-board-node-input")) return;
  activeStructureNodeId = nodeId;
  const rect = structureBoardCanvas.getBoundingClientRect();
  structureNodeDrag = {
    nodeId,
    startX: event.clientX,
    startY: event.clientY,
    nodeX: node.x,
    nodeY: node.y,
    scaleX: structureBoardWidth / rect.width,
    scaleY: structureBoardHeight / rect.height,
    moved: false,
  };
  event.currentTarget.setPointerCapture?.(event.pointerId);
}

function updateStructureNodeDrag(event) {
  if (!structureNodeDrag) return;
  const node = structureBoardNodeById(structureNodeDrag.nodeId);
  if (!node) return;
  node.x = Math.max(36, Math.min(
    structureBoardWidth - 190,
    structureNodeDrag.nodeX + (event.clientX - structureNodeDrag.startX) * structureNodeDrag.scaleX
  ));
  node.y = Math.max(38, Math.min(
    structureBoardHeight - 76,
    structureNodeDrag.nodeY + (event.clientY - structureNodeDrag.startY) * structureNodeDrag.scaleY
  ));
  structureNodeDrag.moved = true;
  renderStructureBoardEditor();
}

function finishStructureNodeDrag() {
  if (!structureNodeDrag) return;
  const shouldSave = structureNodeDrag.moved;
  structureNodeDrag = null;
  if (shouldSave) markStructureBoardChanged("已调整位置，正在保存…");
}

function saveCurrentShotEditor() {
  if (!selectedManualShotKey || !manualAnalysis) return;
  const selectedSize = document.querySelector("[data-shot-size].selected")?.dataset.shotSize || "中景";
  manualAnalysis.shotData[selectedManualShotKey] = {
    size: selectedSize,
    angle: shotAngleSelect.value,
    movement: shotMovementSelect.value,
    note: directorNote.value.trim(),
  };
}

function setSidebarSaveStatus(status = "saved", detail = "原片仅保留在本机") {
  if (!syncCard || !syncIcon || !syncTitle || !syncDetail) return;
  syncCard.classList.toggle("saving", status === "saving");
  syncCard.classList.toggle("error", status === "error");
  if (status === "saving") {
    syncIcon.textContent = "…";
    syncTitle.textContent = "正在保存";
    syncDetail.textContent = detail || "正在写入本机";
    return;
  }
  if (status === "error") {
    syncIcon.textContent = "!";
    syncTitle.textContent = "资料未保存";
    syncDetail.textContent = detail || "请检查权限或重试";
    return;
  }
  syncIcon.textContent = "✓";
  syncTitle.textContent = "资料已保存";
  syncDetail.textContent = detail || "原片仅保留在本机";
}

async function saveAnalysisToDisk({
  savingDetail = "正在写入本机",
  savedDetail = "原片仅保留在本机",
  failureDetail = "影片资料没有保存成功，请重试",
  quiet = false,
} = {}) {
  if (!manualAnalysis || !window.cinemaDesktop?.saveAnalysis) return currentLocalProject;
  setSidebarSaveStatus("saving", savingDetail);
  try {
    const updatedProject = await window.cinemaDesktop.saveAnalysis(manualAnalysis);
    if (!updatedProject || updatedProject.error) {
      throw new Error(updatedProject?.error || failureDetail);
    }
    currentLocalProject = updatedProject;
    setSidebarSaveStatus("saved", savedDetail);
    return updatedProject;
  } catch {
    setSidebarSaveStatus("error", failureDetail);
    if (!quiet) showToast(failureDetail);
    return null;
  }
}

function scheduleManualSave() {
  if (!currentLocalProject || !window.cinemaDesktop?.saveAnalysis) return;
  saveCurrentShotEditor();
  if (saveState) saveState.textContent = "正在自动保存…";
  setSidebarSaveStatus("saving", "正在保存拉片修改");
  clearTimeout(manualSaveTimer);
  manualSaveTimer = setTimeout(async () => {
    const updatedProject = await saveAnalysisToDisk({
      savingDetail: "正在保存拉片修改",
      failureDetail: "拉片修改没有保存成功，请重试",
      quiet: true,
    });
    if (updatedProject) {
      currentLocalProject = updatedProject;
      if (saveState) saveState.textContent = "✓ 已自动保存";
      if (subtitleSaveState) subtitleSaveState.textContent = "✓ 校正版已自动保存";
      if (basicSceneSaveState && manualAnalysis.basicSceneAnalysis) {
        basicSceneSaveState.textContent = "✓ 识别结果已自动保存";
      }
      projectLibrary = projectLibrary.map((record) => (
        record.filePath === currentLocalProject.filePath ? currentLocalProject : record
      ));
      if (!projectLibrary.some((record) => record.filePath === currentLocalProject.filePath)) {
        projectLibrary.unshift(currentLocalProject);
      }
      renderManualShots();
      renderLibraryProjects();
      await syncArchiveRecordsForCurrentShot();
    } else {
      if (saveState) saveState.textContent = "保存未完成";
      if (subtitleSaveState) subtitleSaveState.textContent = "保存未完成，请重试";
      if (basicSceneSaveState && manualAnalysis.basicSceneAnalysis) {
        basicSceneSaveState.textContent = "保存未完成，请重试";
      }
      showToast("拉片修改没有保存成功，请重试");
    }
  }, 450);
}

function updateShotEditor(shot) {
  if (!shot) return;
  const data = manualAnalysis.shotData[shot.key] || defaultShotData();
  manualAnalysis.shotData[shot.key] = data;

  analysisShotLabel.textContent = `镜头 ${String(shot.index + 1).padStart(3, "0")}`;
  document.querySelector(".frame-badge").textContent = `镜头 ${String(shot.index + 1).padStart(3, "0")}`;
  shotInInput.value = formatTimecode(shot.start);
  shotOutInput.value = formatTimecode(shot.end);
  shotDurationInput.value = `${Math.max(0, shot.end - shot.start).toFixed(1)} 秒`;
  shotAngleSelect.value = data.angle || "平视";
  shotMovementSelect.value = data.movement || "固定";
  directorNote.value = data.note || "";
  const representativeFrame = manualAnalysis.representativeFrames?.[shot.key];
  if (mainFrame && representativeFrame?.imageUrl) {
    mainFrame.src = cacheBustedImageUrl(representativeFrame.imageUrl, representativeFrame.updatedAt);
    mainFrame.alt = `镜头 ${String(shot.index + 1).padStart(3, "0")} 代表静帧`;
  }

  document.querySelectorAll("[data-shot-size]").forEach((button) => {
    button.classList.toggle("selected", button.dataset.shotSize === (data.size || "中景"));
  });
  updateRepresentativeFrameControl(shot);
  renderBasicScenePanel();
  renderSubtitleDialoguePanel();
  renderStructureBoardPreview();
}

function selectManualShot(key, seek = true) {
  saveCurrentShotEditor();
  activeClipPlaybackEnd = null;
  selectedManualShotKey = key;
  const shot = manualShots().find((item) => item.key === key);
  if (!shot) return;
  if (seek && Number.isFinite(shot.start)) {
    localVideo.pause();
    localVideo.currentTime = Math.min(shot.start + 0.01, localVideo.duration || shot.start + 0.01);
  }
  updateShotEditor(shot);
  resetCustomClipRange(shot);
  renderManualShots();
  updateArchiveButtons();
}

function renderManualShots() {
  if (!currentLocalProject || !manualAnalysis) return;
  const shots = manualShots();
  shotStrip.classList.add("manual-mode");
  shotStrip.replaceChildren();
  const analysisLabel = manualAnalysis.mode === "local" ? "本地分析" : "手动拉片";
  timelineSummary.textContent = `${analysisLabel} · ${shots.length} 个镜头`;

  shots.forEach((shot) => {
    const data = manualAnalysis.shotData[shot.key] || defaultShotData();
    const representativeFrame = manualAnalysis.representativeFrames?.[shot.key];
    const button = document.createElement("button");
    button.className = "shot-item manual-shot";
    if (shot.key === selectedManualShotKey) button.classList.add("active");
    if (data.note) button.classList.add("has-note");

    if (representativeFrame?.imageUrl) {
      const image = document.createElement("img");
      image.className = "representative-thumbnail";
      image.alt = `镜头 ${String(shot.index + 1).padStart(3, "0")} 代表静帧`;
      image.src = representativeFrame.updatedAt && !representativeFrame.imageUrl.startsWith("data:")
        ? `${representativeFrame.imageUrl}?v=${representativeFrame.updatedAt}`
        : representativeFrame.imageUrl;
      image.addEventListener("error", () => {
        image.remove();
        button.classList.remove("has-representative");
      });
      button.classList.add("has-representative");
      button.append(image);
    }

    const number = document.createElement("strong");
    number.className = "manual-number";
    number.textContent = `镜 ${String(shot.index + 1).padStart(3, "0")}`;

    const range = document.createElement("span");
    range.className = "manual-range";
    range.textContent = `${formatTimecode(shot.start)} — ${formatTimecode(shot.end)}`;

    const duration = document.createElement("small");
    duration.textContent = `${Math.max(0, shot.end - shot.start).toFixed(1)}s`;

    const confidence = Number(manualAnalysis.cutConfidence[shot.key]);
    if (manualAnalysis.mode === "local" && shot.index > 0 && Number.isFinite(confidence)) {
      const confidenceLabel = document.createElement("em");
      confidenceLabel.className = confidence >= 0.82 ? "cut-confidence high" : "cut-confidence review";
      confidenceLabel.textContent = confidence >= 0.82 ? "高可信" : "建议检查";
      button.append(confidenceLabel);
    }

    button.append(number, range, duration);
    button.addEventListener("click", () => selectManualShot(shot.key));
    shotStrip.append(button);
  });
}

function currentManualShot() {
  const shots = manualShots();
  return shots.find((shot) => shot.key === selectedManualShotKey) || shots[0] || null;
}

function updateRepresentativeFrameControl(shot = currentManualShot()) {
  if (!representativeFrameStatus || !setRepresentativeFrameButton) return;
  const frame = shot ? manualAnalysis?.representativeFrames?.[shot.key] : null;
  if (frame?.source === "manual") {
    representativeFrameStatus.textContent = `已手动指定 · ${formatTimecode(Number(frame.capturedAt) || 0)}`;
  } else if (frame?.imageUrl) {
    representativeFrameStatus.textContent = "已从前、中、后三张中自动选择";
  } else if (isGeneratingRepresentativeFrames) {
    representativeFrameStatus.textContent = "正在自动选择代表画面…";
  } else {
    representativeFrameStatus.textContent = "等待生成代表静帧";
  }
  setRepresentativeFrameButton.disabled = isGeneratingRepresentativeFrames || !shot;
}

function shotsMissingRepresentativeFrames(shots = manualShots()) {
  return shots.filter((shot) => {
    const frame = manualAnalysis?.representativeFrames?.[shot.key];
    const capturedAt = Number(frame?.capturedAt);
    return !frame?.imageUrl
      || !Number.isFinite(capturedAt)
      || capturedAt < shot.start
      || capturedAt > shot.end;
  });
}

async function ensureRepresentativeFrames({
  shots = manualShots(),
  onProgress = null,
} = {}) {
  if (
    isGeneratingRepresentativeFrames
    || !currentLocalProject
    || !manualAnalysis
    || !window.cinemaDesktop?.generateRepresentativeFrames
  ) {
    return false;
  }

  const missingShots = shotsMissingRepresentativeFrames(shots);
  if (!missingShots.length) return true;

  isGeneratingRepresentativeFrames = true;
  updateRepresentativeFrameControl();
  try {
    const batchSize = 80;
    let processedCount = 0;
    let generatedCount = 0;
    for (let startIndex = 0; startIndex < missingShots.length; startIndex += batchSize) {
      const batch = missingShots.slice(startIndex, startIndex + batchSize);
      const result = await window.cinemaDesktop.generateRepresentativeFrames(
        batch.map(({ key, start, end }) => ({ key, start, end })),
        (progress) => {
          const batchPercent = Math.max(0, Math.min(100, Number(progress?.percent) || 0));
          const totalPercent = (
            (processedCount + batch.length * (batchPercent / 100))
            / missingShots.length
          ) * 100;
          onProgress?.(totalPercent);
        }
      );
      if (!result || result.error) {
        showToast(result?.error || "代表静帧没有生成成功，可以稍后手动指定");
        return generatedCount > 0;
      }

      Object.entries(result).forEach(([key, frame]) => {
        const existing = manualAnalysis.representativeFrames[key];
        const shot = manualShots().find((item) => item.key === key);
        const existingTime = Number(existing?.capturedAt);
        if (
          existing?.source === "manual"
          && shot
          && Number.isFinite(existingTime)
          && existingTime >= shot.start
          && existingTime <= shot.end
        ) {
          return;
        }
        manualAnalysis.representativeFrames[key] = {
          ...frame,
          updatedAt: Date.now(),
        };
        generatedCount += 1;
      });
      processedCount += batch.length;
      onProgress?.((processedCount / missingShots.length) * 100);
      if (window.cinemaDesktop?.saveAnalysis) {
        await saveAnalysisToDisk({
          savingDetail: "正在保存代表静帧",
          failureDetail: "代表静帧没有保存成功，请重试",
          quiet: true,
        });
      }
    }
    renderManualShots();
    return generatedCount > 0;
  } finally {
    isGeneratingRepresentativeFrames = false;
    updateRepresentativeFrameControl();
  }
}

async function resumeIncompleteLocalAnalysisAssets() {
  if (
    isResumingLocalAnalysisAssets
    || isLocalAnalyzing
    || manualAnalysis?.mode !== "local"
    || !currentLocalProject
  ) {
    return;
  }

  const shots = manualShots();
  if (!shots.length) return;
  const missingFrames = shotsMissingRepresentativeFrames(shots);
  const analyzedScenes = Object.keys(manualAnalysis?.basicSceneAnalysis?.byShot || {}).length;
  if (!missingFrames.length && analyzedScenes >= shots.length) return;

  isResumingLocalAnalysisAssets = true;
  try {
    const framesReady = missingFrames.length
      ? await ensureRepresentativeFrames({ shots })
      : true;
    if (framesReady && analyzedScenes < shots.length) {
      await analyzeBasicScenes({ shots, silent: true });
    }
  } finally {
    isResumingLocalAnalysisAssets = false;
  }
}

async function setCurrentFrameAsRepresentative() {
  if (!currentLocalProject || !manualAnalysis) {
    showToast("请先导入影片并选中一个镜头");
    return;
  }

  const playbackShot = manualShots().find((shot) => (
    localVideo.currentTime >= shot.start && localVideo.currentTime < shot.end
  ));
  const shot = playbackShot || currentManualShot();
  if (!shot) {
    showToast("当前还没有可设置的镜头");
    return;
  }
  if (shot.key !== selectedManualShotKey) {
    selectedManualShotKey = shot.key;
    updateShotEditor(shot);
    resetCustomClipRange(shot);
  }

  localVideo.pause();
  const imageDataUrl = captureCurrentFrame();
  if (!imageDataUrl) {
    showToast("影片画面还没有准备好，请稍后再试");
    return;
  }

  setRepresentativeFrameButton.disabled = true;
  representativeFrameStatus.textContent = "正在保存当前画面…";
  try {
    const result = window.cinemaDesktop?.saveRepresentativeFrame
      ? await window.cinemaDesktop.saveRepresentativeFrame({
          shotKey: shot.key,
          capturedAt: localVideo.currentTime,
          imageDataUrl,
        })
      : {
          shotKey: shot.key,
          capturedAt: localVideo.currentTime,
          imageUrl: imageDataUrl,
          source: "manual",
        };
    if (!result || result.error) {
      showToast(result?.error || "代表静帧没有保存成功，请重试");
      return;
    }

    const updatedAt = Date.now();
    manualAnalysis.representativeFrames[shot.key] = {
      ...result,
      source: "manual",
      updatedAt,
    };
    if (window.cinemaDesktop?.saveAnalysis) {
      await saveAnalysisToDisk({
        savingDetail: "正在保存代表静帧",
        failureDetail: "代表静帧没有保存成功，请重试",
      });
    }
    await syncRepresentativeFrameAcrossViews(shot, imageDataUrl, manualAnalysis.representativeFrames[shot.key]);
    renderManualShots();
    updateRepresentativeFrameControl(shot);
    await analyzeBasicScenes({ shots: [shot], silent: true });
    showToast("当前画面已设为这个镜头的代表静帧");
  } finally {
    setRepresentativeFrameButton.disabled = false;
  }
}

function resetCustomClipRange(shot = currentManualShot()) {
  if (!shot) {
    customClipIn = null;
    customClipOut = null;
  } else {
    customClipIn = shot.start;
    customClipOut = shot.end;
  }
  updateClipRangePanel();
}

function updateClipRangePanel() {
  const shot = currentManualShot();
  const duration = Number(customClipOut) - Number(customClipIn);
  const validRange = Number.isFinite(duration) && duration >= 0.2;

  if (currentClipSummary) {
    currentClipSummary.textContent = shot
      ? `保存镜头 ${String(shot.index + 1).padStart(3, "0")} · ${(shot.end - shot.start).toFixed(1)} 秒`
      : "按当前镜头的入点和出点保存";
  }
  if (clipInTime) clipInTime.textContent = formatTimecode(customClipIn);
  if (clipOutTime) clipOutTime.textContent = formatTimecode(customClipOut);
  if (clipRangeDuration) clipRangeDuration.textContent = validRange ? `${duration.toFixed(1)} 秒` : "范围无效";
  if (clipRangeHint) {
    clipRangeHint.classList.toggle("invalid", !validRange);
    clipRangeHint.textContent = validRange
      ? "默认使用当前镜头范围，也可以播放到任意位置重新设置。"
      : "入点必须早于出点，片段至少保留 0.2 秒。";
  }
  if (saveCustomClipButton) saveCustomClipButton.disabled = !validRange;
}

function isCurrentShotArchived() {
  const shot = currentManualShot();
  return Boolean(
    currentLocalProject
    && shot
    && archiveFrames.some(
      (record) => record.sourceFilePath === currentLocalProject.filePath && record.shotKey === shot.key
    )
  );
}

function isCurrentShotClipArchived() {
  const shot = currentManualShot();
  return Boolean(
    currentLocalProject
    && shot
    && archiveClips.some(
      (record) => (
        record.sourceFilePath === currentLocalProject.filePath
        && Math.abs(Number(record.start) - shot.start) < 0.05
        && Math.abs(Number(record.end) - shot.end) < 0.05
      )
    )
  );
}

function updateArchiveButtons() {
  const archived = isCurrentShotArchived();
  if (favoriteFrameButton) {
    favoriteFrameButton.classList.toggle("active", archived);
    favoriteFrameButton.textContent = archived ? "◆" : "◇";
    favoriteFrameButton.setAttribute("aria-label", archived ? "该镜头已收藏" : "收藏当前静帧");
  }
  const archiveButton = document.querySelector(".archive-button");
  if (archiveButton) {
    archiveButton.classList.toggle("active", archived);
    const icon = archiveButton.querySelector(".archive-button-icon");
    const label = archiveButton.querySelector(".archive-button-label");
    if (icon) icon.textContent = archived ? "◆" : "◇";
    if (label) label.textContent = archived ? "当前静帧已收藏" : "收藏当前静帧";
  }
  if (archiveCurrentClipButton) {
    const clipArchived = isCurrentShotClipArchived();
    archiveCurrentClipButton.classList.toggle("active", clipArchived);
    const icon = archiveCurrentClipButton.querySelector(".archive-button-icon");
    if (icon) icon.textContent = clipArchived ? "◆" : "◇";
    archiveCurrentClipButton.querySelector("strong").textContent = clipArchived
      ? "当前片段已收藏"
      : "收藏当前片段";
  }
  updateClipRangePanel();
}

function captureCurrentFrame() {
  if (!localVideo.videoWidth || !localVideo.videoHeight || localVideo.readyState < 2) return null;
  const canvas = document.createElement("canvas");
  canvas.width = localVideo.videoWidth;
  canvas.height = localVideo.videoHeight;
  const context = canvas.getContext("2d");
  context.drawImage(localVideo, 0, 0, canvas.width, canvas.height);
  return canvas.toDataURL("image/jpeg", 0.88);
}

function cacheBustedImageUrl(imageUrl, version = Date.now()) {
  if (!imageUrl || imageUrl.startsWith("data:")) return imageUrl || "";
  const cleanUrl = imageUrl.split("?")[0];
  return `${cleanUrl}?v=${encodeURIComponent(version || Date.now())}`;
}

function archiveRecordMatchesShot(record, sourceFilePath, shotKey) {
  return record?.sourceFilePath === sourceFilePath && record?.shotKey === shotKey;
}

function updateArchiveRecordImagesForShot(sourceFilePath, shotKey, imageUrl, capturedAt, updatedAt) {
  const displayUrl = cacheBustedImageUrl(imageUrl, updatedAt);
  const updateRecord = (record) => archiveRecordMatchesShot(record, sourceFilePath, shotKey)
    ? {
        ...record,
        imageUrl: displayUrl || record.imageUrl,
        capturedAt: Number.isFinite(capturedAt) ? capturedAt : record.capturedAt,
      }
    : record;
  archiveFrames = archiveFrames.map(updateRecord);
  archiveClips = archiveClips.map(updateRecord);
}

async function syncRepresentativeFrameAcrossViews(shot, imageDataUrl, frame) {
  if (!currentLocalProject || !shot || !frame) return;
  const sourceFilePath = currentLocalProject.filePath;
  const updatedAt = frame.updatedAt || Date.now();
  const capturedAt = Number(frame.capturedAt);
  const displayUrl = cacheBustedImageUrl(frame.imageUrl || imageDataUrl, updatedAt);

  if (mainFrame && shot.key === selectedManualShotKey && displayUrl) {
    mainFrame.src = displayUrl;
  }

  if (window.cinemaDesktop?.syncArchiveRepresentativeFrame && imageDataUrl) {
    const result = await window.cinemaDesktop.syncArchiveRepresentativeFrame({
      sourceFilePath,
      shotKey: shot.key,
      imageDataUrl,
      capturedAt: Number.isFinite(capturedAt) ? capturedAt : localVideo.currentTime,
    });
    if (result?.error) {
      showToast(result.error);
    } else {
      archiveFrames = Array.isArray(result?.frames) ? result.frames : archiveFrames;
      archiveClips = Array.isArray(result?.clips) ? result.clips : archiveClips;
    }
  }

  updateArchiveRecordImagesForShot(
    sourceFilePath,
    shot.key,
    displayUrl || imageDataUrl,
    Number.isFinite(capturedAt) ? capturedAt : localVideo.currentTime,
    updatedAt
  );
  currentLocalProject.analysis = manualAnalysis;
  projectLibrary = projectLibrary.map((record) => (
    record.filePath === currentLocalProject.filePath
      ? { ...record, analysis: manualAnalysis, updatedAt: currentLocalProject.updatedAt }
      : record
  ));
  renderManualShots();
  renderArchiveFrames();
  renderInspirationContentCards();
  renderInspirationCollections();
  updateInspirationResults();
  renderArchiveDropTargets();
  renderLibraryProjects();
  updateContinueProject(currentLocalProject);
  refreshReportWorkspace();
}

async function archiveCurrentFrame() {
  if (!currentLocalProject || !manualAnalysis) {
    showToast("请先导入影片并选中一个镜头");
    return;
  }
  if (!window.cinemaDesktop?.saveArchiveFrame) {
    showToast("安装测试版后可以把静帧保存在本机");
    return;
  }

  const shot = currentManualShot();
  if (!shot) {
    showToast("当前还没有可收藏的镜头");
    return;
  }
  if (isCurrentShotArchived()) {
    showToast("这个镜头已经收藏过了");
    return;
  }

  saveCurrentShotEditor();
  const imageDataUrl = captureCurrentFrame();
  if (!imageDataUrl) {
    showToast("影片画面还没有准备好，请稍后再试");
    return;
  }

  const shotData = manualAnalysis.shotData[shot.key] || defaultShotData();
  const result = await window.cinemaDesktop.saveArchiveFrame({
    shotKey: shot.key,
    shotNumber: shot.index + 1,
    start: shot.start,
    end: shot.end,
    capturedAt: localVideo.currentTime,
    imageDataUrl,
    note: shotData.note || "",
    tags: [shotData.size, shotData.angle, shotData.movement].filter(Boolean),
  });

  if (!result || result.error) {
    showToast(result?.error || "静帧没有保存成功，请重试");
    return;
  }
  if (!archiveFrames.some((record) => record.id === result.id)) {
    archiveFrames.unshift(result);
  }
  renderArchiveFrames();
  updateArchiveButtons();
  renderCloudSubtitleStatus(cloudSubtitleConfigured);
  renderAITranslationStatus(aiTranslationConfigured);
  refreshReportWorkspace();
  showToast(result.alreadyExists ? "这个镜头已经收藏过了" : "静帧已保存到导演资料库");
}

async function archiveClipRange(start, end) {
  if (!currentLocalProject || !manualAnalysis) {
    showToast("请先导入影片并选中一个镜头");
    return;
  }
  if (!window.cinemaDesktop?.saveArchiveClip) {
    showToast("安装新版测试软件后可以保存片段");
    return;
  }

  const shot = currentManualShot();
  const duration = Number(end) - Number(start);
  if (!shot || !Number.isFinite(duration) || duration < 0.2) {
    showToast("请先设置有效的片段入点和出点");
    return;
  }

  saveCurrentShotEditor();
  const imageDataUrl = captureCurrentFrame();
  if (!imageDataUrl) {
    showToast("影片画面还没有准备好，请稍后再试");
    return;
  }

  const shotData = manualAnalysis.shotData[shot.key] || defaultShotData();
  const result = await window.cinemaDesktop.saveArchiveClip({
    shotKey: shot.key,
    shotNumber: shot.index + 1,
    start,
    end,
    capturedAt: Math.min(Math.max(localVideo.currentTime, start), end),
    imageDataUrl,
    note: shotData.note || "",
    tags: [shotData.size, shotData.angle, shotData.movement].filter(Boolean),
  });

  if (!result || result.error) {
    showToast(result?.error || "片段没有保存成功，请重试");
    return;
  }
  if (!archiveClips.some((record) => record.id === result.id)) {
    archiveClips.unshift(result);
  }
  renderArchiveFrames();
  updateArchiveButtons();
  showToast(result.alreadyExists ? "这个片段已经收藏过了" : "片段已保存到导演资料库");
}

async function archiveCurrentShotClip() {
  const shot = currentManualShot();
  if (!shot) {
    showToast("当前还没有可收藏的镜头");
    return;
  }
  await archiveClipRange(shot.start, shot.end);
}

const previewArchiveFrames = [
  {
    id: "demo-frame-1",
    projectName: "潮汐之后",
    sourceFilePath: "/preview/潮汐之后.mov",
    shotKey: "shot-42",
    shotNumber: 42,
    start: 1878.2,
    end: 1883.6,
    capturedAt: 1878.24,
    imageUrl: "./assets/still-05.png",
    note: "等待让画面保持安静，雨声承担人物没有说出口的部分。",
    tags: ["中景", "平视", "固定"],
    createdAt: "2026-06-08T15:10:00.000Z",
  },
  {
    id: "demo-frame-2",
    projectName: "北岸来信",
    sourceFilePath: "/preview/北岸来信.mov",
    shotKey: "shot-19",
    shotNumber: 19,
    start: 764.1,
    end: 770.8,
    capturedAt: 764.12,
    imageUrl: "./assets/still-03.png",
    note: "门框把人物关系切成两个相互靠近但无法重合的空间。",
    tags: ["全景", "平视", "固定"],
    createdAt: "2026-06-08T14:20:00.000Z",
  },
];

const previewArchiveClips = [
  {
    id: "demo-clip-1",
    projectName: "潮汐之后",
    sourceFilePath: "/preview/潮汐之后.mov",
    shotKey: "shot-86",
    shotNumber: 86,
    start: 3852.72,
    end: 3865.12,
    capturedAt: 3858.4,
    imageUrl: "./assets/still-07.png",
    note: "双人视线不断被前景切断，让重逢保持距离。",
    tags: ["中景", "侧面", "固定"],
    createdAt: "2026-06-08T15:00:00.000Z",
  },
];

const archiveCommonTagOptions = [
  "全景", "中景", "近景", "特写",
  "平视", "俯拍", "仰拍",
  "固定", "推镜", "拉镜", "摇镜", "跟拍",
  "日景", "夜景", "室内", "室外",
];

function normalizeArchiveTags(tags) {
  const seen = new Set();
  return (Array.isArray(tags) ? tags : [])
    .map((tag) => String(tag || "").trim())
    .filter((tag) => {
      const key = tag.toLowerCase();
      if (!tag || seen.has(key)) return false;
      seen.add(key);
      return true;
    })
    .slice(0, 20);
}

function archiveRecordKey(record) {
  return `${record.type}:${record.id}`;
}

function allArchiveRecords() {
  return [
    ...archiveFrames.map((record) => ({ ...record, type: "frame" })),
    ...archiveClips.map((record) => ({ ...record, type: "clip" })),
  ];
}

function sortArchiveRecords(records) {
  return [...records].sort((a, b) => {
    if (archiveSortMode === "film") {
      return String(a.projectName).localeCompare(String(b.projectName), "zh-CN")
        || String(b.createdAt).localeCompare(String(a.createdAt));
    }
    if (archiveSortMode === "shot") {
      return String(a.projectName).localeCompare(String(b.projectName), "zh-CN")
        || Number(a.shotNumber) - Number(b.shotNumber)
        || Number(a.capturedAt) - Number(b.capturedAt);
    }
    return String(b.createdAt).localeCompare(String(a.createdAt));
  });
}

function renderArchiveFilterControls(records) {
  if (archiveProjectFilter) {
    const projectMap = new Map();
    records.forEach((record) => {
      if (!projectMap.has(record.sourceFilePath)) {
        projectMap.set(record.sourceFilePath, record.projectName);
      }
    });
    if (activeArchiveProject !== "all" && !projectMap.has(activeArchiveProject)) {
      activeArchiveProject = "all";
    }
    archiveProjectFilter.replaceChildren();
    const allOption = document.createElement("option");
    allOption.value = "all";
    allOption.textContent = "全部影片";
    archiveProjectFilter.append(allOption);
    [...projectMap.entries()]
      .sort((a, b) => String(a[1]).localeCompare(String(b[1]), "zh-CN"))
      .forEach(([path, name]) => {
        const option = document.createElement("option");
        option.value = path;
        option.textContent = `《${name}》`;
        archiveProjectFilter.append(option);
      });
    archiveProjectFilter.value = activeArchiveProject;
  }

  const tags = [...new Set(records.flatMap((record) => normalizeArchiveTags(record.tags)))]
    .sort((a, b) => a.localeCompare(b, "zh-CN"));
  if (activeArchiveTag !== "all" && !tags.includes(activeArchiveTag)) {
    activeArchiveTag = "all";
  }
  if (archiveTagFilters) {
    archiveTagFilters.replaceChildren();
    ["all", ...tags].forEach((tag) => {
      const button = document.createElement("button");
      button.type = "button";
      button.dataset.archiveTag = tag;
      button.textContent = tag === "all" ? "全部标签" : tag;
      button.classList.toggle("active", activeArchiveTag === tag);
      button.addEventListener("click", () => {
        activeArchiveTag = tag;
        renderArchiveFrames();
      });
      archiveTagFilters.append(button);
    });
  }

  if (archiveSort) archiveSort.value = archiveSortMode;
  if (archiveOrderLabel) {
    archiveOrderLabel.textContent = {
      newest: "按收藏时间 ↓",
      film: "按影片名称 A—Z",
      shot: "按影片与镜号 ↑",
    }[archiveSortMode];
  }
}

function renderArchiveCommonTags(container, selectedTags = [], onSelect) {
  if (!container) return;
  container.replaceChildren();
  archiveCommonTagOptions.forEach((tag) => {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = tag;
    button.classList.toggle("active", selectedTags.includes(tag));
    button.addEventListener("click", () => onSelect(tag));
    container.append(button);
  });
}

function updateArchiveBulkState() {
  if (archiveBulkBar) archiveBulkBar.hidden = !archiveBulkMode;
  archiveBulkButton?.classList.toggle("active", archiveBulkMode);
  if (archiveBulkButton) archiveBulkButton.textContent = archiveBulkMode ? "退出批量" : "批量整理";
  if (archiveSelectedCount) archiveSelectedCount.textContent = `已选择 ${archiveSelectedRecords.size} 项`;
}

function setArchiveBulkMode(enabled) {
  archiveBulkMode = enabled;
  archiveSelectedRecords.clear();
  if (archiveBulkTagInput) archiveBulkTagInput.value = "";
  updateArchiveBulkState();
  renderArchiveFrames();
}

function toggleArchiveRecordSelection(record) {
  const key = archiveRecordKey(record);
  if (archiveSelectedRecords.has(key)) archiveSelectedRecords.delete(key);
  else archiveSelectedRecords.add(key);
  updateArchiveBulkState();
  document
    .querySelector(`.memory-card[data-type="${record.type}"][data-record-id="${record.id}"]`)
    ?.classList.toggle("selected", archiveSelectedRecords.has(key));
}

function renderArchiveDetailTags() {
  if (!archiveCurrentTags) return;
  archiveCurrentTags.replaceChildren();
  archiveDraftTags.forEach((tag) => {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = tag;
    button.setAttribute("aria-label", `移除标签 ${tag}`);
    button.addEventListener("click", () => {
      archiveDraftTags = archiveDraftTags.filter((item) => item !== tag);
      renderArchiveDetailTags();
    });
    archiveCurrentTags.append(button);
  });
  renderArchiveCommonTags(archiveCommonTags, archiveDraftTags, (tag) => {
    archiveDraftTags = archiveDraftTags.includes(tag)
      ? archiveDraftTags.filter((item) => item !== tag)
      : normalizeArchiveTags([...archiveDraftTags, tag]);
    renderArchiveDetailTags();
  });
}

function openArchiveDetail(record) {
  activeArchiveRecord = record;
  archiveDraftTags = normalizeArchiveTags(record.tags);
  if (archiveDetailImage) {
    archiveDetailImage.src = record.imageUrl;
    archiveDetailImage.alt = `《${record.projectName}》镜头 ${record.shotNumber}`;
  }
  if (archiveDetailType) archiveDetailType.textContent = record.type === "clip" ? "片段" : "静帧";
  if (archiveDetailTitle) archiveDetailTitle.textContent = `《${record.projectName}》`;
  if (archiveDetailMeta) {
    archiveDetailMeta.textContent = record.type === "clip"
      ? `镜头 ${String(record.shotNumber).padStart(3, "0")} · ${formatTimecode(record.start)} — ${formatTimecode(record.end)}`
      : `镜头 ${String(record.shotNumber).padStart(3, "0")} · ${formatTimecode(record.capturedAt)}`;
  }
  if (archiveDetailNote) archiveDetailNote.textContent = record.note || "尚未填写导演笔记";
  if (archiveCustomTagInput) archiveCustomTagInput.value = "";
  renderArchiveDetailTags();
  if (archiveDetailOverlay) archiveDetailOverlay.hidden = false;
}

function closeArchiveDetail() {
  if (archiveDetailOverlay) archiveDetailOverlay.hidden = true;
  activeArchiveRecord = null;
  archiveDraftTags = [];
}

function addArchiveCustomTag() {
  const tag = archiveCustomTagInput?.value.trim();
  if (!tag) {
    showToast("请先输入一个标签");
    return;
  }
  archiveDraftTags = normalizeArchiveTags([...archiveDraftTags, tag]);
  archiveCustomTagInput.value = "";
  renderArchiveDetailTags();
}

async function updateArchiveTags(items, mode, tags) {
  const normalizedTags = normalizeArchiveTags(tags);
  if (!items.length || (mode !== "replace" && !normalizedTags.length)) {
    return { error: "请选择资料并填写标签" };
  }

  if (window.cinemaDesktop?.updateArchiveTags) {
    const result = await window.cinemaDesktop.updateArchiveTags({
      items: items.map((record) => ({ id: record.id, type: record.type })),
      mode,
      tags: normalizedTags,
    });
    if (!result || result.error) return result || { error: "标签没有保存成功" };
    archiveFrames = Array.isArray(result.frames) ? result.frames : archiveFrames;
    archiveClips = Array.isArray(result.clips) ? result.clips : archiveClips;
    return result;
  }

  const selectedKeys = new Set(items.map(archiveRecordKey));
  const updateRecords = (records, type) => records.map((record) => {
    if (!selectedKeys.has(`${type}:${record.id}`)) return record;
    const currentTags = normalizeArchiveTags(record.tags);
    if (mode === "replace") return { ...record, tags: normalizedTags };
    if (mode === "remove") {
      return {
        ...record,
        tags: currentTags.filter((tag) => !normalizedTags.includes(tag)),
      };
    }
    return { ...record, tags: normalizeArchiveTags([...currentTags, ...normalizedTags]) };
  });
  archiveFrames = updateRecords(archiveFrames, "frame");
  archiveClips = updateRecords(archiveClips, "clip");
  return { frames: archiveFrames, clips: archiveClips };
}

async function updateArchiveNoteRecord(itemType, itemId, note) {
  if (window.cinemaDesktop?.updateArchiveNote) {
    const result = await window.cinemaDesktop.updateArchiveNote({ itemType, itemId, note });
    if (!result || result.error) {
      return result || { error: "导演笔记没有保存成功" };
    }
    archiveFrames = Array.isArray(result.frames) ? result.frames : archiveFrames;
    archiveClips = Array.isArray(result.clips) ? result.clips : archiveClips;
    return result;
  }

  const records = itemType === "clip" ? archiveClips : archiveFrames;
  const record = records.find((item) => item.id === itemId);
  if (!record) return { error: "这份资料已经不在导演资料库中" };
  record.note = note;
  return { frames: archiveFrames, clips: archiveClips, previewOnly: true };
}

function archiveTagsFromShotData(data) {
  return normalizeArchiveTags([data?.size, data?.angle, data?.movement].filter(Boolean));
}

async function syncArchiveRecordsForCurrentShot() {
  if (!currentLocalProject || !selectedManualShotKey || !manualAnalysis) return;
  const matchesCurrentShot = (record) => (
    record.sourceFilePath === currentLocalProject.filePath
    && record.shotKey === selectedManualShotKey
  );
  if (!archiveFrames.some(matchesCurrentShot) && !archiveClips.some(matchesCurrentShot)) return;

  const shotData = manualAnalysis.shotData?.[selectedManualShotKey] || defaultShotData();
  const note = shotData.note || "";
  const tags = archiveTagsFromShotData(shotData);

  if (window.cinemaDesktop?.syncArchiveShot) {
    const result = await window.cinemaDesktop.syncArchiveShot({
      sourceFilePath: currentLocalProject.filePath,
      shotKey: selectedManualShotKey,
      note,
      tags,
    });
    if (!result || result.error) return;
    archiveFrames = Array.isArray(result.frames) ? result.frames : archiveFrames;
    archiveClips = Array.isArray(result.clips) ? result.clips : archiveClips;
  } else {
    archiveFrames = archiveFrames.map((record) => (
      matchesCurrentShot(record) ? { ...record, note, tags } : record
    ));
    archiveClips = archiveClips.map((record) => (
      matchesCurrentShot(record) ? { ...record, note, tags } : record
    ));
  }

  renderArchiveFrames();
  renderInspirationContentCards();
  updateInspirationResults();
  refreshReportWorkspace();
}

async function removeArchiveFromCollection(collectionId, itemType, itemId) {
  let result;
  if (window.cinemaDesktop?.removeArchiveFromInspiration) {
    result = await window.cinemaDesktop.removeArchiveFromInspiration({
      collectionId,
      itemType,
      itemId,
    });
  } else {
    const before = inspirationMemberships.length;
    inspirationMemberships = inspirationMemberships.filter((membership) => !(
      membership.collectionId === collectionId
      && membership.itemType === itemType
      && membership.itemId === itemId
    ));
    writeBrowserInspirationMemberships(inspirationMemberships);
    result = { removed: before - inspirationMemberships.length, collectionId };
  }
  if (!result || result.error) return result || { error: "没有移出成功，请重试" };
  inspirationMemberships = inspirationMemberships.filter((membership) => !(
    membership.collectionId === collectionId
    && membership.itemType === itemType
    && membership.itemId === itemId
  ));
  return result;
}

async function saveArchiveDetailTags() {
  if (!activeArchiveRecord) return;
  const record = activeArchiveRecord;
  const result = await updateArchiveTags([record], "replace", archiveDraftTags);
  if (!result || result.error) {
    showToast(result?.error || "标签没有保存成功");
    return;
  }
  closeArchiveDetail();
  renderArchiveFrames();
  refreshReportWorkspace();
  showToast("资料标签已保存");
}

async function applyArchiveBulkTag(mode) {
  const tag = archiveBulkTagInput?.value.trim();
  if (!archiveSelectedRecords.size) {
    showToast("请先选择需要整理的资料");
    return;
  }
  if (!tag) {
    showToast("请先选择或输入一个标签");
    return;
  }
  const selectedRecords = allArchiveRecords().filter((record) => (
    archiveSelectedRecords.has(archiveRecordKey(record))
  ));
  const result = await updateArchiveTags(selectedRecords, mode, [tag]);
  if (!result || result.error) {
    showToast(result?.error || "批量标签没有保存成功");
    return;
  }
  archiveBulkTagInput.value = "";
  renderArchiveFrames();
  refreshReportWorkspace();
  showToast(mode === "remove" ? `已批量移除“${tag}”` : `已批量添加“${tag}”`);
}

function chooseArchiveBulkCommonTag(tag) {
  if (archiveBulkTagInput) archiveBulkTagInput.value = tag;
  renderArchiveCommonTags(archiveBulkCommonTags, [tag], chooseArchiveBulkCommonTag);
}

function renderArchiveDropTargets() {
  if (!archiveDropList) return;
  archiveDropList.replaceChildren();
  if (!inspirationCollections.length) {
    const empty = document.createElement("div");
    empty.className = "archive-drop-empty";
    empty.innerHTML = "<strong>还没有收藏夹</strong><small>先到灵感板新建一个主题收藏夹</small>";
    archiveDropList.append(empty);
    return;
  }

  inspirationCollections.forEach((collection) => {
    const target = document.createElement("div");
    target.className = "archive-drop-target";
    target.dataset.dropCollection = collection.id;

    const cover = document.createElement("span");
    cover.className = "archive-drop-cover";
    const coverSource = inspirationCollectionCoverSource(collection.id);
    if (coverSource) {
      const image = document.createElement("img");
      image.src = coverSource;
      image.alt = "";
      cover.append(image);
    } else {
      cover.textContent = collection.name.slice(0, 1).toUpperCase();
    }

    const copy = document.createElement("span");
    const name = document.createElement("strong");
    name.textContent = collection.name;
    const count = document.createElement("small");
    count.textContent = `${inspirationCollectionItemCount(collection.id)} 项资料`;
    copy.append(name, count);
    target.append(cover, copy);
    archiveDropList.append(target);
  });
}

function beginArchiveRecordDrag(record, card, event) {
  draggedArchiveRecord = record;
  card.classList.add("dragging");
  renderArchiveDropTargets();
  if (archiveCollectionDrop) archiveCollectionDrop.hidden = false;
  document.body.classList.add("archive-drag-active");
  event.dataTransfer.effectAllowed = "copy";
  event.dataTransfer.setData("text/plain", `${record.type}:${record.id}`);
}

function finishArchiveRecordDrag(card) {
  card.classList.remove("dragging");
  document.body.classList.remove("archive-drag-active");
  document.querySelectorAll(".archive-drop-target").forEach((target) => {
    target.classList.remove("drag-over");
  });
  if (archiveCollectionDrop) archiveCollectionDrop.hidden = true;
  window.setTimeout(() => {
    draggedArchiveRecord = null;
  }, 0);
}

function renderArchiveFrames() {
  if (!memoryGrid || !archiveEmpty) return;

  const allRecords = allArchiveRecords();
  const sourceProjects = new Set(allRecords.map((record) => record.sourceFilePath));
  const tags = new Set(allRecords.flatMap((record) => record.tags || []));
  archiveFrameCount.textContent = String(archiveFrames.length);
  archiveClipCount.textContent = String(archiveClips.length);
  archiveProjectCount.textContent = String(sourceProjects.size);
  archiveTagCount.textContent = String(tags.size);
  renderArchiveFilterControls(allRecords);
  updateArchiveBulkState();

  const query = archiveSearchQuery.trim().toLowerCase();
  const visibleRecords = sortArchiveRecords(allRecords.filter((record) => {
    const matchesType = activeArchiveFilter === "all" || activeArchiveFilter === record.type;
    const matchesProject = activeArchiveProject === "all"
      || activeArchiveProject === record.sourceFilePath;
    const matchesTag = activeArchiveTag === "all"
      || normalizeArchiveTags(record.tags).includes(activeArchiveTag);
    const haystack = [
      record.projectName,
      `镜头 ${record.shotNumber}`,
      record.type === "clip" ? "片段" : "静帧",
      record.note,
      ...(record.tags || []),
    ].join(" ").toLowerCase();
    return matchesType && matchesProject && matchesTag && (!query || haystack.includes(query));
  }));

  memoryGrid.replaceChildren();
  archiveEmpty.hidden = visibleRecords.length > 0;
  const emptyTitle = archiveEmpty.querySelector("h3");
  const emptyCopy = archiveEmpty.querySelector("p");
  if (allRecords.length && !visibleRecords.length) {
    emptyTitle.textContent = "没有找到符合条件的资料";
    emptyCopy.textContent = "换一个影片名、镜号、标签或笔记关键词试试。";
  } else if (activeArchiveFilter === "clip") {
    emptyTitle.textContent = "还没有收藏片段";
    emptyCopy.textContent = "在拉片工作台选中镜头，一键收藏整镜，或打开自定义范围设置入点和出点。";
  } else if (activeArchiveFilter === "frame") {
    emptyTitle.textContent = "还没有收藏静帧";
    emptyCopy.textContent = "在拉片工作台选中镜头，停在想保留的画面，再点击“收藏当前静帧”。";
  } else {
    emptyTitle.textContent = "还没有收藏资料";
    emptyCopy.textContent = "在拉片工作台收藏静帧或片段，资料会保留原影片和准确时间码。";
  }

  visibleRecords.forEach((record) => {
    const isClip = record.type === "clip";
    const card = document.createElement("article");
    card.className = "memory-card";
    card.dataset.type = record.type;
    card.dataset.recordId = record.id;
    card.tabIndex = 0;
    card.draggable = !archiveBulkMode;
    card.classList.toggle("selected", archiveSelectedRecords.has(archiveRecordKey(record)));
    card.setAttribute("aria-label", archiveBulkMode
      ? `选择《${record.projectName}》${isClip ? "片段" : "镜头"} ${record.shotNumber}`
      : `查看《${record.projectName}》${isClip ? "片段" : "镜头"} ${record.shotNumber}详情`);

    const imageBox = document.createElement("div");
    imageBox.className = "memory-image";
    const image = document.createElement("img");
    image.src = record.imageUrl;
    image.alt = `《${record.projectName}》镜头 ${record.shotNumber}${isClip ? "片段封面" : "静帧"}`;
    image.draggable = false;
    const type = document.createElement("span");
    type.textContent = isClip ? "片段" : "静帧";
    imageBox.append(image, type);
    if (isClip) {
      const play = document.createElement("i");
      play.textContent = "▶";
      imageBox.append(play);
    }

    const copy = document.createElement("div");
    copy.className = "memory-copy";
    const title = document.createElement("h3");
    title.textContent = isClip
      ? `镜头 ${String(record.shotNumber).padStart(3, "0")} · ${(Number(record.end) - Number(record.start)).toFixed(1)} 秒片段`
      : `镜头 ${String(record.shotNumber).padStart(3, "0")} · ${(record.tags || []).slice(0, 2).join(" / ") || "导演收藏"}`;
    const source = document.createElement("p");
    source.textContent = isClip
      ? `《${record.projectName}》 · ${formatTimecode(record.start)} — ${formatTimecode(record.end)}`
      : `《${record.projectName}》 · ${formatTimecode(record.capturedAt)}`;
    const note = document.createElement("p");
    note.className = "memory-note";
    note.textContent = record.note || "尚未填写导演笔记";
    const tagRow = document.createElement("div");
    (record.tags || []).forEach((tag) => {
      const tagElement = document.createElement("span");
      tagElement.textContent = tag;
      tagRow.append(tagElement);
    });
    copy.append(title, source, note, tagRow);
    const dragHint = document.createElement("span");
    dragHint.className = "memory-drag-hint";
    dragHint.textContent = "拖到收藏夹";
    card.append(imageBox, copy);
    if (archiveBulkMode) {
      const selectMark = document.createElement("span");
      selectMark.className = "archive-select-mark";
      selectMark.textContent = "✓";
      card.append(selectMark);
    } else {
      card.append(dragHint);
    }

    let wasDragged = false;
    card.addEventListener("dragstart", (event) => {
      if (archiveBulkMode) {
        event.preventDefault();
        return;
      }
      wasDragged = true;
      beginArchiveRecordDrag(record, card, event);
    });
    card.addEventListener("dragend", () => {
      finishArchiveRecordDrag(card);
      window.setTimeout(() => {
        wasDragged = false;
      }, 80);
    });
    card.addEventListener("click", () => {
      if (wasDragged) return;
      if (archiveBulkMode) toggleArchiveRecordSelection(record);
      else if (record.type === "clip") openArchiveClipRecord(record);
      else openArchiveDetail(record);
    });
    card.addEventListener("keydown", (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        if (archiveBulkMode) toggleArchiveRecordSelection(record);
        else if (record.type === "clip") openArchiveClipRecord(record);
        else openArchiveDetail(record);
      }
    });
    memoryGrid.append(card);
  });
}

async function loadArchiveFrames() {
  if (!window.cinemaDesktop?.getArchiveFrames) {
    if (!archiveFrames.length && !archiveClips.length) {
      archiveFrames = previewArchiveFrames.map((record) => ({ ...record }));
      archiveClips = previewArchiveClips.map((record) => ({ ...record }));
    }
    renderArchiveFrames();
    return;
  }
  const [frameRecords, clipRecords] = await Promise.all([
    window.cinemaDesktop.getArchiveFrames(),
    window.cinemaDesktop.getArchiveClips?.() || [],
  ]);
  archiveFrames = Array.isArray(frameRecords) ? frameRecords : [];
  archiveClips = Array.isArray(clipRecords) ? clipRecords : [];
  renderArchiveFrames();
  updateArchiveButtons();
  refreshReportWorkspace();
  renderLibraryProjects();
}

function seekToArchiveRecord(record) {
  const matchingShot = manualShots().find((shot) => shot.key === record.shotKey);
  if (matchingShot) selectManualShot(matchingShot.key, false);
  const targetTime = Math.max(0, Number(record.capturedAt) || Number(record.start) || 0);
  localVideo.pause();
  localVideo.currentTime = Math.min(targetTime, localVideo.duration || targetTime);
  openPage("workbench");
  showToast(`已返回《${record.projectName}》镜头 ${String(record.shotNumber).padStart(3, "0")}`);
}

async function openArchiveFrameRecord(record) {
  if (!window.cinemaDesktop?.openArchiveFrame) {
    showToast("安装测试版后可以返回原影片时间码");
    return;
  }
  const project = await window.cinemaDesktop.openArchiveFrame({ id: record.id });
  if (!project || project.error) {
    showToast(project?.error || "没有找到原影片");
    return;
  }

  if (currentLocalProject?.filePath === project.filePath && localVideo.readyState >= 1) {
    seekToArchiveRecord(record);
    return;
  }
  pendingArchiveTarget = record;
  selectedManualShotKey = null;
  applyLocalProject(project, true);
}

async function reopenMovedInspirationSource(record, itemType) {
  if (!window.cinemaDesktop?.relinkInspirationSource) {
    return { error: "原影片已经移动，请重新选择影片" };
  }
  const previousPath = record.sourceFilePath;
  const project = await window.cinemaDesktop.relinkInspirationSource({
    id: record.id,
    itemType,
  });
  if (!project || project.error || project.cancelled) return project;
  [...archiveFrames, ...archiveClips].forEach((item) => {
    if (item.sourceFilePath === previousPath) {
      item.sourceFilePath = project.filePath;
      item.sourceFileUrl = project.fileUrl;
    }
  });
  return project;
}

function rememberInspirationSourcePosition() {
  inspirationSourceReturnState = {
    collection: activeInspirationCollection,
    filter: activeInspirationFilter,
    search: inspirationSearchInput?.value || "",
    scrollY: window.scrollY,
  };
}

async function openInspirationSource(card) {
  const itemType = card?.dataset.inspirationType;
  const itemId = card?.dataset.itemId;
  if (!itemId || !["frame", "clip"].includes(itemType)) {
    showToast("这份资料没有可以返回的原片位置");
    return false;
  }
  let record = archiveInspirationRecord(itemType, itemId);
  if (!record) {
    showToast("没有找到这份资料的来源记录");
    return false;
  }
  if (!window.cinemaDesktop) {
    closeInspirationPreview();
    openPage("workbench");
    showToast("安装版会返回原影片的准确时间码");
    return true;
  }

  rememberInspirationSourcePosition();
  let project = itemType === "clip"
    ? await window.cinemaDesktop?.openArchiveClip?.({ id: record.id })
    : await window.cinemaDesktop?.openArchiveFrame?.({ id: record.id });
  if (project?.needsRelink) {
    project = await reopenMovedInspirationSource(record, itemType);
    if (project && !project.error && !project.cancelled) {
      record = {
        ...record,
        sourceFilePath: project.filePath,
        sourceFileUrl: project.fileUrl,
      };
    }
  }
  if (!project || project.error || project.cancelled) {
    inspirationSourceReturnState = null;
    if (project?.error) showToast(project.error);
    return false;
  }

  closeInspirationPreview();
  if (currentLocalProject?.filePath === project.filePath && localVideo.readyState >= 1) {
    if (itemType === "clip") {
      await playArchiveClip({ ...record, continueAfterClip: true });
    } else {
      seekToArchiveRecord(record);
    }
    return true;
  }
  pendingArchiveTarget = itemType === "clip"
    ? { ...record, type: "clip", continueAfterClip: true }
    : record;
  selectedManualShotKey = null;
  applyLocalProject(project, true);
  return true;
}

async function playArchiveClip(record) {
  const matchingShot = manualShots().find((shot) => (
    shot.key === record.shotKey
    || (Number(record.start) >= shot.start && Number(record.start) < shot.end)
  ));
  if (matchingShot) selectManualShot(matchingShot.key, false);
  const start = Math.max(0, Number(record.start) || 0);
  const end = Math.max(start, Number(record.end) || start);
  activeClipPlaybackEnd = end;
  activeClipPlaybackContinue = record.continueAfterClip === true;
  localVideo.currentTime = Math.min(start, localVideo.duration || start);
  openPage("workbench");
  try {
    await localVideo.play();
    showToast(`正在播放《${record.projectName}》收藏片段`);
  } catch {
    showToast(`已返回片段入点 ${formatTimecode(start)}`);
  }
}

async function openArchiveClipRecord(record) {
  if (!window.cinemaDesktop?.openArchiveClip) {
    showToast("安装新版测试软件后可以返回原影片播放片段");
    return;
  }
  const project = await window.cinemaDesktop.openArchiveClip({ id: record.id });
  if (!project || project.error) {
    showToast(project?.error || "没有找到原影片");
    return;
  }

  if (currentLocalProject?.filePath === project.filePath && localVideo.readyState >= 1) {
    await playArchiveClip(record);
    return;
  }
  pendingArchiveTarget = { ...record, type: "clip" };
  selectedManualShotKey = null;
  applyLocalProject(project, true);
}

function addManualCutPoint() {
  if (!currentLocalProject) {
    showToast("请先导入一部本地影片");
    return;
  }
  if (!Number.isFinite(localVideo.duration) || localVideo.duration <= 0) {
    showToast("影片仍在读取，请稍后再添加切点");
    return;
  }

  const time = localVideo.currentTime;
  if (time < 0.12 || time > localVideo.duration - 0.12) {
    showToast("切点需要放在影片内容之间");
    return;
  }
  if (manualAnalysis.cutPoints.some((point) => Math.abs(point - time) < 0.12)) {
    showToast("这里已经有一个切点");
    return;
  }

  saveCurrentShotEditor();
  manualAnalysis.cutPoints.push(time);
  initializeManualAnalysis(localVideo.duration);
  const newKey = shotKey(time);
  manualAnalysis.shotData[newKey] = defaultShotData();
  selectedManualShotKey = newKey;
  updateShotEditor(manualShots().find((shot) => shot.key === newKey));
  renderManualShots();
  scheduleManualSave();
  ensureRepresentativeFrames();
  showToast(`已在 ${formatTimecode(time)} 添加切点`);
}

function transferShotRecordKey(oldKey, newKey, confidence = 1) {
  if (!oldKey || !newKey || oldKey === newKey || !manualAnalysis) return;
  manualAnalysis.shotData[newKey] = manualAnalysis.shotData[oldKey] || defaultShotData();
  manualAnalysis.cutConfidence[newKey] = confidence;
  if (manualAnalysis.representativeFrames?.[oldKey]) {
    manualAnalysis.representativeFrames[newKey] = manualAnalysis.representativeFrames[oldKey];
  }
  if (manualAnalysis.basicSceneAnalysis?.byShot?.[oldKey]) {
    manualAnalysis.basicSceneAnalysis.byShot[newKey] = {
      ...manualAnalysis.basicSceneAnalysis.byShot[oldKey],
      shotKey: newKey,
    };
  }
  delete manualAnalysis.shotData[oldKey];
  delete manualAnalysis.cutConfidence[oldKey];
  delete manualAnalysis.representativeFrames?.[oldKey];
  delete manualAnalysis.basicSceneAnalysis?.byShot?.[oldKey];
}

function moveCutPointAtIndex(boundaryIndex, newTime, { selectedKey = selectedManualShotKey, message } = {}) {
  if (!manualAnalysis?.cutPoints?.length || !Number.isFinite(newTime)) return false;
  if (boundaryIndex <= 0 || boundaryIndex >= manualAnalysis.cutPoints.length - 1) {
    showToast("影片首尾边界不能直接移动");
    return false;
  }

  const previousStart = manualAnalysis.cutPoints[boundaryIndex - 1];
  const nextEnd = manualAnalysis.cutPoints[boundaryIndex + 1];
  if (newTime <= previousStart + 0.12 || newTime >= nextEnd - 0.12) {
    showToast(`请输入 ${formatTimecode(previousStart + 0.12)} 到 ${formatTimecode(nextEnd - 0.12)} 之间的时间码`);
    return false;
  }

  saveCurrentShotEditor();
  const oldKey = shotKey(manualAnalysis.cutPoints[boundaryIndex]);
  const newKey = shotKey(newTime);
  manualAnalysis.cutPoints[boundaryIndex] = newTime;
  transferShotRecordKey(oldKey, newKey, 1);
  initializeManualAnalysis(localVideo.duration);
  selectedManualShotKey = selectedKey === oldKey ? newKey : selectedKey;
  const selectedShot = manualShots().find((shot) => shot.key === selectedManualShotKey) || manualShots()[0];
  if (selectedShot) {
    selectedManualShotKey = selectedShot.key;
    updateShotEditor(selectedShot);
    resetCustomClipRange(selectedShot);
  }
  renderManualShots();
  scheduleManualSave();
  ensureRepresentativeFrames();
  showToast(message || `切点已移动到 ${formatTimecode(newTime)}`);
  return true;
}

function moveSelectedCutPointTo(newTime) {
  const shots = manualShots();
  const selectedShot = shots.find((shot) => shot.key === selectedManualShotKey);
  if (!selectedShot || selectedShot.index === 0) {
    showToast(currentLocalProject ? "第一镜的起点不能移动" : "请先导入一部本地影片");
    return false;
  }
  return moveCutPointAtIndex(selectedShot.index, newTime, {
    selectedKey: selectedShot.key,
    message: `切点已移动到 ${formatTimecode(newTime)}`,
  });
}

function moveSelectedCutPoint() {
  moveSelectedCutPointTo(localVideo.currentTime);
}

function parseTimecodeInput(value) {
  const parts = String(value || "")
    .trim()
    .split(":")
    .map((part) => Number(part));
  if (parts.some((part) => !Number.isFinite(part) || part < 0)) return null;
  if (parts.length === 4) {
    const [hours, minutes, seconds, frames] = parts;
    return hours * 3600 + minutes * 60 + seconds + frames / 25;
  }
  if (parts.length === 3) {
    const [hours, minutes, seconds] = parts;
    return hours * 3600 + minutes * 60 + seconds;
  }
  if (parts.length === 2) {
    const [minutes, seconds] = parts;
    return minutes * 60 + seconds;
  }
  return Number.isFinite(parts[0]) ? parts[0] : null;
}

function selectedMovableCutContext() {
  const shots = manualShots();
  const selectedShot = shots.find((shot) => shot.key === selectedManualShotKey);
  if (!selectedShot || selectedShot.index === 0) return null;
  return {
    selectedShot,
    min: manualAnalysis.cutPoints[selectedShot.index - 1] + 0.12,
    max: manualAnalysis.cutPoints[selectedShot.index + 1] - 0.12,
    current: manualAnalysis.cutPoints[selectedShot.index],
  };
}

function setMoveCutDraft(time) {
  if (!moveCutDraft) return;
  const clamped = Math.max(moveCutDraft.min, Math.min(moveCutDraft.max, Number(time) || 0));
  moveCutDraft.value = clamped;
  if (moveCutSlider) moveCutSlider.value = String(clamped);
  if (moveCutTimeInput) moveCutTimeInput.value = formatTimecode(clamped);
  if (moveCutHint) {
    const durationBefore = clamped - (moveCutDraft.min - 0.12);
    const durationAfter = (moveCutDraft.max + 0.12) - clamped;
    moveCutHint.textContent = `前一镜约 ${durationBefore.toFixed(1)} 秒，后一镜约 ${durationAfter.toFixed(1)} 秒。`;
  }
}

function openMoveCutDialog() {
  const context = selectedMovableCutContext();
  if (!context) {
    showToast(currentLocalProject ? "请先选择第二镜或后面的镜头，再移动它前面的切点" : "请先导入影片");
    return;
  }
  moveCutDraft = { ...context, value: context.current };
  if (moveCutRange) {
    moveCutRange.textContent = `镜头 ${String(context.selectedShot.index + 1).padStart(3, "0")} 前的切点，可在 ${formatTimecode(context.min)} — ${formatTimecode(context.max)} 之间移动。`;
  }
  if (moveCutSlider) {
    moveCutSlider.min = String(context.min);
    moveCutSlider.max = String(context.max);
    moveCutSlider.step = String(frameDuration);
  }
  setMoveCutDraft(context.current);
  if (moveCutOverlay) moveCutOverlay.hidden = false;
  window.setTimeout(() => moveCutSlider?.focus(), 0);
}

function closeMoveCutDialog() {
  if (moveCutOverlay) moveCutOverlay.hidden = true;
  moveCutDraft = null;
}

function confirmMoveCutDialog() {
  if (!moveCutDraft) return;
  const value = parseTimecodeInput(moveCutTimeInput?.value) ?? moveCutDraft.value;
  if (moveSelectedCutPointTo(value)) closeMoveCutDialog();
}

function applyShotTimeInput(field) {
  const shot = currentManualShot();
  if (!currentLocalProject || !manualAnalysis || !shot) {
    showToast("请先打开影片并选择镜头");
    return false;
  }
  const value = parseTimecodeInput(field?.value);
  if (!Number.isFinite(value)) {
    updateShotEditor(shot);
    showToast("请输入有效时间码，例如 00:00:42:18");
    return false;
  }

  if (field === shotInInput) {
    if (shot.index === 0) {
      updateShotEditor(shot);
      showToast("第一镜入点固定在影片开头");
      return false;
    }
    return moveCutPointAtIndex(shot.index, value, {
      selectedKey: shot.key,
      message: `入点已调整为 ${formatTimecode(value)}`,
    });
  }

  if (field === shotOutInput) {
    if (shot.index >= manualAnalysis.cutPoints.length - 2) {
      updateShotEditor(shot);
      showToast("最后一镜出点固定在影片结尾");
      return false;
    }
    return moveCutPointAtIndex(shot.index + 1, value, {
      selectedKey: shot.key,
      message: `出点已调整为 ${formatTimecode(value)}`,
    });
  }

  return false;
}

function deleteSelectedCutPoint() {
  const shots = manualShots();
  const selectedShot = shots.find((shot) => shot.key === selectedManualShotKey);
  if (!selectedShot || selectedShot.index === 0) {
    showToast(currentLocalProject ? "第一镜前没有可以删除的切点" : "请先导入一部本地影片");
    return;
  }

  saveCurrentShotEditor();
  const previousShot = shots[selectedShot.index - 1];
  const previousData = manualAnalysis.shotData[previousShot.key] || defaultShotData();
  const selectedData = manualAnalysis.shotData[selectedShot.key] || defaultShotData();
  if (selectedData.note && !previousData.note.includes(selectedData.note)) {
    previousData.note = [previousData.note, selectedData.note].filter(Boolean).join("\n\n");
  }
  manualAnalysis.shotData[previousShot.key] = previousData;
  manualAnalysis.cutPoints.splice(selectedShot.index, 1);
  delete manualAnalysis.shotData[selectedShot.key];
  delete manualAnalysis.cutConfidence[selectedShot.key];
  delete manualAnalysis.representativeFrames[selectedShot.key];
  delete manualAnalysis.basicSceneAnalysis?.byShot?.[selectedShot.key];
  initializeManualAnalysis(localVideo.duration);
  selectedManualShotKey = previousShot.key;
  updateShotEditor(manualShots().find((shot) => shot.key === previousShot.key));
  renderManualShots();
  scheduleManualSave();
  showToast("切点已删除，前后镜头已安全合并");
}

function applyLocalProject(project, openWorkbench = true) {
  if (!project) return;
  restoreRemovedLibraryProject(project);
  lastVideoErrorFilePath = "";
  currentLocalProject = project;
  manualAnalysis = project.analysis || { cutPoints: [], shotData: {} };
  ensureStructureBoard();
  setSidebarSaveStatus("saved", "原片仅保留在本机");
  appShell.classList.add("local-project");
  localVideo.src = project.fileUrl;
  videoStage.classList.add("has-local-video");
  document.querySelector(".frame-badge").textContent = "本地影片";
  document.querySelector(".workbench-title h2").textContent = project.name;
  document.querySelector(".breadcrumb").textContent = `影片库　/　${project.name}`;
  document.querySelector(".continue-copy h3").textContent = `《${project.name}》`;
  document.querySelector(".continue-copy .film-meta").textContent = project.usingCompatibleCopy
    ? "本地影片 · 已使用兼容副本播放和分析"
    : "本地影片 · 原片仅保留在本机";
  document.querySelector(".continue-copy .film-note").textContent = project.analysis?.mode === "local"
    ? "本地分析已经完成，可以进入工作台检查和修正切点。"
    : "影片已导入，可以进入工作台开始播放和手动拉片。";
  if (project.duration > 0) {
    initializeManualAnalysis(project.duration);
    const firstShot = manualShots()[0];
    if (firstShot) {
      const selectedShot = manualShots().find((shot) => shot.key === selectedManualShotKey) || firstShot;
      selectedManualShotKey = selectedShot.key;
      updateShotEditor(selectedShot);
      renderManualShots();
    }
  }
  if (localVideo.readyState >= 1) scheduleLocalVideoTimeClamp();
  updateArchiveButtons();
  renderStructureBoardPreview();
  refreshReportWorkspace();
  if (!projectLibrary.some((record) => record.filePath === project.filePath)) {
    projectLibrary.unshift(project);
  } else {
    projectLibrary = projectLibrary.map((record) => (
      record.filePath === project.filePath ? project : record
    ));
  }
  renderLibraryProjects();
  if (openWorkbench) openPage("workbench");
}

function showAnalysisChoice(project) {
  analysisChoiceFilm.textContent = project.usingCompatibleCopy
    ? `《${project.name}》已导入，软件会使用兼容副本播放和分析。`
    : `《${project.name}》已导入，原片只保留在你的电脑。`;
  analysisChoice.hidden = false;
  analysisProgress.hidden = true;
  document.querySelector(".analysis-choice-options").hidden = false;
  startLocalAnalysisButton.disabled = false;
  startManualAnalysisButton.disabled = false;
}

function hideAnalysisChoice() {
  analysisChoice.hidden = true;
}

function updateLocalAnalysisProgress(progress) {
  const percent = Math.max(0, Math.min(100, Number(progress?.percent) || 0));
  analysisProgressPercent.textContent = `${percent}%`;
  analysisProgressBar.style.width = `${percent}%`;
  analysisProgressDetail.textContent = progress?.message || (percent >= 100
    ? "正在整理镜头结果…"
    : `已分析到 ${formatTimecode(Number(progress?.seconds) || 0)}`);
}

async function startLocalAnalysis() {
  if (!currentLocalProject || !window.cinemaDesktop?.analyzeLocalVideo || isLocalAnalyzing) return;
  isLocalAnalyzing = true;
  startLocalAnalysisButton.disabled = true;
  startManualAnalysisButton.disabled = true;
  document.querySelector(".analysis-choice-options").hidden = true;
  analysisProgress.hidden = false;
  updateLocalAnalysisProgress({ percent: 0, seconds: 0 });

  const result = await window.cinemaDesktop.analyzeLocalVideo((progress) => {
    if (progress?.phase === "compatibility") {
      updateLocalAnalysisProgress({
        percent: Math.max(1, Math.min(35, Number(progress?.percent) || 8)),
        message: progress?.message || "正在生成兼容副本…",
      });
      return;
    }
    updateLocalAnalysisProgress({
      percent: Math.round((Number(progress?.percent) || 0) * 0.65),
      seconds: progress?.seconds,
      message: progress?.message,
    });
  });
  if (!result || result.error) {
    isLocalAnalyzing = false;
    document.querySelector(".analysis-choice-options").hidden = false;
    analysisProgress.hidden = true;
    startLocalAnalysisButton.disabled = false;
    startManualAnalysisButton.disabled = false;
    showToast(result?.error || "本地分析没有完成，请直接手动拉片");
    return;
  }

  const duration = Number(result.duration) || localVideo.duration || currentLocalProject.duration;
  const cutPoints = [0];
  const cutConfidence = {};
  const subtitles = manualAnalysis?.subtitles;
  const subtitleTranslation = manualAnalysis?.subtitleTranslation;
  const subtitleEdits = manualAnalysis?.subtitleEdits;
  const structureBoard = manualAnalysis?.structureBoard;
  (result.cuts || []).forEach((cut) => {
    const time = Number(cut.time);
    if (!Number.isFinite(time) || time <= 0 || time >= duration) return;
    cutPoints.push(time);
    cutConfidence[shotKey(time)] = Number(cut.confidence) || 0.58;
  });
  cutPoints.push(duration);
  manualAnalysis = {
    mode: "local",
    cutPoints,
    cutConfidence,
    shotData: {},
    representativeFrames: {},
  };
  if (subtitles) manualAnalysis.subtitles = subtitles;
  if (subtitleTranslation) manualAnalysis.subtitleTranslation = subtitleTranslation;
  if (subtitleEdits) manualAnalysis.subtitleEdits = subtitleEdits;
  if (structureBoard) manualAnalysis.structureBoard = structureBoard;
  initializeManualAnalysis(duration);
  selectedManualShotKey = manualShots()[0]?.key || null;
  currentLocalProject = await window.cinemaDesktop.updateProject({ duration }) || {
    ...currentLocalProject,
    duration,
  };
  await saveAnalysisToDisk({
    savingDetail: "正在保存拉片分析",
    failureDetail: "拉片分析没有保存成功，请重试",
  });
  analysisProgressDetail.textContent = "正在从每个镜头的前、中、后三张画面中挑选代表静帧…";
  await ensureRepresentativeFrames({
    onProgress: (percent) => {
      const totalPercent = 65 + Math.round(percent * 0.2);
      analysisProgressPercent.textContent = `${totalPercent}%`;
      analysisProgressBar.style.width = `${totalPercent}%`;
    },
  });
  analysisProgressDetail.textContent = "正在识别人物数量、昼夜与室内外…";
  const basicSceneCompleted = await analyzeBasicScenes({
    silent: true,
    onProgress: (percent) => {
      const totalPercent = 85 + Math.round(percent * 0.1);
      analysisProgressPercent.textContent = `${totalPercent}%`;
      analysisProgressBar.style.width = `${totalPercent}%`;
    },
  });
  analysisProgressDetail.textContent = "正在整理拉片结果…";
  analysisProgressPercent.textContent = "100%";
  analysisProgressBar.style.width = "100%";
  isLocalAnalyzing = false;
  hideAnalysisChoice();
  applyLocalProject(currentLocalProject, true);
  showToast(basicSceneCompleted
    ? `本地分析完成，共识别 ${manualShots().length} 个镜头`
    : `镜头分析已完成，基础识别可以稍后在右侧重新运行`);
}

async function startManualAnalysis() {
  if (!currentLocalProject || isLocalAnalyzing) return;
  manualAnalysis = currentLocalProject.analysis || { cutPoints: [], shotData: {}, cutConfidence: {} };
  manualAnalysis.mode = "manual";
  initializeManualAnalysis(localVideo.duration || currentLocalProject.duration);
  await saveAnalysisToDisk({
    savingDetail: "正在保存手动拉片",
    failureDetail: "手动拉片没有保存成功，请重试",
  });
  hideAnalysisChoice();
  applyLocalProject(currentLocalProject, true);
  showToast("已进入手动拉片");
}

async function importLocalVideo() {
  if (!window.cinemaDesktop) {
    showToast("当前是网页预览，安装测试版后可选择本地影片");
    return;
  }

  const project = await window.cinemaDesktop.selectVideo();
  if (!project) return;
  if (project.error) {
    showToast(project.error);
    return;
  }
  applyLocalProject(project, false);
  const subtitleResult = await window.cinemaDesktop.readSubtitles?.();
  if (subtitleResult && !subtitleResult.error) {
    manualAnalysis.subtitles = subtitleResult;
    updateSubtitleAssignments();
    await saveAnalysisToDisk({
      savingDetail: "正在保存字幕结果",
      failureDetail: "字幕结果没有保存成功，请重试",
    });
  }
  showAnalysisChoice(project);
  await refreshProjectLibrary();
  showToast(subtitleResult?.found
    ? `影片已导入，已读取 ${subtitleResult.cueCount || 0} 条字幕`
    : "影片已导入，未发现已有字幕");
}

const inspirationAllCollection = {
  id: "all",
  name: "全部灵感",
  description: "已加入收藏夹的资料会在这里合并展示，同一份资料只出现一次。",
};

const previewInspirationCollections = [
  {
    id: "atmosphere",
    name: "潮湿城市与孤独",
    description: "雨、玻璃、街道反光，以及人物被城市包围时的情绪参考。",
    createdAt: "2026-06-08T12:00:00.000Z",
    updatedAt: "2026-06-08T12:00:00.000Z",
    lastUsedAt: "2026-06-08T15:00:00.000Z",
  },
  {
    id: "blocking",
    name: "双人调度参考",
    description: "整理双人关系中距离、视线、前景遮挡与空间变化的处理。",
    createdAt: "2026-06-08T11:00:00.000Z",
    updatedAt: "2026-06-08T11:00:00.000Z",
    lastUsedAt: "2026-06-08T14:00:00.000Z",
  },
  {
    id: "color",
    name: "冷色夜景",
    description: "冷蓝与冷紫夜景中的肤色、反光和实景光源参考。",
    createdAt: "2026-06-08T10:00:00.000Z",
    updatedAt: "2026-06-08T10:00:00.000Z",
    lastUsedAt: "2026-06-08T13:00:00.000Z",
  },
];

const inspirationCollectionStorageKey = "cinema-paradiso-inspiration-collections";
const inspirationMembershipStorageKey = "cinema-paradiso-inspiration-memberships";
const inspirationNoteStorageKey = "cinema-paradiso-inspiration-notes";
const inspirationCollectionCoverSources = {
  atmosphere: "./assets/still-05.png",
  blocking: "./assets/still-07.png",
  color: "./assets/still-11.png",
};

const inspirationTypeNames = {
  frame: "STATIC FRAME",
  clip: "VIDEO CLIP",
  image: "IMPORTED IMAGE",
  text: "DIRECTOR'S NOTE",
};

const previewInspirationNotes = [
  {
    id: "preview-note-1",
    title: "孤独感不是空镜",
    body: "让城市始终在人物身后运转。环境越繁忙，人物的停顿就越明显。",
    collectionIds: ["atmosphere"],
    createdAt: "2026-06-08T14:40:00.000Z",
    updatedAt: "2026-06-08T15:20:00.000Z",
  },
  {
    id: "preview-note-2",
    title: "重逢场景的距离变化",
    body: "先让两个人共享同一块背景，再用前景和视线逐渐把他们拆开。",
    collectionIds: ["blocking", "color"],
    createdAt: "2026-06-08T13:20:00.000Z",
    updatedAt: "2026-06-08T14:10:00.000Z",
  },
];

function inspirationCards() {
  return [...document.querySelectorAll(".inspiration-card")];
}

function inspirationCollectionById(id) {
  if (id === "all") return inspirationAllCollection;
  return inspirationCollections.find((collection) => collection.id === id) || null;
}

function inspirationCollectionItemCount(id) {
  const archiveItems = new Set(
    inspirationMemberships
      .filter((membership) => (
        (id === "all" || membership.collectionId === id)
        && archiveInspirationRecord(membership.itemType, membership.itemId)
      ))
      .map((membership) => `${membership.itemType}:${membership.itemId}`)
  );
  const noteItems = inspirationNotes.filter((note) => (
    id === "all" ? note.collectionIds?.length : note.collectionIds?.includes(id)
  ));
  const imageItems = inspirationImages.filter((image) => (
    id === "all" ? image.collectionIds?.length : image.collectionIds?.includes(id)
  ));
  const transientImageCards = window.cinemaDesktop ? [] : inspirationCards().filter((card) => (
    card.dataset.inspirationType === "image"
    && card.dataset.previewDemo !== "true"
    && (
      id === "all"
        ? (card.dataset.collections || "").split(",").some(Boolean)
        : (card.dataset.collections || "").split(",").includes(id)
    )
  ));
  return archiveItems.size + noteItems.length + imageItems.length + transientImageCards.length;
}

function sortInspirationCollections(records) {
  return [...records].sort((a, b) => (
    String(b.lastUsedAt || "").localeCompare(String(a.lastUsedAt || ""))
  ));
}

function readBrowserInspirationCollections() {
  try {
    const stored = localStorage.getItem(inspirationCollectionStorageKey);
    if (stored) {
      const records = JSON.parse(stored);
      if (Array.isArray(records)) return sortInspirationCollections(records);
    }
  } catch {
    // 浏览器预览不可保存时仍保留页面演示。
  }
  const records = previewInspirationCollections.map((collection) => ({ ...collection }));
  writeBrowserInspirationCollections(records);
  return records;
}

function writeBrowserInspirationCollections(records) {
  try {
    localStorage.setItem(inspirationCollectionStorageKey, JSON.stringify(records));
  } catch {
    // 浏览器预览不可保存时不影响当前操作。
  }
}

function previewInspirationMemberships() {
  return inspirationCards().flatMap((card) => {
    if (!["frame", "clip"].includes(card.dataset.inspirationType)) return [];
    const itemId = card.dataset.itemId;
    if (!itemId) return [];
    return (card.dataset.collections || "").split(",").filter(Boolean).map((collectionId) => ({
      id: `preview-${collectionId}-${card.dataset.inspirationType}-${itemId}`,
      collectionId,
      itemType: card.dataset.inspirationType,
      itemId,
      addedAt: "2026-06-08T12:00:00.000Z",
    }));
  });
}

function readBrowserInspirationMemberships() {
  try {
    const stored = localStorage.getItem(inspirationMembershipStorageKey);
    if (stored) {
      const records = JSON.parse(stored);
      if (Array.isArray(records)) return records;
    }
  } catch {
    // 浏览器预览不可保存时仍可体验本次操作。
  }
  const records = previewInspirationMemberships();
  writeBrowserInspirationMemberships(records);
  return records;
}

function writeBrowserInspirationMemberships(records) {
  try {
    localStorage.setItem(inspirationMembershipStorageKey, JSON.stringify(records));
  } catch {
    // 浏览器预览不可保存时不影响当前操作。
  }
}

function readBrowserInspirationNotes() {
  try {
    const stored = localStorage.getItem(inspirationNoteStorageKey);
    if (stored) {
      const records = JSON.parse(stored);
      if (Array.isArray(records)) return records;
    }
  } catch {
    // 浏览器预览不可保存时仍可体验文字卡片。
  }
  const records = previewInspirationNotes.map((note) => ({
    ...note,
    collectionIds: [...note.collectionIds],
  }));
  writeBrowserInspirationNotes(records);
  return records;
}

function writeBrowserInspirationNotes(records) {
  try {
    localStorage.setItem(inspirationNoteStorageKey, JSON.stringify(records));
  } catch {
    // 浏览器预览不可保存时不影响当前操作。
  }
}

function duplicateInspirationCollectionName(name, ignoredId = "") {
  return inspirationCollections.some((collection) => (
    collection.id !== ignoredId
    && collection.name.localeCompare(name, undefined, { sensitivity: "base" }) === 0
  ));
}

function archiveInspirationRecord(itemType, itemId) {
  const records = itemType === "clip" ? archiveClips : archiveFrames;
  return records.find((record) => record.id === itemId) || null;
}

function inspirationCollectionCoverSource(collectionId) {
  const membership = inspirationMemberships
    .filter((item) => item.collectionId === collectionId)
    .sort((a, b) => String(b.addedAt || "").localeCompare(String(a.addedAt || "")))
    .find((item) => archiveInspirationRecord(item.itemType, item.itemId)?.imageUrl);
  return membership
    ? archiveInspirationRecord(membership.itemType, membership.itemId)?.imageUrl
    : inspirationImages.find((image) => image.collectionIds?.includes(collectionId))?.imageUrl
      || inspirationCollectionCoverSources[collectionId];
}

function formatInspirationNoteTime(value) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "刚刚";
  const now = new Date();
  const isToday = date.toDateString() === now.toDateString();
  return isToday
    ? `今天 ${date.toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit" })}`
    : date.toLocaleDateString("zh-CN", { month: "numeric", day: "numeric" });
}

function createInspirationSelectMark() {
  const select = document.createElement("button");
  select.className = "card-select-mark";
  select.type = "button";
  select.setAttribute("aria-label", "选择资料");
  select.textContent = "✓";
  return select;
}

function createArchiveInspirationCard(entry) {
  const { record, itemType, collectionIds } = entry;
  const isClip = itemType === "clip";
  const card = document.createElement("article");
  card.className = "inspiration-card";
  card.dataset.realInspiration = "true";
  card.dataset.inspirationType = itemType;
  card.dataset.itemId = record.id;
  card.dataset.collections = collectionIds.join(",");
  card.dataset.note = record.note || "";
  card.dataset.search = [record.projectName, record.note].filter(Boolean).join(" ");

  const visual = document.createElement("div");
  visual.className = `inspiration-visual${isClip ? " clip-visual" : ""}`;
  const image = document.createElement("img");
  image.src = record.imageUrl;
  image.alt = `《${record.projectName}》镜头 ${record.shotNumber}${isClip ? "片段封面" : "静帧"}`;
  visual.append(image);
  if (isClip) {
    const play = document.createElement("span");
    play.className = "clip-play";
    play.textContent = "▶";
    const duration = document.createElement("small");
    duration.textContent = `${Math.max(0, Number(record.end) - Number(record.start)).toFixed(1)} 秒`;
    visual.append(play, duration);
  }

  const copy = document.createElement("div");
  copy.className = "inspiration-card-copy";
  const heading = document.createElement("div");
  const title = document.createElement("span");
  title.textContent = `《${record.projectName}》`;
  const badge = document.createElement("b");
  badge.textContent = isClip ? "片段" : "静帧";
  heading.append(title, badge);
  const meta = document.createElement("p");
  meta.textContent = isClip
    ? `镜头 ${String(record.shotNumber).padStart(3, "0")} · ${formatTimecode(record.start)}`
    : `镜头 ${String(record.shotNumber).padStart(3, "0")} · ${formatTimecode(record.capturedAt)}`;
  copy.append(heading, meta);
  card.append(createInspirationSelectMark(), visual, copy);
  return card;
}

function createTextInspirationCard(note) {
  const card = document.createElement("article");
  card.className = "inspiration-card text-card";
  card.dataset.realInspiration = "true";
  card.dataset.inspirationType = "text";
  card.dataset.noteId = note.id;
  card.dataset.collections = (note.collectionIds || []).join(",");
  card.dataset.search = [note.title, note.body].filter(Boolean).join(" ");

  const inner = document.createElement("div");
  inner.className = "text-card-inner";
  const type = document.createElement("span");
  type.textContent = "导演随记";
  const title = document.createElement("h4");
  title.textContent = note.title || "未命名文字";
  const body = document.createElement("p");
  body.textContent = note.body || "继续补充这张文字卡片的内容。";
  const saved = document.createElement("small");
  saved.textContent = `${formatInspirationNoteTime(note.updatedAt)} · 已自动保存`;
  inner.append(type, title, body, saved);
  card.append(createInspirationSelectMark(), inner);
  return card;
}

function createImageInspirationCard(imageRecord) {
  const card = document.createElement("article");
  card.className = "inspiration-card";
  card.dataset.realInspiration = "true";
  card.dataset.inspirationType = "image";
  card.dataset.imageId = imageRecord.id;
  card.dataset.collections = (imageRecord.collectionIds || []).join(",");
  card.dataset.note = imageRecord.note || "";
  card.dataset.search = [imageRecord.title, imageRecord.note, "导入图片"].filter(Boolean).join(" ");

  const visual = document.createElement("div");
  visual.className = "inspiration-visual";
  const image = document.createElement("img");
  image.src = imageRecord.imageUrl;
  image.alt = imageRecord.title || "导入图片";
  visual.append(image);

  const copy = document.createElement("div");
  copy.className = "inspiration-card-copy";
  const heading = document.createElement("div");
  const title = document.createElement("span");
  title.textContent = imageRecord.title || "导入图片";
  const badge = document.createElement("b");
  badge.textContent = "导入图片";
  heading.append(title, badge);
  const meta = document.createElement("p");
  meta.textContent = `${formatInspirationNoteTime(imageRecord.updatedAt || imageRecord.createdAt)} · 已保存到本机`;
  copy.append(heading, meta);
  card.append(createInspirationSelectMark(), visual, copy);
  return card;
}

function renderInspirationContentCards() {
  if (!inspirationMasonry) return;
  inspirationMasonry.querySelectorAll('[data-real-inspiration="true"]').forEach((card) => {
    card.remove();
  });

  const archiveEntries = new Map();
  inspirationMemberships.forEach((membership) => {
    const record = archiveInspirationRecord(membership.itemType, membership.itemId);
    if (!record) return;
    const key = `${membership.itemType}:${membership.itemId}`;
    const existing = archiveEntries.get(key);
    if (existing) {
      if (!existing.collectionIds.includes(membership.collectionId)) {
        existing.collectionIds.push(membership.collectionId);
      }
      if (String(membership.addedAt || "") > existing.sortTime) {
        existing.sortTime = String(membership.addedAt || "");
      }
      return;
    }
    archiveEntries.set(key, {
      itemType: membership.itemType,
      record,
      collectionIds: [membership.collectionId],
      sortTime: String(membership.addedAt || ""),
    });
  });

  const entries = [
    ...archiveEntries.values(),
    ...inspirationImages.map((image) => ({
      image,
      sortTime: String(image.updatedAt || image.createdAt || ""),
    })),
    ...inspirationNotes.map((note) => ({
      note,
      sortTime: String(note.updatedAt || note.createdAt || ""),
    })),
  ].sort((a, b) => b.sortTime.localeCompare(a.sortTime));

  const fragment = document.createDocumentFragment();
  entries.forEach((entry) => {
    if (entry.note) fragment.append(createTextInspirationCard(entry.note));
    else if (entry.image) fragment.append(createImageInspirationCard(entry.image));
    else fragment.append(createArchiveInspirationCard(entry));
  });
  inspirationMasonry.insertBefore(fragment, inspirationMasonry.firstChild);
}

function createCollectionListItem(collection) {
  const button = document.createElement("button");
  button.className = "collection-item";
  button.dataset.collection = collection.id;
  button.type = "button";
  button.classList.toggle("active", collection.id === activeInspirationCollection);

  const cover = document.createElement("span");
  cover.className = "collection-cover";
  if (collection.id === "all") {
    cover.classList.add("all-cover");
    cover.textContent = "✦";
  } else if (inspirationCollectionCoverSource(collection.id)) {
    const image = document.createElement("img");
    image.src = inspirationCollectionCoverSource(collection.id);
    image.alt = "";
    cover.append(image);
  } else {
    cover.classList.add("empty-cover");
    cover.textContent = collection.name.slice(0, 1).toUpperCase();
  }

  const copy = document.createElement("span");
  const name = document.createElement("strong");
  name.textContent = collection.name;
  const count = document.createElement("small");
  count.textContent = `${inspirationCollectionItemCount(collection.id)} 项资料`;
  copy.append(name, count);
  button.append(cover, copy);
  return button;
}

function renderInspirationCollections() {
  if (!collectionList) return;
  collectionList.replaceChildren(
    createCollectionListItem(inspirationAllCollection),
    ...inspirationCollections.map(createCollectionListItem)
  );
}

async function loadInspirationCollections() {
  await loadArchiveFrames();
  if (window.cinemaDesktop?.getInspirationCollections) {
    const [records, memberships, notes, images] = await Promise.all([
      window.cinemaDesktop.getInspirationCollections(),
      window.cinemaDesktop.getInspirationMemberships?.() || [],
      window.cinemaDesktop.getInspirationNotes?.() || [],
      window.cinemaDesktop.getInspirationImages?.() || [],
    ]);
    inspirationCollections = Array.isArray(records) ? sortInspirationCollections(records) : [];
    inspirationMemberships = Array.isArray(memberships) ? memberships : [];
    inspirationNotes = Array.isArray(notes) ? notes : [];
    inspirationImages = Array.isArray(images) ? images : [];
  } else {
    inspirationCollections = readBrowserInspirationCollections();
    inspirationMemberships = readBrowserInspirationMemberships();
    inspirationNotes = readBrowserInspirationNotes();
  }
  if (
    activeInspirationCollection !== "all"
    && !inspirationCollectionById(activeInspirationCollection)
  ) {
    activeInspirationCollection = "all";
  }
  renderInspirationContentCards();
  renderInspirationCollections();
  selectInspirationCollection(activeInspirationCollection, { touch: false });
}

async function createInspirationCollectionRecord(collection) {
  if (window.cinemaDesktop?.createInspirationCollection) {
    return window.cinemaDesktop.createInspirationCollection(collection);
  }
  if (duplicateInspirationCollectionName(collection.name)) {
    return { error: "已经有同名收藏夹，请换一个名称" };
  }
  const now = new Date().toISOString();
  const record = {
    id: `collection-${Date.now()}-${Math.random().toString(16).slice(2)}`,
    name: collection.name,
    description: collection.description,
    createdAt: now,
    updatedAt: now,
    lastUsedAt: now,
  };
  inspirationCollections.unshift(record);
  writeBrowserInspirationCollections(inspirationCollections);
  return record;
}

async function updateInspirationCollectionRecord(collection) {
  if (window.cinemaDesktop?.updateInspirationCollection) {
    return window.cinemaDesktop.updateInspirationCollection(collection);
  }
  if (duplicateInspirationCollectionName(collection.name, collection.id)) {
    return { error: "已经有同名收藏夹，请换一个名称" };
  }
  const index = inspirationCollections.findIndex((item) => item.id === collection.id);
  if (index < 0) return { error: "没有找到这个收藏夹" };
  const now = new Date().toISOString();
  const record = {
    ...inspirationCollections[index],
    name: collection.name,
    description: collection.description,
    updatedAt: now,
    lastUsedAt: now,
  };
  inspirationCollections[index] = record;
  writeBrowserInspirationCollections(inspirationCollections);
  return record;
}

async function deleteInspirationCollectionRecord(id) {
  if (window.cinemaDesktop?.deleteInspirationCollection) {
    return window.cinemaDesktop.deleteInspirationCollection({ id });
  }
  inspirationCollections = inspirationCollections.filter((collection) => collection.id !== id);
  inspirationMemberships = inspirationMemberships.filter(
    (membership) => membership.collectionId !== id
  );
  inspirationNotes = inspirationNotes
    .map((note) => ({
      ...note,
      collectionIds: (note.collectionIds || []).filter((collectionId) => collectionId !== id),
    }))
    .filter((note) => note.collectionIds.length);
  writeBrowserInspirationCollections(inspirationCollections);
  writeBrowserInspirationMemberships(inspirationMemberships);
  writeBrowserInspirationNotes(inspirationNotes);
  return { deleted: true, id };
}

async function addArchiveRecordToInspiration(record, collectionId) {
  if (!record || !collectionId) return null;
  const payload = {
    collectionId,
    itemType: record.type,
    itemId: record.id,
  };
  let result;
  if (window.cinemaDesktop?.addArchiveRecordToInspiration) {
    result = await window.cinemaDesktop.addArchiveRecordToInspiration(payload);
  } else {
    const existing = inspirationMemberships.find((membership) => (
      membership.collectionId === collectionId
      && membership.itemType === record.type
      && membership.itemId === record.id
    ));
    if (existing) {
      result = { ...existing, alreadyExists: true };
    } else {
      result = {
        id: `membership-${Date.now()}-${Math.random().toString(16).slice(2)}`,
        ...payload,
        addedAt: new Date().toISOString(),
      };
      inspirationMemberships.unshift(result);
      writeBrowserInspirationMemberships(inspirationMemberships);
    }
  }

  if (!result || result.error) {
    showToast(result?.error || "资料没有加入收藏夹，请重试");
    return result;
  }
  if (!result.alreadyExists && !inspirationMemberships.some((item) => item.id === result.id)) {
    inspirationMemberships.unshift(result);
  }
  renderInspirationContentCards();
  renderInspirationCollections();
  updateInspirationResults();
  renderArchiveDropTargets();
  const collection = inspirationCollectionById(collectionId);
  showToast(result.alreadyExists
    ? `这份资料已经在“${collection?.name || "该收藏夹"}”中`
    : `已加入“${collection?.name || "收藏夹"}”`);
  return result;
}

async function upsertInspirationNoteRecord(note) {
  if (window.cinemaDesktop?.upsertInspirationNote) {
    return window.cinemaDesktop.upsertInspirationNote(note);
  }
  const validCollectionIds = [...new Set(
    (note.collectionIds || []).filter((id) => inspirationCollectionById(id))
  )];
  const title = String(note.title || "").trim();
  const body = String(note.body || "").trim();
  if (!title && !body) return { error: "请写下标题或正文" };
  if (!validCollectionIds.length) return { error: "请至少选择一个收藏夹" };
  const index = inspirationNotes.findIndex((record) => record.id === note.id);
  const now = new Date().toISOString();
  const record = {
    id: index >= 0
      ? inspirationNotes[index].id
      : `note-${Date.now()}-${Math.random().toString(16).slice(2)}`,
    title: title || "未命名文字",
    body,
    collectionIds: validCollectionIds,
    createdAt: index >= 0 ? inspirationNotes[index].createdAt : now,
    updatedAt: now,
  };
  if (index >= 0) {
    inspirationNotes[index] = record;
  } else {
    inspirationNotes.unshift(record);
  }
  writeBrowserInspirationNotes(inspirationNotes);
  return record;
}

function selectedNoteCollectionIds() {
  if (!noteCollectionOptions) return [];
  return [...noteCollectionOptions.querySelectorAll('input[type="checkbox"]:checked')]
    .map((input) => input.value);
}

function setNoteSaveState(message, saved = false) {
  if (!noteSaveState) return;
  noteSaveState.textContent = message;
  noteSaveState.classList.toggle("saved", saved);
}

function renderNoteCollectionOptions(selectedIds = []) {
  if (!noteCollectionOptions) return;
  noteCollectionOptions.replaceChildren();
  inspirationCollections.forEach((collection) => {
    const label = document.createElement("label");
    const input = document.createElement("input");
    input.type = "checkbox";
    input.value = collection.id;
    input.checked = selectedIds.includes(collection.id);
    const name = document.createElement("span");
    name.textContent = collection.name;
    label.append(input, name);
    noteCollectionOptions.append(label);
  });
}

function saveInspirationNoteNow() {
  clearTimeout(noteSaveTimer);
  noteSaveQueue = noteSaveQueue.catch(() => null).then(async () => {
    const title = noteTitleInput?.value || "";
    const body = noteBodyInput?.value || "";
    const collectionIds = selectedNoteCollectionIds();
    if (!title.trim() && !body.trim()) {
      setNoteSaveState("等待输入");
      return null;
    }
    if (!collectionIds.length) {
      setNoteSaveState("请选择至少一个收藏夹");
      return { error: "请至少选择一个收藏夹" };
    }

    setNoteSaveState("正在自动保存…");
    const result = await upsertInspirationNoteRecord({
      id: editingInspirationNoteId || undefined,
      title,
      body,
      collectionIds,
    });
    if (!result || result.error) {
      setNoteSaveState(result?.error || "保存没有完成，请重试");
      return result;
    }

    editingInspirationNoteId = result.id;
    const index = inspirationNotes.findIndex((note) => note.id === result.id);
    if (index >= 0) {
      inspirationNotes[index] = result;
    } else {
      inspirationNotes.unshift(result);
    }
    renderInspirationContentCards();
    renderInspirationCollections();
    updateInspirationResults();
    setNoteSaveState("✓ 已自动保存到本机", true);
    return result;
  });
  return noteSaveQueue;
}

function scheduleInspirationNoteSave() {
  clearTimeout(noteSaveTimer);
  setNoteSaveState("等待自动保存…");
  noteSaveTimer = window.setTimeout(saveInspirationNoteNow, 500);
}

function openInspirationNoteEditor(note = null) {
  if (!noteEditorOverlay || !noteTitleInput || !noteBodyInput) return;
  if (!inspirationCollections.length) {
    showToast("请先新建一个收藏夹，再写文字卡片");
    return;
  }
  clearTimeout(noteSaveTimer);
  editingInspirationNoteId = note?.id || null;
  noteEditorTitle.textContent = note ? "编辑文字卡片" : "新建文字卡片";
  noteTitleInput.value = note?.title || "";
  noteBodyInput.value = note?.body || "";
  const selectedIds = note?.collectionIds?.length
    ? note.collectionIds
    : activeInspirationCollection === "all" ? [] : [activeInspirationCollection];
  renderNoteCollectionOptions(selectedIds);
  setNoteSaveState(note ? "✓ 已自动保存到本机" : (
    selectedIds.length ? "等待输入" : "请选择至少一个收藏夹"
  ), Boolean(note));
  noteEditorOverlay.hidden = false;
  window.setTimeout(() => noteTitleInput.focus(), 0);
}

async function closeInspirationNoteEditor() {
  if (!noteEditorOverlay || noteEditorOverlay.hidden) return;
  const hasContent = Boolean(noteTitleInput?.value.trim() || noteBodyInput?.value.trim());
  if (hasContent && !selectedNoteCollectionIds().length) {
    setNoteSaveState("请选择至少一个收藏夹");
    return;
  }
  if (hasContent) await saveInspirationNoteNow();
  noteEditorOverlay.hidden = true;
  editingInspirationNoteId = null;
}

function touchInspirationCollectionRecord(id) {
  if (window.cinemaDesktop?.touchInspirationCollection) {
    window.cinemaDesktop.touchInspirationCollection({ id });
    return;
  }
  const index = inspirationCollections.findIndex((collection) => collection.id === id);
  if (index < 0) return;
  inspirationCollections[index] = {
    ...inspirationCollections[index],
    lastUsedAt: new Date().toISOString(),
  };
  writeBrowserInspirationCollections(inspirationCollections);
}

function finishInspirationBulkMode() {
  inspirationBulkMode = false;
  inspirationWorkspace?.classList.remove("bulk-mode");
  inspirationBulkButton?.classList.remove("active");
  if (inspirationBulkButton) inspirationBulkButton.textContent = "批量整理";
  if (inspirationBulkBar) inspirationBulkBar.hidden = true;
  inspirationCards().forEach((card) => card.classList.remove("selected"));
  if (inspirationSelectedCount) inspirationSelectedCount.textContent = "0";
}

function updateInspirationSelectionCount() {
  if (!inspirationSelectedCount) return;
  inspirationSelectedCount.textContent = String(
    inspirationCards().filter((card) => card.classList.contains("selected")).length
  );
}

function updateInspirationResults() {
  const query = (inspirationSearchInput?.value || "").trim().toLowerCase();
  let visibleCount = 0;
  inspirationCards().forEach((card) => {
    if (
      card.dataset.previewDemo === "true"
      && (window.cinemaDesktop || card.dataset.inspirationType !== "image")
    ) {
      card.hidden = true;
      return;
    }
    const collections = (card.dataset.collections || "").split(",").filter(Boolean);
    const matchesCollection = activeInspirationCollection === "all"
      || collections.includes(activeInspirationCollection);
    const matchesType = activeInspirationFilter === "all"
      || card.dataset.inspirationType === activeInspirationFilter;
    const matchesSearch = !query || (card.dataset.search || "").toLowerCase().includes(query);
    const visible = matchesCollection && matchesType && matchesSearch;
    card.hidden = !visible;
    if (visible) visibleCount += 1;
  });
  if (inspirationResultCount) inspirationResultCount.textContent = `${visibleCount} 项资料`;
  if (inspirationEmpty) inspirationEmpty.hidden = visibleCount > 0;
  if (inspirationMasonry) inspirationMasonry.hidden = visibleCount === 0;
}

function selectInspirationCollection(collection, options = {}) {
  finishInspirationBulkMode();
  activeInspirationCollection = inspirationCollectionById(collection) ? collection : "all";
  document.querySelectorAll(".collection-item").forEach((button) => {
    button.classList.toggle("active", button.dataset.collection === activeInspirationCollection);
  });
  const copy = inspirationCollectionById(activeInspirationCollection) || inspirationAllCollection;
  if (inspirationCollectionTitle) inspirationCollectionTitle.textContent = copy.name;
  if (inspirationCollectionDescription) inspirationCollectionDescription.textContent = copy.description;
  if (manageInspirationCollectionButton) {
    manageInspirationCollectionButton.hidden = activeInspirationCollection === "all";
  }
  if (options.touch !== false && activeInspirationCollection !== "all") {
    touchInspirationCollectionRecord(activeInspirationCollection);
  }
  updateInspirationResults();
}

function selectInspirationFilter(filter) {
  finishInspirationBulkMode();
  activeInspirationFilter = filter;
  document.querySelectorAll("[data-inspiration-filter]").forEach((button) => {
    button.classList.toggle("active", button.dataset.inspirationFilter === filter);
  });
  updateInspirationResults();
}

function toggleInspirationCardSelection(card) {
  if (!card || card.hidden) return;
  card.classList.toggle("selected");
  updateInspirationSelectionCount();
}

function closeInspirationPreview() {
  flushInspirationPreviewNoteSave();
  if (inspirationPreviewOverlay) inspirationPreviewOverlay.hidden = true;
  activeInspirationCard = null;
}

function renderInspirationPreviewCollections(card) {
  if (!inspirationPreviewCollectionList) return;
  const collectionIds = (card.dataset.collections || "").split(",").filter(Boolean);
  const manageable = card.dataset.realInspiration === "true"
    && Boolean(card.dataset.itemId)
    && ["frame", "clip"].includes(card.dataset.inspirationType);
  inspirationPreviewCollectionList.replaceChildren();
  inspirationCollections.forEach((collection) => {
    const label = document.createElement("label");
    const input = document.createElement("input");
    input.type = "checkbox";
    input.checked = collectionIds.includes(collection.id);
    input.disabled = !manageable;
    input.dataset.collectionId = collection.id;
    label.append(input, document.createTextNode(collection.name));
    inspirationPreviewCollectionList.append(label);
  });
}

function openInspirationPreview(card) {
  if (!card || !inspirationPreviewOverlay) return;
  flushInspirationPreviewNoteSave();
  activeInspirationCard = card;
  const type = card.dataset.inspirationType;
  const image = card.querySelector(".inspiration-visual img");
  const title = card.querySelector(".inspiration-card-copy span")?.textContent
    || card.querySelector(".text-card-inner h4")?.textContent
    || "灵感资料";
  const meta = card.querySelector(".inspiration-card-copy p")?.textContent
    || card.querySelector(".text-card-inner small")?.textContent
    || "文字卡片";
  const text = card.querySelector(".text-card-inner p")?.textContent;

  inspirationPreviewMedia?.classList.toggle("text-preview", type === "text");
  if (inspirationPreviewImage) {
    inspirationPreviewImage.hidden = type === "text";
    if (image) {
      inspirationPreviewImage.src = image.src;
      inspirationPreviewImage.alt = image.alt;
    }
  }
  if (inspirationPreviewPlay) inspirationPreviewPlay.hidden = type !== "clip";
  if (inspirationPreviewType) inspirationPreviewType.textContent = inspirationTypeNames[type] || "INSPIRATION";
  if (inspirationPreviewTitle) inspirationPreviewTitle.textContent = title;
  if (inspirationPreviewMeta) inspirationPreviewMeta.textContent = meta;
  if (inspirationPreviewNote) {
    inspirationPreviewNote.value = text
      || card.dataset.note
      || (card.dataset.search || "").split(" ").slice(-5).join(" ")
      || "可以在这里补充导演笔记。";
  }
  renderInspirationPreviewCollections(card);
  if (inspirationReturnSource) inspirationReturnSource.hidden = type === "image" || type === "text";
  if (inspirationRemoveCard) {
    inspirationRemoveCard.textContent = activeInspirationCollection === "all"
      ? "管理收藏夹"
      : "移出当前收藏夹";
  }
  inspirationPreviewOverlay.hidden = false;
}

function flushInspirationPreviewNoteSave() {
  clearTimeout(inspirationPreviewNoteSaveTimer);
  const pending = pendingInspirationPreviewNoteSave;
  pendingInspirationPreviewNoteSave = null;
  if (!pending) return inspirationPreviewNoteSaveQueue;

  inspirationPreviewNoteSaveQueue = inspirationPreviewNoteSaveQueue.then(async () => {
    const result = await updateArchiveNoteRecord(
      pending.itemType,
      pending.itemId,
      pending.note
    );
    if (!result || result.error) {
      showToast(result?.error || "导演笔记没有保存成功");
      return result;
    }
    pending.card.dataset.note = pending.note;
    const record = archiveInspirationRecord(pending.itemType, pending.itemId);
    pending.card.dataset.search = [record?.projectName, pending.note].filter(Boolean).join(" ");
    showToast(result.previewOnly ? "预览中已更新导演笔记" : "导演笔记已保存");
    return result;
  });
  return inspirationPreviewNoteSaveQueue;
}

function scheduleInspirationPreviewNoteSave(card, note) {
  pendingInspirationPreviewNoteSave = {
    card,
    itemType: card.dataset.inspirationType,
    itemId: card.dataset.itemId,
    note,
  };
  clearTimeout(inspirationPreviewNoteSaveTimer);
  inspirationPreviewNoteSaveTimer = window.setTimeout(
    flushInspirationPreviewNoteSave,
    500
  );
}

async function addImportedInspirationImages(files) {
  if (!inspirationMasonry) return;
  const targetCollection = activeInspirationCollection === "all"
    ? inspirationCollections[0]?.id
    : activeInspirationCollection;
  if (!targetCollection) {
    showToast("请先新建一个收藏夹，再导入图片");
    return;
  }
  if (window.cinemaDesktop?.importInspirationImages) {
    const result = await window.cinemaDesktop.importInspirationImages({
      collectionId: targetCollection,
    });
    if (result?.error) {
      showToast(result.error);
      return;
    }
    if (result?.cancelled) return;
    inspirationImages = Array.isArray(result?.images) ? result.images : inspirationImages;
    renderInspirationContentCards();
    renderInspirationCollections();
    updateInspirationResults();
    showToast(`已导入 ${result?.importedCount || 0} 张图片，并保存到本机`);
    return;
  }
  if (!files?.length) return;
  [...files].forEach((file) => {
    const card = document.createElement("article");
    card.className = "inspiration-card";
    card.dataset.inspirationType = "image";
    card.dataset.collections = targetCollection;
    card.dataset.search = `${file.name} 导入图片`;

    const select = document.createElement("button");
    select.className = "card-select-mark";
    select.type = "button";
    select.setAttribute("aria-label", "选择资料");
    select.textContent = "✓";

    const visual = document.createElement("div");
    visual.className = "inspiration-visual";
    const image = document.createElement("img");
    image.src = URL.createObjectURL(file);
    image.alt = file.name;
    visual.append(image);

    const copy = document.createElement("div");
    copy.className = "inspiration-card-copy";
    const heading = document.createElement("div");
    const title = document.createElement("span");
    title.textContent = file.name.replace(/\.[^.]+$/, "");
    const badge = document.createElement("b");
    badge.textContent = "导入图片";
    heading.append(title, badge);
    const meta = document.createElement("p");
    meta.textContent = `${inspirationCollectionById(targetCollection)?.name || "灵感收藏"} · 刚刚导入`;
    copy.append(heading, meta);
    card.append(select, visual, copy);
    inspirationMasonry.prepend(card);
  });
  updateInspirationResults();
  showToast(`已导入 ${files.length} 张图片，并复制保存到当前收藏夹`);
}

function updateCollectionEditorCounts() {
  if (collectionNameCount) {
    collectionNameCount.textContent = String(collectionNameInput?.value.length || 0);
  }
  if (collectionDescriptionCount) {
    collectionDescriptionCount.textContent = String(
      collectionDescriptionInput?.value.length || 0
    );
  }
}

function showCollectionEditorError(message = "") {
  if (!collectionEditorError) return;
  collectionEditorError.textContent = message;
  collectionEditorError.hidden = !message;
}

function openCollectionEditor(collection = null) {
  if (!collectionEditorOverlay || !collectionNameInput || !collectionDescriptionInput) return;
  editingInspirationCollectionId = collection?.id || null;
  collectionEditorTitle.textContent = collection ? "管理主题收藏夹" : "新建主题收藏夹";
  collectionEditorIntro.textContent = collection
    ? "修改名称或整理方向后会自动保存在本机。"
    : "为一组创作参考起个名字，并写下一句清晰的整理方向。";
  collectionNameInput.value = collection?.name || "";
  collectionDescriptionInput.value = collection?.description || "";
  deleteInspirationCollectionButton.hidden = !collection;
  saveInspirationCollectionButton.textContent = collection ? "保存修改" : "创建并进入";
  saveInspirationCollectionButton.disabled = false;
  showCollectionEditorError();
  updateCollectionEditorCounts();
  collectionEditorOverlay.hidden = false;
  window.setTimeout(() => collectionNameInput.focus(), 0);
}

function closeCollectionEditor() {
  if (collectionEditorOverlay) collectionEditorOverlay.hidden = true;
  editingInspirationCollectionId = null;
  showCollectionEditorError();
}

function openCollectionDeleteConfirmation() {
  const collection = inspirationCollectionById(editingInspirationCollectionId);
  if (!collection || !collectionDeleteOverlay) return;
  const title = document.querySelector("#collection-delete-title");
  if (title) title.textContent = `删除“${collection.name}”？`;
  collectionDeleteOverlay.hidden = false;
}

function closeCollectionDeleteConfirmation() {
  if (collectionDeleteOverlay) collectionDeleteOverlay.hidden = true;
}

async function saveInspirationCollection(event) {
  event.preventDefault();
  const name = (collectionNameInput?.value || "").trim();
  const description = (collectionDescriptionInput?.value || "").trim();
  if (!name || !description) {
    showCollectionEditorError("请填写收藏夹名称和一句说明");
    return;
  }
  if (duplicateInspirationCollectionName(name, editingInspirationCollectionId || "")) {
    showCollectionEditorError("已经有同名收藏夹，请换一个名称");
    return;
  }

  const isEditing = Boolean(editingInspirationCollectionId);
  saveInspirationCollectionButton.disabled = true;
  saveInspirationCollectionButton.textContent = isEditing ? "正在保存…" : "正在创建…";
  const result = isEditing
    ? await updateInspirationCollectionRecord({
      id: editingInspirationCollectionId,
      name,
      description,
    })
    : await createInspirationCollectionRecord({ name, description });

  if (!result || result.error) {
    showCollectionEditorError(result?.error || "收藏夹没有保存成功，请重试");
    saveInspirationCollectionButton.disabled = false;
    saveInspirationCollectionButton.textContent = isEditing ? "保存修改" : "创建并进入";
    return;
  }

  const existingIndex = inspirationCollections.findIndex((collection) => (
    collection.id === result.id
  ));
  if (existingIndex >= 0) {
    inspirationCollections[existingIndex] = result;
  } else {
    inspirationCollections.unshift(result);
  }
  renderInspirationCollections();
  closeCollectionEditor();
  selectInspirationCollection(result.id, { touch: false });
  showToast(isEditing ? "收藏夹修改已保存" : "收藏夹已创建并自动进入");
}

async function confirmDeleteInspirationCollection() {
  const id = editingInspirationCollectionId;
  if (!id) return;
  confirmCollectionDeleteButton.disabled = true;
  confirmCollectionDeleteButton.textContent = "正在删除…";
  const result = await deleteInspirationCollectionRecord(id);
  confirmCollectionDeleteButton.disabled = false;
  confirmCollectionDeleteButton.textContent = "确认删除";
  if (!result || result.error) {
    closeCollectionDeleteConfirmation();
    showCollectionEditorError(result?.error || "收藏夹没有删除成功，请重试");
    return;
  }
  inspirationCollections = inspirationCollections.filter((collection) => collection.id !== id);
  inspirationMemberships = inspirationMemberships.filter(
    (membership) => membership.collectionId !== id
  );
  inspirationNotes = inspirationNotes
    .map((note) => ({
      ...note,
      collectionIds: (note.collectionIds || []).filter((collectionId) => collectionId !== id),
    }))
    .filter((note) => note.collectionIds.length);
  activeInspirationCollection = "all";
  await loadInspirationCollections();
  closeCollectionDeleteConfirmation();
  closeCollectionEditor();
  showToast("收藏夹已删除，原始静帧和片段仍保留");
}

launchContinueButton?.addEventListener("click", handleLaunchContinue);
launchNewProjectButton?.addEventListener("click", async () => {
  closeLaunchScreen();
  await importLocalVideo();
});
launchGuideButton?.addEventListener("click", () => {
  closeLaunchScreen();
  openNewUserGuide({ remember: true });
});
launchSkipButton?.addEventListener("click", () => {
  closeLaunchScreen();
  openPage("library");
});
guideCloseButton?.addEventListener("click", () => closeNewUserGuide());
guideLaterButton?.addEventListener("click", () => closeNewUserGuide());
guideDoneButton?.addEventListener("click", () => closeNewUserGuide());
newUserGuideOverlay?.addEventListener("click", (event) => {
  if (event.target === newUserGuideOverlay) closeNewUserGuide();
});
newUserGuideOverlay?.addEventListener("click", async (event) => {
  const action = event.target.closest("[data-guide-action]")?.dataset.guideAction;
  if (action) await handleGuideAction(action);
});

startLocalAnalysisButton?.addEventListener("click", startLocalAnalysis);
startManualAnalysisButton?.addEventListener("click", startManualAnalysis);

navItems.forEach((item) => {
  item.addEventListener("click", () => openPage(item.dataset.page));
});

document.querySelectorAll("[data-page-jump]").forEach((item) => {
  item.addEventListener("click", () => openPage(item.dataset.pageJump));
});

collectionList?.addEventListener("click", (event) => {
  const button = event.target.closest(".collection-item");
  if (!button) return;
  selectInspirationCollection(button.dataset.collection);
});

archiveDropList?.addEventListener("dragover", (event) => {
  const target = event.target.closest(".archive-drop-target");
  if (!target || !draggedArchiveRecord) return;
  event.preventDefault();
  event.dataTransfer.dropEffect = "copy";
  document.querySelectorAll(".archive-drop-target").forEach((item) => {
    item.classList.toggle("drag-over", item === target);
  });
});

archiveDropList?.addEventListener("dragleave", (event) => {
  const target = event.target.closest(".archive-drop-target");
  target?.classList.remove("drag-over");
});

archiveDropList?.addEventListener("drop", async (event) => {
  const target = event.target.closest(".archive-drop-target");
  const record = draggedArchiveRecord;
  if (!target || !record) return;
  event.preventDefault();
  target.classList.remove("drag-over");
  await addArchiveRecordToInspiration(record, target.dataset.dropCollection);
});

document.querySelector("#inspiration-filters")?.addEventListener("click", (event) => {
  const button = event.target.closest("[data-inspiration-filter]");
  if (!button) return;
  selectInspirationFilter(button.dataset.inspirationFilter);
});

document.querySelector("#collapse-collection-panel")?.addEventListener("click", () => {
  inspirationLayout?.classList.toggle("collection-collapsed");
});

inspirationSearchInput?.addEventListener("input", updateInspirationResults);

inspirationBulkButton?.addEventListener("click", () => {
  inspirationBulkMode = !inspirationBulkMode;
  inspirationWorkspace?.classList.toggle("bulk-mode", inspirationBulkMode);
  inspirationBulkButton.classList.toggle("active", inspirationBulkMode);
  inspirationBulkButton.textContent = inspirationBulkMode ? "退出整理" : "批量整理";
  if (inspirationBulkBar) inspirationBulkBar.hidden = !inspirationBulkMode;
  if (!inspirationBulkMode) {
    inspirationCards().forEach((card) => card.classList.remove("selected"));
    updateInspirationSelectionCount();
  }
});

inspirationMasonry?.addEventListener("click", (event) => {
  const card = event.target.closest(".inspiration-card");
  if (!card) return;
  if (inspirationBulkMode || event.target.closest(".card-select-mark")) {
    toggleInspirationCardSelection(card);
    return;
  }
  if (card.dataset.inspirationType === "text" && card.dataset.noteId) {
    const note = inspirationNotes.find((record) => record.id === card.dataset.noteId);
    if (note) openInspirationNoteEditor(note);
    return;
  }
  openInspirationPreview(card);
});

document.querySelector("#inspiration-bulk-bar")?.addEventListener("click", (event) => {
  const action = event.target.closest("[data-bulk-action]")?.dataset.bulkAction;
  if (!action) return;
  const count = inspirationCards().filter((card) => card.classList.contains("selected")).length;
  if (action === "cancel") {
    finishInspirationBulkMode();
    return;
  }
  if (!count) {
    showToast("请先选择需要整理的资料");
    return;
  }
  showToast(action === "add"
    ? `已选择 ${count} 项资料，可以加入多个收藏夹`
    : `已将 ${count} 项资料移出当前收藏夹 · 可撤销`);
});

document.querySelector("#import-inspiration-images")?.addEventListener("click", () => {
  if (window.cinemaDesktop?.importInspirationImages) {
    addImportedInspirationImages();
    return;
  }
  inspirationImageInput?.click();
});

inspirationImageInput?.addEventListener("change", async () => {
  await addImportedInspirationImages(inspirationImageInput.files);
  inspirationImageInput.value = "";
});

document.querySelector("#new-inspiration-collection")?.addEventListener("click", () => {
  openCollectionEditor();
});

document.querySelector("#new-inspiration-note")?.addEventListener("click", () => {
  openInspirationNoteEditor();
});

noteTitleInput?.addEventListener("input", scheduleInspirationNoteSave);
noteBodyInput?.addEventListener("input", scheduleInspirationNoteSave);
noteCollectionOptions?.addEventListener("change", scheduleInspirationNoteSave);
noteEditorClose?.addEventListener("click", closeInspirationNoteEditor);
finishNoteEditorButton?.addEventListener("click", closeInspirationNoteEditor);
noteEditorOverlay?.addEventListener("click", (event) => {
  if (event.target === noteEditorOverlay) closeInspirationNoteEditor();
});

manageInspirationCollectionButton?.addEventListener("click", () => {
  const collection = inspirationCollectionById(activeInspirationCollection);
  if (collection && collection.id !== "all") openCollectionEditor(collection);
});

collectionEditorForm?.addEventListener("submit", saveInspirationCollection);
collectionNameInput?.addEventListener("input", () => {
  updateCollectionEditorCounts();
  showCollectionEditorError();
});
collectionDescriptionInput?.addEventListener("input", () => {
  updateCollectionEditorCounts();
  showCollectionEditorError();
});
collectionEditorClose?.addEventListener("click", closeCollectionEditor);
cancelCollectionEditorButton?.addEventListener("click", closeCollectionEditor);
collectionEditorOverlay?.addEventListener("click", (event) => {
  if (event.target === collectionEditorOverlay) closeCollectionEditor();
});
deleteInspirationCollectionButton?.addEventListener("click", openCollectionDeleteConfirmation);
cancelCollectionDeleteButton?.addEventListener("click", closeCollectionDeleteConfirmation);
collectionDeleteOverlay?.addEventListener("click", (event) => {
  if (event.target === collectionDeleteOverlay) closeCollectionDeleteConfirmation();
});
confirmCollectionDeleteButton?.addEventListener("click", confirmDeleteInspirationCollection);
document.addEventListener("keydown", (event) => {
  const isEditableTarget = ["INPUT", "TEXTAREA", "SELECT"].includes(event.target?.tagName)
    || Boolean(event.target?.isContentEditable);
  if (event.key === "Escape" && newUserGuideOverlay && !newUserGuideOverlay.hidden) {
    event.preventDefault();
    closeNewUserGuide();
    return;
  }
  if (event.key === "Escape" && launchScreen && !launchScreen.hidden) {
    event.preventDefault();
    closeLaunchScreen();
    openPage("library");
    return;
  }
  if (
    structureBoardOverlay
    && !structureBoardOverlay.hidden
    && !isEditableTarget
    && (event.key === "Delete" || event.key === "Backspace")
  ) {
    event.preventDefault();
    deleteStructureNode(activeStructureNodeId || "root");
    return;
  }
  if (event.key !== "Escape") return;
  if (collectionDeleteOverlay && !collectionDeleteOverlay.hidden) {
    closeCollectionDeleteConfirmation();
  } else if (libraryCategoryEditorOverlay && !libraryCategoryEditorOverlay.hidden) {
    closeLibraryCategoryEditor();
  } else if (noteEditorOverlay && !noteEditorOverlay.hidden) {
    closeInspirationNoteEditor();
  } else if (collectionEditorOverlay && !collectionEditorOverlay.hidden) {
    closeCollectionEditor();
  } else if (structureBoardOverlay && !structureBoardOverlay.hidden) {
    closeStructureBoard();
  }
});

document.querySelector("#inspiration-empty")?.addEventListener("click", (event) => {
  const action = event.target.closest("[data-empty-action]")?.dataset.emptyAction;
  if (action === "add") {
    openPage("archive");
    showToast("从资料卡拖到左侧收藏夹，即可加入灵感板");
  }
  if (action === "text") openInspirationNoteEditor();
});

inspirationPreviewClose?.addEventListener("click", closeInspirationPreview);
inspirationPreviewOverlay?.addEventListener("click", (event) => {
  if (event.target === inspirationPreviewOverlay) closeInspirationPreview();
});

inspirationPreviewPlay?.addEventListener("click", async () => {
  if (!activeInspirationCard) return;
  inspirationPreviewPlay.disabled = true;
  inspirationPreviewPlay.textContent = "正在打开原片…";
  await openInspirationSource(activeInspirationCard);
  inspirationPreviewPlay.disabled = false;
  inspirationPreviewPlay.textContent = "▶ 继续播放原片";
});

inspirationPreviewNote?.addEventListener("input", () => {
  const card = activeInspirationCard;
  if (
    !card
    || card.dataset.realInspiration !== "true"
    || !card.dataset.itemId
    || !["frame", "clip"].includes(card.dataset.inspirationType)
  ) {
    return;
  }
  scheduleInspirationPreviewNoteSave(card, inspirationPreviewNote.value);
});

inspirationPreviewCollectionList?.addEventListener("change", async (event) => {
  const card = activeInspirationCard;
  const input = event.target.closest('input[type="checkbox"]');
  if (
    !card
    || !input
    || card.dataset.realInspiration !== "true"
    || !card.dataset.itemId
    || !["frame", "clip"].includes(card.dataset.inspirationType)
  ) {
    return;
  }

  input.disabled = true;
  const itemType = card.dataset.inspirationType;
  const itemId = card.dataset.itemId;
  const collectionId = input.dataset.collectionId;
  let result;
  if (input.checked) {
    const record = archiveInspirationRecord(itemType, itemId);
    result = await addArchiveRecordToInspiration(
      record ? { ...record, type: itemType } : null,
      collectionId
    );
  } else {
    result = await removeArchiveFromCollection(collectionId, itemType, itemId);
  }

  if (!result || result.error) {
    input.checked = !input.checked;
    input.disabled = false;
    if (result?.error) showToast(result.error);
    return;
  }

  const collectionIds = new Set(
    (card.dataset.collections || "").split(",").filter(Boolean)
  );
  if (input.checked) collectionIds.add(collectionId);
  else collectionIds.delete(collectionId);
  card.dataset.collections = [...collectionIds].join(",");
  input.disabled = false;
  if (!input.checked) {
    renderInspirationContentCards();
    renderInspirationCollections();
    updateInspirationResults();
    renderArchiveDropTargets();
    showToast("已移出收藏夹");
  }
});

inspirationReturnSource?.addEventListener("click", async () => {
  if (!activeInspirationCard) return;
  inspirationReturnSource.disabled = true;
  const originalText = inspirationReturnSource.textContent;
  inspirationReturnSource.textContent = "正在打开原片…";
  await openInspirationSource(activeInspirationCard);
  inspirationReturnSource.disabled = false;
  inspirationReturnSource.textContent = originalText;
});

inspirationRemoveCard?.addEventListener("click", async () => {
  const card = activeInspirationCard;
  if (!card) return;
  if (activeInspirationCollection === "all") {
    showToast("可以勾选上方收藏夹来管理这份资料");
    return;
  }
  if (
    card.dataset.realInspiration !== "true"
    || !card.dataset.itemId
    || !["frame", "clip"].includes(card.dataset.inspirationType)
  ) {
    return;
  }

  inspirationRemoveCard.disabled = true;
  const result = await removeArchiveFromCollection(
    activeInspirationCollection,
    card.dataset.inspirationType,
    card.dataset.itemId
  );
  inspirationRemoveCard.disabled = false;
  if (!result || result.error) {
    showToast(result?.error || "没有移出成功，请重试");
    return;
  }
  closeInspirationPreview();
  renderInspirationContentCards();
  renderInspirationCollections();
  updateInspirationResults();
  renderArchiveDropTargets();
  showToast("已移出当前收藏夹，导演资料库中的原资料仍保留");
});

directorAnalysisTab?.addEventListener("click", () => setWorkbenchSideTab("analysis"));
basicSceneTab?.addEventListener("click", () => setWorkbenchSideTab("basic"));
subtitleDialogueTab?.addEventListener("click", () => setWorkbenchSideTab("subtitles"));
analyzeBasicScenesButton?.addEventListener("click", () => analyzeBasicScenes());
retryReadSubtitlesButton?.addEventListener("click", retryReadExistingSubtitles);

document.querySelectorAll("[data-basic-field][data-basic-value]").forEach((button) => {
  button.addEventListener("click", () => {
    const shot = currentManualShot();
    const sceneAnalysis = ensureBasicSceneAnalysis();
    if (!shot || !sceneAnalysis) {
      showToast("请先导入影片并选中一个镜头");
      return;
    }
    const field = button.dataset.basicField;
    sceneAnalysis.byShot[shot.key] = {
      ...(sceneAnalysis.byShot[shot.key] || { shotKey: shot.key }),
      [field]: {
        value: button.dataset.basicValue,
        confidence: 1,
        source: "manual",
        updatedAt: new Date().toISOString(),
      },
    };
    renderBasicScenePanel();
    if (basicSceneSaveState) basicSceneSaveState.textContent = "正在保存人工结果…";
    scheduleManualSave();
  });
});

document.querySelectorAll(".view-switch button").forEach((button) => {
  button.addEventListener("click", () => {
    document.querySelectorAll(".view-switch button").forEach((item) => item.classList.remove("active"));
    button.classList.add("active");
    showToast("预览中：已切换项目视图");
  });
});

globalSearchInput?.addEventListener("input", () => {
  const activePage = document.querySelector(".page.active")?.id || "";
  const value = globalSearchInput.value || "";
  if (activePage !== "library-page") {
    return;
  }
  librarySearchQuery = value;
  libraryExpanded = Boolean(value.trim()) || activeProjectCategory !== "all";
  renderLibraryProjects();
});

addLibraryCategoryButton?.addEventListener("click", openLibraryCategoryEditor);
addLibraryCategoryInlineButton?.addEventListener("click", openLibraryCategoryEditor);
backToLibraryButton?.addEventListener("click", openLibraryHome);
libraryCategoryEditorClose?.addEventListener("click", closeLibraryCategoryEditor);
libraryCategoryEditorCancel?.addEventListener("click", closeLibraryCategoryEditor);
libraryCategoryEditorOverlay?.addEventListener("click", (event) => {
  if (event.target === libraryCategoryEditorOverlay) closeLibraryCategoryEditor();
});
libraryCategoryForm?.addEventListener("submit", async (event) => {
  event.preventDefault();
  await createLibraryCategory(libraryCategoryNameInput?.value);
});

viewAllProjectsButton?.addEventListener("click", () => {
  libraryExpanded = !libraryExpanded;
  renderLibraryProjects();
  projectGrid?.scrollIntoView({ behavior: "smooth", block: "start" });
  showToast(libraryExpanded ? "已展开全部最近项目" : "已收起最近项目");
});

projectOverviewClose?.addEventListener("click", closeProjectOverview);
projectOverviewCancel?.addEventListener("click", closeProjectOverview);
projectOverviewContinue?.addEventListener("click", () => {
  closeProjectOverview();
  openPage("workbench");
});
projectOverviewOverlay?.addEventListener("click", (event) => {
  if (event.target === projectOverviewOverlay) closeProjectOverview();
});

moveCutClose?.addEventListener("click", closeMoveCutDialog);
moveCutCancel?.addEventListener("click", closeMoveCutDialog);
moveCutOverlay?.addEventListener("click", (event) => {
  if (event.target === moveCutOverlay) closeMoveCutDialog();
});
moveCutSlider?.addEventListener("input", () => setMoveCutDraft(Number(moveCutSlider.value)));
moveCutTimeInput?.addEventListener("change", () => {
  const value = parseTimecodeInput(moveCutTimeInput.value);
  if (value == null || !moveCutDraft || value < moveCutDraft.min || value > moveCutDraft.max) {
    showToast("请输入前后镜头之间的有效时间码");
    setMoveCutDraft(moveCutDraft?.value || 0);
    return;
  }
  setMoveCutDraft(value);
});
moveCutTimeInput?.addEventListener("keydown", (event) => {
  if (event.key === "Enter") {
    event.preventDefault();
    confirmMoveCutDialog();
  }
});
moveCutUsePlayhead?.addEventListener("click", () => {
  if (!hasPlayableLocalVideo() || !moveCutDraft) {
    showToast("请先打开影片");
    return;
  }
  setMoveCutDraft(localVideo.currentTime);
});
moveCutConfirm?.addEventListener("click", confirmMoveCutDialog);

document.querySelectorAll(".shot-item").forEach((shot) => {
  shot.addEventListener("click", () => {
    document.querySelectorAll(".shot-item").forEach((item) => item.classList.remove("active"));
    shot.classList.add("active");
    document.querySelector("#main-frame").src = `./assets/still-${shot.dataset.frame}.png`;
    document.querySelector(".frame-badge").textContent = `镜头 ${shot.dataset.shot}`;
    analysisShotLabel.textContent = `镜头 ${shot.dataset.shot}`;
  });
});

document.querySelectorAll(".selectable button").forEach((button) => {
  button.addEventListener("click", () => {
    document.querySelectorAll(".selectable button").forEach((item) => item.classList.remove("selected"));
    button.classList.add("selected");
    if (currentLocalProject) scheduleManualSave();
  });
});

[shotAngleSelect, shotMovementSelect].forEach((field) => {
  field.addEventListener("change", scheduleManualSave);
});

directorNote.addEventListener("input", scheduleManualSave);

[shotInInput, shotOutInput].forEach((field) => {
  field?.addEventListener("focus", () => field.select());
  field?.addEventListener("change", () => applyShotTimeInput(field));
  field?.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      event.preventDefault();
      field.blur();
    }
    if (event.key === "Escape") {
      event.preventDefault();
      updateShotEditor(currentManualShot());
      field.blur();
    }
  });
});

openStructureBoardButton?.addEventListener("click", openStructureBoard);
structureBoardPreview?.addEventListener("click", openStructureBoard);
structureBoardClose?.addEventListener("click", closeStructureBoard);
structureBoardDone?.addEventListener("click", closeStructureBoard);
structureBoardOverlay?.addEventListener("click", (event) => {
  if (event.target === structureBoardOverlay) closeStructureBoard();
});
structureAddTopicButton?.addEventListener("click", () => addStructureNode("root"));
structureAddBranchButton?.addEventListener("click", () => addStructureNode(activeStructureNodeId || "root"));
structureRenameNodeButton?.addEventListener("click", () => renameStructureNode(activeStructureNodeId || "root"));
structureAutoLayoutButton?.addEventListener("click", autoLayoutStructureBoard);
window.addEventListener("pointermove", updateStructureNodeDrag);
window.addEventListener("pointerup", finishStructureNodeDrag);
window.addEventListener("pointercancel", finishStructureNodeDrag);

document.querySelectorAll("#archive-page .filter-tabs button").forEach((button) => {
  button.addEventListener("click", () => {
    document.querySelectorAll("#archive-page .filter-tabs button").forEach((item) => item.classList.remove("active"));
    button.classList.add("active");
    activeArchiveFilter = button.dataset.filter;
    renderArchiveFrames();
  });
});

archiveSearchInput?.addEventListener("input", () => {
  archiveSearchQuery = archiveSearchInput.value;
  renderArchiveFrames();
});

archiveMoreFiltersButton?.addEventListener("click", () => {
  const willOpen = archiveFilterPanel.hidden;
  archiveFilterPanel.hidden = !willOpen;
  archiveMoreFiltersButton.classList.toggle("active", willOpen);
  archiveMoreFiltersButton.setAttribute("aria-expanded", String(willOpen));
});

archiveProjectFilter?.addEventListener("change", () => {
  activeArchiveProject = archiveProjectFilter.value;
  renderArchiveFrames();
});

archiveSort?.addEventListener("change", () => {
  archiveSortMode = archiveSort.value;
  renderArchiveFrames();
});

archiveClearFilters?.addEventListener("click", () => {
  activeArchiveFilter = "all";
  activeArchiveProject = "all";
  activeArchiveTag = "all";
  archiveSortMode = "newest";
  archiveSearchQuery = "";
  if (archiveSearchInput) archiveSearchInput.value = "";
  document.querySelectorAll("#archive-page .filter-tabs button").forEach((button) => {
    button.classList.toggle("active", button.dataset.filter === "all");
  });
  renderArchiveFrames();
  showToast("筛选条件已清除");
});

archiveBulkButton?.addEventListener("click", () => {
  setArchiveBulkMode(!archiveBulkMode);
});

archiveBulkFinish?.addEventListener("click", () => {
  setArchiveBulkMode(false);
});

archiveBulkAddTag?.addEventListener("click", () => applyArchiveBulkTag("add"));
archiveBulkRemoveTag?.addEventListener("click", () => applyArchiveBulkTag("remove"));
archiveBulkTagInput?.addEventListener("keydown", (event) => {
  if (event.key === "Enter") {
    event.preventDefault();
    applyArchiveBulkTag("add");
  }
});
renderArchiveCommonTags(archiveBulkCommonTags, [], chooseArchiveBulkCommonTag);

archiveDetailClose?.addEventListener("click", closeArchiveDetail);
archiveDetailOverlay?.addEventListener("click", (event) => {
  if (event.target === archiveDetailOverlay) closeArchiveDetail();
});
archiveAddCustomTag?.addEventListener("click", addArchiveCustomTag);
archiveCustomTagInput?.addEventListener("keydown", (event) => {
  if (event.key === "Enter") {
    event.preventDefault();
    addArchiveCustomTag();
  }
});
archiveSaveTags?.addEventListener("click", saveArchiveDetailTags);
archiveReturnSource?.addEventListener("click", () => {
  if (!activeArchiveRecord) return;
  const record = activeArchiveRecord;
  closeArchiveDetail();
  if (record.type === "clip") openArchiveClipRecord(record);
  else openArchiveFrameRecord(record);
});

favoriteFrameButton?.addEventListener("click", archiveCurrentFrame);
archiveCurrentClipButton?.addEventListener("click", archiveCurrentShotClip);

toggleClipRangeButton?.addEventListener("click", () => {
  const willOpen = clipRangePanel.hidden;
  clipRangePanel.hidden = !willOpen;
  toggleClipRangeButton.setAttribute("aria-expanded", String(willOpen));
  if (willOpen && (!Number.isFinite(customClipIn) || !Number.isFinite(customClipOut))) {
    resetCustomClipRange();
  }
});

setClipInButton?.addEventListener("click", () => {
  if (!currentLocalProject || localVideo.readyState < 1) {
    showToast("请先打开影片");
    return;
  }
  customClipIn = localVideo.currentTime;
  updateClipRangePanel();
  showToast(`入点已设为 ${formatTimecode(customClipIn)}`);
});

setClipOutButton?.addEventListener("click", () => {
  if (!currentLocalProject || localVideo.readyState < 1) {
    showToast("请先打开影片");
    return;
  }
  customClipOut = localVideo.currentTime;
  updateClipRangePanel();
  showToast(`出点已设为 ${formatTimecode(customClipOut)}`);
});

saveCustomClipButton?.addEventListener("click", async () => {
  await archiveClipRange(customClipIn, customClipOut);
});

document.querySelectorAll("[data-action]").forEach((button) => {
  button.addEventListener("click", async () => {
    if (button.dataset.action === "new-project") {
      await importLocalVideo();
      return;
    }

    if (button.dataset.action === "export") {
      openPage("export");
      return;
    }

    if (button.dataset.action === "add-shot") {
      addManualCutPoint();
      return;
    }

    if (button.dataset.action === "move-cut") {
      openMoveCutDialog();
      return;
    }

    if (button.dataset.action === "delete-cut") {
      deleteSelectedCutPoint();
      return;
    }

    if (button.dataset.action === "archive") {
      await archiveCurrentFrame();
      return;
    }

    if (button.dataset.action === "export-pdf") {
      openReportWindow(true);
      return;
    }

    if (button.dataset.action === "export-excel") {
      await exportExcelWorkbook();
      return;
    }

    if (button.dataset.action === "export-frames") {
      await exportDirectorFramePackage();
      return;
    }

    if (button.dataset.action === "preview") {
      openProjectOverview();
      return;
    }

    const messages = {
      ai: "预览中：AI辅助分析面板",
    };
    showToast(messages[button.dataset.action] || "预览操作");
  });
});

const reportFrame = document.querySelector("#report-preview-frame");
const reportPageInputs = [...document.querySelectorAll("[data-report-page]")];
const reportFieldInputs = [...document.querySelectorAll("[data-report-field]")];
const previewPageLabel = document.querySelector("#preview-page-label");
const exportPageCount = document.querySelector("#export-page-count");
const sceneCount = document.querySelector("#scene-count");
const previewPrev = document.querySelector("#preview-prev");
const previewNext = document.querySelector("#preview-next");
const openFullReportButton = document.querySelector("#open-full-report");
const exportReportButton = document.querySelector('[data-action="export-pdf"]');
const exportExcelButton = document.querySelector('[data-action="export-excel"]');
const exportFramesButton = document.querySelector('[data-action="export-frames"]');
const reportFilmImage = document.querySelector("#report-film-image");
const reportFilmPlaceholder = document.querySelector("#report-film-placeholder");
const reportFilmName = document.querySelector("#report-film-name");
const reportFilmMeta = document.querySelector("#report-film-meta");
const reportSelectedMark = document.querySelector("#report-selected-film .selected-mark");
const reportShotRange = document.querySelector("#report-shot-range");
let currentPreviewPage = 0;
let latestReportData = null;
const openedReportWindows = new Set();

function selectedReportPages() {
  return reportPageInputs.filter((input) => input.checked).map((input) => input.dataset.reportPage);
}

function reportDateLabel() {
  return new Intl.DateTimeFormat("zh-CN", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
}

function reportDialogueForShot(shotKeyValue) {
  const assignment = manualAnalysis?.subtitleAssignments?.byShot?.[shotKeyValue];
  const cues = Array.isArray(assignment?.cues) ? assignment.cues : [];
  const isChinese = isChineseSubtitleSource();
  const items = cues.flatMap((cue) => {
    const original = String(cue?.text || "").trim();
    const translated = String(cue?.translatedText || "").trim();
    const primary = isChinese ? original : translated || original;
    const secondary = !isChinese && translated && original && translated !== original ? original : "";
    if (!primary && !secondary) return [];
    return [{
      cueIndex: Number(cue.cueIndex),
      start: Number(cue.start) || 0,
      end: Number(cue.end) || 0,
      primary,
      secondary,
    }];
  });
  return {
    items,
    text: items.map((item) => (
      item.secondary
        ? `${item.primary}\n原文：${item.secondary}`
        : item.primary
    )).join("\n\n"),
  };
}

function reportBasicSceneText(shotKeyValue) {
  const result = manualAnalysis?.basicSceneAnalysis?.byShot?.[shotKeyValue];
  if (!result) return "";
  const values = [result.people?.value, result.timeOfDay?.value, result.setting?.value]
    .map((value) => String(value || "").trim())
    .filter(Boolean);
  return values.length ? `基础识别：${values.join(" · ")}` : "";
}

function buildCurrentReportData() {
  if (!currentLocalProject || !manualAnalysis) return null;
  saveCurrentShotEditor();
  const archivedFrames = archiveFrames.filter(
    (record) => record.sourceFilePath === currentLocalProject.filePath
  );
  const archivedFrameByShot = new Map(archivedFrames.map((record) => [record.shotKey, record]));
  const shots = manualShots().map((shot) => {
    const shotData = manualAnalysis.shotData[shot.key] || defaultShotData();
    const archivedFrame = archivedFrameByShot.get(shot.key);
    const representativeFrame = manualAnalysis.representativeFrames?.[shot.key];
    const dialogue = reportDialogueForShot(shot.key);
    const imageUrl = archivedFrame?.imageUrl || representativeFrame?.imageUrl || "";
    return {
      key: shot.key,
      number: shot.index + 1,
      start: shot.start,
      end: shot.end,
      size: shotData.size || "",
      angle: shotData.angle || "",
      movement: shotData.movement || "",
      action: reportBasicSceneText(shot.key),
      sound: "",
      dialogueItems: dialogue.items,
      dialogueText: dialogue.text,
      note: shotData.note || "",
      imageUrl,
      imageSource: archivedFrame?.imageUrl ? "archive" : (representativeFrame?.imageUrl ? "representative" : ""),
    };
  });
  const noteCount = shots.filter((shot) => shot.note.trim()).length;
  const imageShots = shots.filter((shot) => shot.imageUrl);
  const coverShot = imageShots.find((shot) => shot.imageSource === "archive") || imageShots[0];
  return {
    version: 1,
    generatedAt: new Date().toISOString(),
    generatedDate: reportDateLabel(),
    project: {
      name: currentLocalProject.name,
      duration: Number(localVideo.duration) || Number(currentLocalProject.duration) || 0,
      mode: manualAnalysis.mode || "manual",
    },
    shots,
    noteCount,
    frameCount: imageShots.length,
    archiveFrameCount: archivedFrames.length,
    representativeFrameCount: imageShots.filter((shot) => shot.imageSource === "representative").length,
    coverImageUrl: coverShot?.imageUrl || "",
    coverImageSource: coverShot?.imageSource || "",
  };
}

function updateReportProjectSummary(report) {
  const hasReport = Boolean(report?.project);
  exportReportButton.disabled = !hasReport;
  exportExcelButton.disabled = !hasReport;
  exportFramesButton.disabled = !hasReport || (report.archiveFrameCount || 0) === 0;
  openFullReportButton.disabled = !hasReport;
  reportSelectedMark.textContent = hasReport ? "已选择" : "待导入";
  if (!hasReport) {
    reportFilmImage.hidden = true;
    reportFilmPlaceholder.hidden = false;
    reportFilmName.textContent = "尚未导入影片";
    reportFilmMeta.textContent = "导入影片并完成拉片后即可生成真实报告";
    sceneCount.textContent = "共 0 镜";
    reportShotRange.textContent = "每页展示 4 镜，自动代表静帧会进入 PDF 和 Excel";
    exportPageCount.textContent = "0 页";
    previewPageLabel.textContent = "等待当前影片";
    return;
  }

  const duration = formatTimecode(report.project.duration).slice(0, 8);
  reportFilmName.textContent = `《${report.project.name}》`;
  reportFilmMeta.textContent = `本地影片 · ${duration} · ${report.shots.length} 镜`;
  sceneCount.textContent = `共 ${report.shots.length} 镜`;
  reportShotRange.textContent = report.shots.length
    ? `镜 001—${String(report.shots.length).padStart(3, "0")} · 每页 4 镜`
    : "当前影片还没有镜头资料";
  if (report.coverImageUrl) {
    reportFilmImage.src = report.coverImageUrl;
    reportFilmImage.alt = `《${report.project.name}》代表静帧`;
    reportFilmImage.hidden = false;
    reportFilmPlaceholder.hidden = true;
  } else {
    reportFilmImage.hidden = true;
    reportFilmPlaceholder.hidden = false;
  }
}

function encodeReportData(report) {
  const bytes = new TextEncoder().encode(JSON.stringify(report));
  let binary = "";
  for (let index = 0; index < bytes.length; index += 8192) {
    binary += String.fromCharCode(...bytes.subarray(index, index + 8192));
  }
  return btoa(binary)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/g, "");
}

function reportUrlFor({ embed = false, print = false, previewKey = "" } = {}) {
  if (!latestReportData) return null;
  const reportUrl = new URL("../report/index.html", window.location.href);
  if (embed) reportUrl.searchParams.set("embed", "1");
  if (print) reportUrl.searchParams.set("print", "1");
  if (previewKey) reportUrl.searchParams.set("preview", previewKey);
  reportUrl.searchParams.set("pages", selectedReportPages().join(","));
  reportUrl.searchParams.set("fields", selectedReportFields().join(","));
  reportUrl.hash = `data=${encodeReportData(latestReportData)}`;
  return reportUrl;
}

function refreshReportWorkspace() {
  latestReportData = buildCurrentReportData();
  updateReportProjectSummary(latestReportData);
  currentPreviewPage = 0;
  syncReportPreview();
}

function selectedReportFields() {
  return reportFieldInputs
    .filter((input) => input.checked)
    .map((input) => input.dataset.reportField);
}

function openReportWindow(shouldPrint = false) {
  refreshReportWorkspace();
  if (!latestReportData) {
    showToast("请先导入影片并完成拉片");
    return;
  }
  const reportUrl = reportUrlFor({ print: shouldPrint });
  const reportWindow = window.open(reportUrl, "_blank");
  if (reportWindow) openedReportWindows.add(reportWindow);
  showToast(shouldPrint ? "真实报告已生成，可打印或保存为 PDF" : "已打开真实拉片报告");
}

async function exportExcelWorkbook() {
  refreshReportWorkspace();
  if (!latestReportData) {
    showToast("请先导入影片并完成拉片");
    return;
  }
  if (!window.cinemaDesktop?.exportExcel) {
    showToast("请在安装版软件中导出 Excel");
    return;
  }

  const originalText = exportExcelButton.textContent;
  exportExcelButton.disabled = true;
  exportExcelButton.textContent = "正在生成 Excel…";
  try {
    const result = await window.cinemaDesktop.exportExcel(latestReportData);
    if (result?.error) {
      showToast(result.error);
      return;
    }
    if (!result?.cancelled) {
      showToast(`Excel 已保存：${result.fileName || "专业图文拉片表.xlsx"}`);
    }
  } finally {
    exportExcelButton.textContent = originalText;
    exportExcelButton.disabled = !latestReportData;
  }
}

async function exportDirectorFramePackage() {
  refreshReportWorkspace();
  if (!currentLocalProject) {
    showToast("请先导入影片");
    return;
  }
  const frames = archiveFrames.filter(
    (record) => record.sourceFilePath === currentLocalProject.filePath
  );
  if (!frames.length) {
    showToast("当前影片还没有收藏静帧");
    return;
  }
  if (!window.cinemaDesktop?.exportFramePackage) {
    showToast("请在安装版软件中导出静帧资料包");
    return;
  }

  const originalText = exportFramesButton.textContent;
  exportFramesButton.disabled = true;
  exportFramesButton.textContent = "正在整理静帧资料包…";
  try {
    const result = await window.cinemaDesktop.exportFramePackage({
      project: {
        name: currentLocalProject.name,
        filePath: currentLocalProject.filePath,
      },
      frames,
    });
    if (result?.error) {
      showToast(result.error);
      return;
    }
    if (!result?.cancelled) {
      showToast(`静帧资料包已保存，共 ${result?.frameCount || frames.length} 张`);
    }
  } finally {
    exportFramesButton.textContent = originalText;
    exportFramesButton.disabled = !latestReportData || (latestReportData.archiveFrameCount || 0) === 0;
  }
}

function syncReportPreview() {
  const selectedGroups = selectedReportPages();
  if (!selectedGroups.length) {
    reportPageInputs.find((input) => input.dataset.reportPage === "cover").checked = true;
    return syncReportPreview();
  }

  if (!latestReportData) {
    exportPageCount.textContent = "0 页";
    previewPageLabel.textContent = "等待当前影片";
    previewPrev.disabled = true;
    previewNext.disabled = true;
    return;
  }
  const allPages = [
    { key: "cover", group: "cover", name: "封面" },
    { key: "overview", group: "overview", name: "分析总览" },
    ...Array.from(
      { length: Math.ceil(latestReportData.shots.length / 4) },
      (_, index) => ({
        key: `shots-${index + 1}`,
        group: "shots",
        name: `逐镜表 ${index + 1}`,
      })
    ),
  ];
  const visiblePages = allPages.filter((page) => (
    selectedGroups.includes(page.key) || selectedGroups.includes(page.group)
  ));
  exportPageCount.textContent = `${visiblePages.length} 页`;
  if (!visiblePages.length) {
    previewPageLabel.textContent = "当前选择没有可显示页面";
    previewPrev.disabled = true;
    previewNext.disabled = true;
    return;
  }

  currentPreviewPage = Math.min(currentPreviewPage, visiblePages.length - 1);
  previewPrev.disabled = currentPreviewPage === 0;
  previewNext.disabled = currentPreviewPage === visiblePages.length - 1;
  const activePage = visiblePages[currentPreviewPage];
  previewPageLabel.textContent = `${activePage.name} · 第 ${currentPreviewPage + 1} / ${visiblePages.length} 页`;
  const reportUrl = reportUrlFor({ embed: true, previewKey: activePage.key });
  if (reportFrame.src !== reportUrl.href) reportFrame.src = reportUrl.href;
}

reportFrame?.addEventListener("load", () => {
  if (!latestReportData) return;
  reportFrame.contentWindow?.postMessage({
    type: "cinema-report-data",
    report: latestReportData,
  }, "*");
});

window.addEventListener("message", (event) => {
  if (event.data?.type !== "cinema-report-ready" || !latestReportData) return;
  const isPreview = event.source === reportFrame?.contentWindow;
  const isOpenedReport = openedReportWindows.has(event.source);
  if (!isPreview && !isOpenedReport) return;
  event.source?.postMessage({
    type: "cinema-report-data",
    report: latestReportData,
  }, "*");
});

reportPageInputs.forEach((input) => input.addEventListener("change", () => {
  currentPreviewPage = 0;
  syncReportPreview();
}));
reportFieldInputs.forEach((input) => input.addEventListener("change", syncReportPreview));
previewPrev?.addEventListener("click", () => {
  currentPreviewPage = Math.max(0, currentPreviewPage - 1);
  syncReportPreview();
});
previewNext?.addEventListener("click", () => {
  currentPreviewPage += 1;
  syncReportPreview();
});
openFullReportButton?.addEventListener("click", () => openReportWindow(false));

const playbackRates = [0.5, 1, 1.5, 2];
const frameDuration = 1 / 25;

function hasPlayableLocalVideo() {
  return Boolean(currentLocalProject && localVideo.readyState >= 1);
}

function clampLocalVideoTimeToProject() {
  if (!currentLocalProject || !Number.isFinite(localVideo.duration) || localVideo.duration <= 0) {
    return;
  }
  const shots = manualShots();
  const selectedShot = shots.find((shot) => shot.key === selectedManualShotKey) || shots[0];
  const fallbackTime = selectedShot && Number.isFinite(selectedShot.start)
    ? selectedShot.start + 0.01
    : 0;
  if (
    !Number.isFinite(localVideo.currentTime)
    || localVideo.currentTime < 0
    || localVideo.currentTime > localVideo.duration
  ) {
    localVideo.currentTime = Math.max(0, Math.min(localVideo.duration, fallbackTime));
  }
  currentTimeLabel.textContent = formatTimecode(localVideo.currentTime);
  updatePlayerProgressDisplay();
}

function scheduleLocalVideoTimeClamp() {
  window.setTimeout(clampLocalVideoTimeToProject, 0);
  window.setTimeout(clampLocalVideoTimeToProject, 250);
  window.setTimeout(clampLocalVideoTimeToProject, 1000);
}

function seekPlayerBy(seconds, label) {
  if (!hasPlayableLocalVideo()) {
    showToast("请先导入并打开影片");
    return;
  }
  activeClipPlaybackEnd = null;
  const duration = Number.isFinite(localVideo.duration) ? localVideo.duration : Infinity;
  localVideo.currentTime = Math.max(0, Math.min(duration, localVideo.currentTime + seconds));
  showToast(`${label} · ${formatTimecode(localVideo.currentTime)}`);
}

function updatePlayerProgressDisplay() {
  const progress = localVideo.duration
    ? Math.max(0, Math.min(100, (localVideo.currentTime / localVideo.duration) * 100))
    : 0;
  if (playerScrubberProgress) playerScrubberProgress.style.width = `${progress}%`;
  if (playerScrubberHandle) playerScrubberHandle.style.left = `${progress}%`;
}

function seekPlayerToRatio(ratio) {
  if (!hasPlayableLocalVideo()) {
    showToast("请先导入并打开影片");
    return;
  }
  const duration = Number.isFinite(localVideo.duration) ? localVideo.duration : 0;
  if (!duration) return;
  activeClipPlaybackEnd = null;
  activeClipPlaybackContinue = false;
  const clamped = Math.max(0, Math.min(1, ratio));
  localVideo.currentTime = clamped * duration;
  currentTimeLabel.textContent = formatTimecode(localVideo.currentTime);
  updatePlayerProgressDisplay();
}

function bindPlayerScrubber() {
  if (!playerScrubber) return;
  let dragging = false;
  const ratioFromEvent = (event) => {
    const bounds = playerScrubber.getBoundingClientRect();
    if (bounds.width <= 0) return 0;
    return (event.clientX - bounds.left) / bounds.width;
  };
  const stopDragging = (event) => {
    if (!dragging) return;
    dragging = false;
    try {
      playerScrubber.releasePointerCapture?.(event.pointerId);
    } catch {
      // 指针已经在进度条外释放时无需重复处理。
    }
  };

  playerScrubber.addEventListener("pointerdown", (event) => {
    dragging = true;
    event.preventDefault();
    try {
      playerScrubber.setPointerCapture?.(event.pointerId);
    } catch {
      // 某些测试环境不提供指针捕获，点击和拖动仍可继续。
    }
    seekPlayerToRatio(ratioFromEvent(event));
  });
  playerScrubber.addEventListener("pointermove", (event) => {
    if (dragging) seekPlayerToRatio(ratioFromEvent(event));
  });
  playerScrubber.addEventListener("pointerup", stopDragging);
  playerScrubber.addEventListener("pointercancel", stopDragging);
}

function applyTimelineZoom() {
  timelineZoom = Math.max(0.7, Math.min(1.8, timelineZoom));
  shotStrip?.style.setProperty("--timeline-zoom", String(timelineZoom));
  if (timelineZoomLabel) timelineZoomLabel.textContent = `${Math.round(timelineZoom * 100)}%`;
}

function changeTimelineZoom(delta) {
  timelineZoom = Math.round((timelineZoom + delta) * 10) / 10;
  applyTimelineZoom();
  showToast(`时间线缩放 ${Math.round(timelineZoom * 100)}%`);
}

async function togglePlayerFullscreen() {
  setPlayerFullscreen(!isPlayerFullscreen);
  showToast(isPlayerFullscreen ? "已进入全屏播放，按 Esc 退出" : "已退出全屏播放");
}

function clearPlayerChromeHideTimer() {
  if (playerChromeHideTimer) {
    clearTimeout(playerChromeHideTimer);
    playerChromeHideTimer = null;
  }
}

function setPlayerChromeHidden(hidden) {
  const target = document.querySelector(".player-card");
  target?.classList.toggle("is-player-chrome-hidden", Boolean(hidden));
}

function schedulePlayerChromeHide() {
  clearPlayerChromeHideTimer();
  if (!isPlayerFullscreen || localVideo.paused) {
    setPlayerChromeHidden(false);
    return;
  }
  playerChromeHideTimer = setTimeout(() => {
    if (isPlayerFullscreen && !localVideo.paused) {
      setPlayerChromeHidden(true);
    }
  }, 1800);
}

function showPlayerChromeTemporarily() {
  if (!isPlayerFullscreen) return;
  setPlayerChromeHidden(false);
  schedulePlayerChromeHide();
}

function setPlayerFullscreen(active) {
  const target = document.querySelector(".player-card");
  if (!target) return;
  isPlayerFullscreen = Boolean(active);
  target.classList.toggle("is-player-fullscreen", isPlayerFullscreen);
  document.body.classList.toggle("player-fullscreen-active", isPlayerFullscreen);
  clearPlayerChromeHideTimer();
  setPlayerChromeHidden(false);
  if (playerFullscreenButton) {
    playerFullscreenButton.textContent = isPlayerFullscreen ? "×" : "⛶";
    playerFullscreenButton.setAttribute("aria-label", isPlayerFullscreen ? "退出全屏播放" : "全屏播放");
    playerFullscreenButton.setAttribute("title", isPlayerFullscreen ? "退出全屏播放（Esc）" : "全屏播放");
  }
  if (isPlayerFullscreen) schedulePlayerChromeHide();
}

function stepPlayerFrame(direction) {
  if (!hasPlayableLocalVideo()) {
    showToast("请先导入并打开影片");
    return;
  }
  localVideo.pause();
  activeClipPlaybackEnd = null;
  const duration = Number.isFinite(localVideo.duration) ? localVideo.duration : Infinity;
  localVideo.currentTime = Math.max(
    0,
    Math.min(duration, localVideo.currentTime + direction * frameDuration)
  );
}

function cyclePlaybackRate() {
  if (!hasPlayableLocalVideo()) {
    showToast("请先导入并打开影片");
    return;
  }
  const currentIndex = playbackRates.findIndex(
    (rate) => Math.abs(rate - localVideo.playbackRate) < 0.01
  );
  const nextRate = playbackRates[(currentIndex + 1) % playbackRates.length];
  localVideo.playbackRate = nextRate;
  playerSpeedButton.textContent = `${nextRate}×`;
  showToast(`播放速度 ${nextRate}×`);
}

function handleActiveClipPlaybackBoundary(currentTime) {
  if (!Number.isFinite(activeClipPlaybackEnd) || currentTime < activeClipPlaybackEnd) {
    return "none";
  }
  const clipEnd = activeClipPlaybackEnd;
  const shouldContinue = activeClipPlaybackContinue;
  activeClipPlaybackEnd = null;
  activeClipPlaybackContinue = false;
  if (shouldContinue) {
    showToast("已到收藏出点，继续播放原片");
    return "continue";
  }
  localVideo.pause();
  localVideo.currentTime = clipEnd;
  showToast("收藏片段播放完成");
  return "stop";
}

async function togglePlayerPlayback() {
  if (currentLocalProject) {
    if (localVideo.paused) {
      await localVideo.play();
    } else {
      localVideo.pause();
    }
    return;
  }
  document.querySelectorAll(".center-play, .main-play").forEach((button) => {
    button.textContent = button.textContent === "▶" ? "Ⅱ" : "▶";
  });
  const isPlaying = document.querySelector(".main-play").textContent === "Ⅱ";
  showToast(isPlaying ? "预览中：影片播放" : "预览中：影片暂停");
}

document.querySelectorAll(".center-play, .main-play").forEach((button) => {
  button.addEventListener("click", togglePlayerPlayback);
});

playerSkipBack?.addEventListener("click", () => seekPlayerBy(-5, "已后退 5 秒"));
playerFrameBack?.addEventListener("click", () => stepPlayerFrame(-1));
playerFrameForward?.addEventListener("click", () => stepPlayerFrame(1));
playerSkipForward?.addEventListener("click", () => seekPlayerBy(5, "已前进 5 秒"));
playerSpeedButton?.addEventListener("click", cyclePlaybackRate);
playerFullscreenButton?.addEventListener("click", togglePlayerFullscreen);
timelineZoomOutButton?.addEventListener("click", () => changeTimelineZoom(-0.1));
timelineZoomInButton?.addEventListener("click", () => changeTimelineZoom(0.1));
setRepresentativeFrameButton?.addEventListener("click", setCurrentFrameAsRepresentative);
bindPlayerScrubber();
applyTimelineZoom();
document.querySelector(".player-card")?.addEventListener("pointermove", showPlayerChromeTemporarily);
document.querySelector(".player-card")?.addEventListener("pointerdown", showPlayerChromeTemporarily);
document.addEventListener("click", () => closeProjectCardMenus());

document.addEventListener("keydown", async (event) => {
  const target = event.target;
  const isEditing = target instanceof HTMLElement && (
    target.isContentEditable
    || ["INPUT", "TEXTAREA", "SELECT"].includes(target.tagName)
  );
  if (event.key === "Escape" && isPlayerFullscreen) {
    event.preventDefault();
    setPlayerFullscreen(false);
    return;
  }
  if (
    isEditing
    || event.metaKey
    || event.ctrlKey
    || event.altKey
    || !document.querySelector("#workbench-page")?.classList.contains("active")
  ) {
    return;
  }

  if (event.code === "Space") {
    event.preventDefault();
    await togglePlayerPlayback();
  } else if (event.key === "ArrowLeft") {
    event.preventDefault();
    seekPlayerBy(-5, "已后退 5 秒");
  } else if (event.key === "ArrowRight") {
    event.preventDefault();
    seekPlayerBy(5, "已前进 5 秒");
  } else if (event.key === ",") {
    event.preventDefault();
    stepPlayerFrame(-1);
  } else if (event.key === ".") {
    event.preventDefault();
    stepPlayerFrame(1);
  }
});

localVideo.addEventListener("play", () => {
  document.querySelectorAll(".center-play, .main-play").forEach((button) => {
    button.textContent = "Ⅱ";
  });
  schedulePlayerChromeHide();
});

localVideo.addEventListener("pause", () => {
  document.querySelectorAll(".center-play, .main-play").forEach((button) => {
    button.textContent = "▶";
  });
  clearPlayerChromeHideTimer();
  setPlayerChromeHidden(false);
});

localVideo.addEventListener("ratechange", () => {
  if (playerSpeedButton) playerSpeedButton.textContent = `${localVideo.playbackRate}×`;
});

localVideo.addEventListener("error", () => {
  if (!currentLocalProject || isLocalAnalyzing) return;
  if (lastVideoErrorFilePath === currentLocalProject.filePath) return;
  lastVideoErrorFilePath = currentLocalProject.filePath;
  setSidebarSaveStatus("error", "原片没有读到，请重新导入");
  const continueNote = document.querySelector(".continue-copy .film-note");
  if (continueNote) {
    continueNote.textContent = "原影片可能已经移动，或当前打开的是安装镜像里的软件。请从“电影资源”重新导入这部影片。";
  }
  showToast("原影片没有读到画面，请退出镜像版后从“电影资源”重新导入");
});

localVideo.addEventListener("timeupdate", () => {
  clampLocalVideoTimeToProject();
  currentTimeLabel.textContent = formatTimecode(localVideo.currentTime);
  updatePlayerProgressDisplay();
  handleActiveClipPlaybackBoundary(localVideo.currentTime);
});

localVideo.addEventListener("loadedmetadata", async () => {
  totalTimeLabel.textContent = formatTimecode(localVideo.duration);
  if (window.cinemaDesktop && currentLocalProject) {
    currentLocalProject = await window.cinemaDesktop.updateProject({
      duration: localVideo.duration,
    });
  }
  initializeManualAnalysis(localVideo.duration);
  const shots = manualShots();
  const selectedShot = shots.find((shot) => shot.key === selectedManualShotKey) || shots[0];
  if (selectedShot) {
    selectedManualShotKey = selectedShot.key;
    updateShotEditor(selectedShot);
    resetCustomClipRange(selectedShot);
    renderManualShots();
    if (!isLocalAnalyzing && analysisChoice.hidden) scheduleManualSave();
    if (!isLocalAnalyzing && analysisChoice.hidden) ensureRepresentativeFrames();
  }
  scheduleLocalVideoTimeClamp();
  if (
    pendingArchiveTarget
    && currentLocalProject?.filePath === pendingArchiveTarget.sourceFilePath
  ) {
    const target = pendingArchiveTarget;
    pendingArchiveTarget = null;
    if (target.type === "clip") {
      await playArchiveClip(target);
    } else {
      seekToArchiveRecord(target);
    }
  }
});

if (window.cinemaDesktop) {
  refreshCloudSubtitleStatus();
  refreshAITranslationStatus();
  window.cinemaDesktop.getRecentProject().then((project) => {
    if (project) applyLocalProject(project, false);
    refreshProjectLibrary();
  });
} else {
  renderLibraryProjects();
}

loadInspirationCollections();
renderLightAccountProfile();
initializeOpeningExperience();
