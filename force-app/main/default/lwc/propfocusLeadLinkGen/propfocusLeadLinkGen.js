import { LightningElement, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { CurrentPageReference } from "lightning/navigation";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import LEAD_STATUS_SCHEMA from "@salesforce/schema/Lead.Status";
import OPP_STAGE_SCHEMA from "@salesforce/schema/Opportunity.StageName";
import {
  normalizeStatusToken,
  parseStatusSet,
  pickAutoModalAction as resolveAutoModalAction,
  isAutoCreateReady as resolveAutoCreateReady
} from "./autoModalRules";

import getLeadDetails from "@salesforce/apex/PropFocusLeadService.getLeadDetails";
import getProjects from "@salesforce/apex/PropFocusLeadService.getProjects";
import getProjectsForSiteVisit from "@salesforce/apex/PropFocusLeadService.getProjectsForSiteVisit";
import generatePropfocusTemplate from "@salesforce/apex/PropFocusLeadService.generatePropfocusTemplate";
import getConfigurationsForProjects from "@salesforce/apex/PropFocusLeadService.getConfigurationsForProjects";
import getLatestSiteVisitDateTime from "@salesforce/apex/PropFocusLeadService.getLatestSiteVisitDateTime";
import getSiteVisitManagers from "@salesforce/apex/PropFocusLeadService.getSiteVisitManagers";
import getSalesTeam from "@salesforce/apex/PropFocusLeadService.getSalesTeam";
import getLinkHistory from "@salesforce/apex/PropFocusLeadService.getLinkHistory";
import getBuyerInsightsEmbedContext from "@salesforce/apex/PropFocusLeadService.getBuyerInsightsEmbedContext";
import getUiConfiguration from "@salesforce/apex/PropfocusConfigService.getUiConfiguration";

const LEAD_PROFOCUS_LINK_FIELD = "Propfocus_Link__c";
const LEAD_SITE_VISIT_FIELD = "Propfocus_Site_Visit__c";
const LEAD_POST_VISIT_FIELD = "Propfocus_Post_Visit__c";
const LEAD_BUYER_ID_FIELD = "buyerId";
const LEAD_BUYER_NAME_FIELD = "buyerName";
const LEAD_PROJECT_FIELD = "projectName";
const LEAD_STATUS_FIELD = "leadStatus";

const COMM_TYPE_MICROSITE = "microsite";
const COMM_TYPE_SITE_VISIT = "site_visit";
const COMM_TYPE_POST_VISIT = "post_visit";

const CUSTOMER_SUPPORT_MESSAGE =
  "Something went wrong. Please contact the Propfocus support team.";

const MICROSITE_LEAD_TYPE_OPTIONS = [
  { label: "New", value: "new" },
  { label: "RNR", value: "rnr" },
  { label: "Refer", value: "refer" },
  { label: "Old Data", value: "old data" },
  { label: "Investor", value: "investor" }
];
const ALL_CONFIG_OPTION_VALUE = "__ALL_CONFIGS__";
const ALL_CONFIG_API_VALUE = "all";
const FULL_NAME_REGEX = /^[A-Za-z\s.]+$/;

function validateFullName(name) {
  const trimmed = (name || "").trim();
  if (!trimmed) {
    return { valid: false, message: "Full Name cannot be empty" };
  }
  if (!FULL_NAME_REGEX.test(trimmed)) {
    return {
      valid: false,
      message: "Full Name should contain only letters, spaces, and periods"
    };
  }
  return { valid: true, value: trimmed };
}

function buildMicrositeWhatsAppMessage(clientName, projectNames, micrositeUrl) {
  if (!micrositeUrl) return "";
  const name = (clientName || "").trim() || "there";
  const projects = Array.isArray(projectNames) ? projectNames : [];
  const projectList = projects
    .map((projectName, index) => `${index + 1}. ${projectName}`)
    .join("\n");
  let message = `Hi ${name},

As discussed, here's the link with all the details of the projects:

${projectList} 

Check here 👉 ${micrositeUrl}

If you'd like assistance in comparing options or scheduling a site visit, just let me know. I'll be happy to help.

Note: If the link isn't clickable, simply reply with any message (e.g. ok) and it will be activated.`;
  return message;
}

function buildSiteVisitWhatsAppMessage(clientName, projectName, siteVisitUrl) {
  if (!siteVisitUrl) return "";
  const greetingName = (clientName || "").trim() || "there";
  const project = (projectName || "").trim() || "your project";
  return `Hi ${greetingName},

Your *site visit for ${project}* is scheduled.

Please confirm your visit here: ${siteVisitUrl}

You can also find the *location and visit details* in the link.

Looking forward to meeting you.`;
}

function buildPostVisitWhatsAppMessage(
  clientName,
  projectName,
  visitedConfiguration,
  postVisitUrl
) {
  if (!postVisitUrl) return "";
  const greetingName = (clientName || "").trim() || "there";
  const project = (projectName || "").trim() || "your project";
  const config = (visitedConfiguration || "").trim() || "the unit";
  return `✅ Post-visit page ready for ${greetingName}

${config} · ${project}

Share with your buyer:
${postVisitUrl}`;
}

function copyWithTextarea(text) {
  try {
    const ta = document.createElement("textarea");
    ta.value = text;
    ta.setAttribute("readonly", "");
    ta.style.cssText = "position:fixed;top:0;left:0;width:2em;height:2em;padding:0;border:none;outline:none;boxShadow:none;background:transparent";
    document.body.appendChild(ta);
    ta.focus();
    ta.select();
    ta.setSelectionRange(0, text.length);
    const ok = document.execCommand("copy");
    document.body.removeChild(ta);
    return ok;
  } catch {
    return false;
  }
}

function beginDeferredClipboardCopy() {
  let resolveCopyText;
  const copyTextDeferred = new Promise((resolve) => {
    resolveCopyText = resolve;
  });

  if (navigator.clipboard?.write && typeof ClipboardItem !== "undefined") {
    try {
      void navigator.clipboard.write([
        new ClipboardItem({
          "text/plain": copyTextDeferred.then(
            (text) => new Blob([String(text || "")], { type: "text/plain" })
          )
        })
      ]);
    } catch {
      // Clipboard API may be unavailable in this browser context.
    }
  }

  return (text) => resolveCopyText(String(text || ""));
}

function resolveHistoryStatus(type, rawStatus) {
  const status = normalizeStatusToken(rawStatus);
  const historyType = String(type || "").trim().toLowerCase();

  const engaged = {
    label: "Engaged",
    statusClass: "pf-status pf-status-engaged"
  };
  const notEngaged = {
    label: "Not engaged",
    statusClass: "pf-status pf-status-not-engaged"
  };
  const pending = {
    label: "Pending",
    statusClass: "pf-status pf-status-pending"
  };
  const confirmed = {
    label: "Confirmed",
    statusClass: "pf-status pf-status-confirmed"
  };
  const rescheduled = {
    label: "Rescheduled",
    statusClass: "pf-status pf-status-rescheduled"
  };

  if (historyType.includes("site visit")) {
    if (
      status === "confirmed" ||
      status === "completed" ||
      status === "conducted" ||
      status === "done" ||
      status === "visited"
    ) {
      return confirmed;
    }
    if (status === "rescheduled" || status === "reschedule") {
      return rescheduled;
    }
    if (
      status === "pending" ||
      status === "scheduled" ||
      status === "open" ||
      status === "generated"
    ) {
      return pending;
    }
    return pending;
  }

  if (status === "engaged") {
    return engaged;
  }
  if (
    status === "not engaged" ||
    status === "generated" ||
    status === "unengaged"
  ) {
    return notEngaged;
  }
  return notEngaged;
}

function resolveDefaultMicrositeLeadType(leadStatus) {
  const normalized = (leadStatus || "").trim().toLowerCase();
  if (normalized === "open") return "rnr";
  if (normalized === "new") return "new";
  return "new";
}

function formatDateTimeLocalInput(value) {
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) {
    return "";
  }
  const pad2 = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}T${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}

function startOfLocalDay(value) {
  const d = new Date(value);
  d.setHours(0, 0, 0, 0);
  return d;
}

function normalizeSiteVisitDateTime(value) {
  const chosen = value instanceof Date ? new Date(value) : new Date(value);
  if (Number.isNaN(chosen.getTime())) {
    const tomorrow = startOfLocalDay(new Date());
    tomorrow.setDate(tomorrow.getDate() + 1);
    return formatDateTimeLocalInput(tomorrow);
  }
  const today = startOfLocalDay(new Date());
  if (startOfLocalDay(chosen) < today) {
    const tomorrow = startOfLocalDay(new Date());
    tomorrow.setDate(tomorrow.getDate() + 1);
    tomorrow.setHours(chosen.getHours(), chosen.getMinutes(), 0, 0);
    return formatDateTimeLocalInput(tomorrow);
  }
  return formatDateTimeLocalInput(chosen);
}

function getPropfocusLinkFromLead(lead) {
  if (!lead) return "";
  const v = lead[LEAD_PROFOCUS_LINK_FIELD];
  return v != null && String(v).trim() ? String(v).trim() : "";
}

function leadFieldHasValue(lead, field) {
  if (!lead) return false;
  const v = lead[field];
  return v != null && String(v).trim() !== "";
}

export default class PropfocusLeadLinkGen extends LightningElement {
  recordId;
  isLoading = false;
  isModalOpen = false;
  iframeBust = 0;
  storedPropfocusLink = "";
  enquiryRefNo = "";
  logoUrl = "";
  buyerInsightsEmbedBase = "";
  buyerInsightsEmbedUrl = "";
  embedUsesSalesforceLeadId = false;
  clientName;
  selectedProjects = [];
  modalAction = "microsite";
  siteVisitDateTime = "";
  siteVisitProject = "";
  siteVisitManager = "";
  siteVisitManagerOptions = [];
  isLoadingSiteVisitManagers = false;
  postVisitProject = "";
  postVisitSelectedConfigurations = [];
  postVisitConfigurationOptions = [];
  isLoadingPostVisitConfigurations = false;
  postVisitReassignTo = "";
  salesTeamOptions = [];
  isLoadingSalesTeam = false;
  micrositeLeadType = "new";
  selectedConfigurations = [];
  configurationOptions = [];
  isLoadingConfigurations = false;
  projectOptions;
  hasMicrosite = false;
  hasSiteVisit = false;
  hasPostVisit = false;
  hasValidBuyerInsights = false;
  previewExpanded = false;
  linkHistory = [];
  selectedLinkKey = "";
  historyExpanded = false;
  lastReloadAt = null;
  showCopySuccess = false;
  successCopyText = "";
  copyButtonLabel = "Copy message";
  pendingAutoCopy = false;
  showCopyModalEnabled = false;
  showSiteVisitButtonEnabled = true;
  showPostVisitButtonEnabled = true;
  autoMicrositeStatuses = new Set();
  autoSiteVisitStatuses = new Set();
  autoPostVisitStatuses = new Set();
  autoModalsConfigLoaded = false;
  autoStatusRecordId = null;
  lastKnownLeadStatus;
  autoPromptedKeys = new Set();

  @wire(CurrentPageReference)
  setPageRef(pageRef) {
    if (pageRef?.attributes?.recordId) {
      const changedRecord = this.recordId !== pageRef.attributes.recordId;
      this.recordId = pageRef.attributes.recordId;
      this.iframeBust = Date.now();
      this.historyExpanded = false;
      if (changedRecord) {
        // New record: forget prior auto-open baselines so it can prompt afresh.
        this.autoPromptedKeys = new Set();
        this.lastKnownLeadStatus = undefined;
        this.autoStatusRecordId = null;
      }
      Promise.allSettled([
        this.refreshMicrositeState(),
        this.loadLinkHistory(),
        this.loadBuyerInsightsEmbedContext()
      ]).finally(() => this.markDataReloaded());
    } else {
      this.recordId = undefined;
      this.storedPropfocusLink = "";
      this.enquiryRefNo = "";
      this.hasMicrosite = false;
      this.hasSiteVisit = false;
      this.hasPostVisit = false;
      this.hasValidBuyerInsights = false;
      this.linkHistory = [];
      this.selectedLinkKey = "";
      this.historyExpanded = false;
      this.lastReloadAt = null;
      this.buyerInsightsEmbedUrl = "";
    }
  }

  // The status field to watch depends on the object this panel is on:
  // Lead.Status on a Lead, Opportunity.StageName on an Opportunity (key
  // prefix 006). Returned as a reactive field list for the getRecord wire.
  get autoStatusFields() {
    if (!this.recordId) {
      return [];
    }
    return String(this.recordId).startsWith("006")
      ? [OPP_STAGE_SCHEMA]
      : [LEAD_STATUS_SCHEMA];
  }

  // Reactively observe the record's status (Lead.Status or Opportunity
  // .StageName) so that both opening a matching record and changing its status
  // into a matching value can auto-open the relevant modal. Works on both Lead
  // and Opportunity record pages.
  @wire(getRecord, { recordId: "$recordId", fields: "$autoStatusFields" })
  wiredRecordStatus({ data }) {
    if (!data) {
      return;
    }
    const statusField =
      data.apiName === "Opportunity" ? OPP_STAGE_SCHEMA : LEAD_STATUS_SCHEMA;
    this.autoStatusRecordId = data.id;
    this.lastKnownLeadStatus = normalizeStatusToken(
      getFieldValue(data, statusField)
    );
    this.evaluateAutoModals();
  }

  // Picks which modal (if any) should auto-open for the current status, in
  // precedence order microsite -> site visit -> post visit. A modal is a
  // candidate only when the status is in its admin-configured list, its feature
  // is enabled, and its link does not exist yet.
  pickAutoModalAction(status) {
    return resolveAutoModalAction(status, {
      micrositeStatuses: this.autoMicrositeStatuses,
      siteVisitStatuses: this.autoSiteVisitStatuses,
      postVisitStatuses: this.autoPostVisitStatuses,
      hasMicrosite: this.hasMicrosite,
      hasSiteVisit: this.hasSiteVisit,
      hasPostVisit: this.hasPostVisit,
      siteVisitEnabled: this.showSiteVisitButtonEnabled,
      postVisitEnabled: this.showPostVisitButtonEnabled
    });
  }

  // Auto-opens the microsite / site visit / post visit modal whenever the
  // current Lead status matches its admin-configured statuses and its link does
  // not exist yet. Runs on load and on every status change; the prompt key set
  // stops it from re-popping for the same record+action+status after the rep
  // dismisses it (or on LDS cache refreshes).
  evaluateAutoModals() {
    if (!this.autoModalsConfigLoaded) {
      return;
    }
    const recordId = this.autoStatusRecordId;
    const status = this.lastKnownLeadStatus;
    if (!recordId || !status) {
      return;
    }
    if (this.isModalOpen || this.isLoading) {
      return;
    }
    const action = this.pickAutoModalAction(status);
    if (!action) {
      return;
    }
    const promptKey = `${recordId}::${action}::${status}`;
    if (this.autoPromptedKeys.has(promptKey)) {
      return;
    }
    // Mark as prompted before the async open so LDS refreshes can't double-fire.
    this.autoPromptedKeys.add(promptKey);
    if (action === "microsite") {
      this.openMicrositeModal({ skipIfExists: true, autoCreate: true });
    } else if (action === "siteVisit") {
      this.openSiteVisitModal({ skipIfExists: true, autoCreate: true });
    } else if (action === "postVisit") {
      this.openPostVisitModal({ skipIfExists: true, autoCreate: true });
    }
  }

  // For the auto-open path: true when every mandatory field for the action is
  // already populated and valid, so the link can be created without showing the
  // modal. Mirrors each submit's own required-field validation.
  isAutoCreateReady(action) {
    return resolveAutoCreateReady(action, {
      nameValid: validateFullName(this.clientName).valid,
      projectCount: this.selectedProjects?.length || 0,
      siteVisitProject: this.siteVisitProject,
      siteVisitDateTime: this.siteVisitDateTime,
      postVisitProject: this.postVisitProject,
      postVisitConfigCount: this.postVisitSelectedConfigurations?.length || 0
    });
  }

  markDataReloaded() {
    this.lastReloadAt = new Date();
  }

  connectedCallback() {
    this.loadUiConfig();
    this.loadProjects();
  }

  loadUiConfig() {
    getUiConfiguration()
      .then((cfg) => {
        this.logoUrl = cfg?.logoUrl || "";
        this.buyerInsightsEmbedBase = cfg?.embedBaseUrl || "";
        this.embedUsesSalesforceLeadId =
          cfg?.embedUsesSalesforceLeadId === true;
        this.showCopyModalEnabled = cfg?.showCopyModal === true;
        this.showSiteVisitButtonEnabled = cfg?.showSiteVisitButton === true;
        this.showPostVisitButtonEnabled = cfg?.showPostVisitButton === true;
        this.autoMicrositeStatuses = parseStatusSet(cfg?.autoMicrositeStatuses);
        this.autoSiteVisitStatuses = parseStatusSet(cfg?.autoSiteVisitStatuses);
        this.autoPostVisitStatuses = parseStatusSet(cfg?.autoPostVisitStatuses);
        this.autoModalsConfigLoaded = true;
        // Re-check in case the status wire resolved before config loaded.
        this.evaluateAutoModals();
      })
      .catch(() => {
        this.logoUrl = "";
        this.buyerInsightsEmbedBase = "";
        this.embedUsesSalesforceLeadId = false;
        this.showCopyModalEnabled = false;
        this.showSiteVisitButtonEnabled = true;
        this.showPostVisitButtonEnabled = true;
        this.autoMicrositeStatuses = new Set();
        this.autoSiteVisitStatuses = new Set();
        this.autoPostVisitStatuses = new Set();
        this.autoModalsConfigLoaded = true;
      });
  }

  applyLeadLinkFromResponse(lead) {
    this.storedPropfocusLink = getPropfocusLinkFromLead(lead);
    this.enquiryRefNo =
      lead?.[LEAD_BUYER_ID_FIELD] != null &&
      String(lead[LEAD_BUYER_ID_FIELD]).trim()
        ? String(lead[LEAD_BUYER_ID_FIELD]).trim()
        : "";
    this.hasMicrosite = !!this.storedPropfocusLink;
    this.hasSiteVisit = leadFieldHasValue(lead, LEAD_SITE_VISIT_FIELD);
    this.hasPostVisit = leadFieldHasValue(lead, LEAD_POST_VISIT_FIELD);
    this.hasValidBuyerInsights = !!lead?.buyerInsightsAvailable;
  }

  loadBuyerInsightsEmbedContext() {
    if (!this.recordId) {
      this.buyerInsightsEmbedUrl = "";
      return Promise.resolve();
    }
    return getBuyerInsightsEmbedContext({ leadId: this.recordId })
      .then((ctx) => {
        this.embedUsesSalesforceLeadId = ctx?.usesSalesforceLeadId === true;
        this.buyerInsightsEmbedUrl = ctx?.embedUrl || "";
        if (ctx?.buyerInsightsAvailable != null) {
          this.hasValidBuyerInsights = !!ctx.buyerInsightsAvailable;
        }
      })
      .catch(() => {
        this.buyerInsightsEmbedUrl = "";
      });
  }

  refreshMicrositeState() {
    if (!this.recordId) {
      this.storedPropfocusLink = "";
      this.enquiryRefNo = "";
      this.hasMicrosite = false;
      this.hasSiteVisit = false;
      this.hasPostVisit = false;
      this.hasValidBuyerInsights = false;
      return Promise.resolve();
    }
    return getLeadDetails({ leadId: this.recordId })
      .then((lead) => {
        this.applyLeadLinkFromResponse(lead);
        // Existence flags are now authoritative; re-check auto-open candidates.
        this.evaluateAutoModals();
      })
      .catch(() => {
        this.storedPropfocusLink = "";
        this.enquiryRefNo = "";
        this.hasMicrosite = false;
        this.hasSiteVisit = false;
        this.hasPostVisit = false;
        this.hasValidBuyerInsights = false;
      })
      .finally(() => this.loadBuyerInsightsEmbedContext());
  }

  loadProjects() {
    return getProjects()
      .then((result) => {
        const options = result.map((item) => ({
          label: item,
          value: item
        }));
        this.projectOptions = options;
        return this.postVisitConfigurationOptions;
      })
      .catch(() => {
        this.projectOptions = [];
        this.showToast("Error", CUSTOMER_SUPPORT_MESSAGE, "error");
        return [];
      });
  }

  loadSiteVisitProjects() {
    return getProjectsForSiteVisit()
      .then((result) => result.map((item) => ({ label: item, value: item })))
      .catch(() => this.projectOptions || []);
  }

  loadSiteVisitManagers(projectName) {
    const normalizedProject = (projectName || "").trim();
    if (!normalizedProject) {
      this.siteVisitManagerOptions = [];
      this.siteVisitManager = "";
      this.isLoadingSiteVisitManagers = false;
      return Promise.resolve([]);
    }
    this.isLoadingSiteVisitManagers = true;
    return getSiteVisitManagers({ projectName: normalizedProject })
      .then((rows) => {
        const options = (rows || []).map((row) => ({
          id: row.id,
          name: row.name,
          phone: row.phone || "",
          label: row.name,
          value: row.id
        }));
        this.siteVisitManagerOptions = options;
        if (
          this.siteVisitManager &&
          !options.some((option) => option.value === this.siteVisitManager)
        ) {
          this.siteVisitManager = "";
        }
        return options;
      })
      .catch(() => {
        this.siteVisitManagerOptions = [];
        this.siteVisitManager = "";
        return [];
      })
      .finally(() => {
        this.isLoadingSiteVisitManagers = false;
      });
  }

  extractLinkKey(url) {
    if (!url) {
      return "";
    }
    try {
      const parts = new URL(url).pathname.split("/").filter(Boolean);
      return parts.length ? parts[parts.length - 1] : "";
    } catch (e) {
      const parts = String(url).split("?")[0].split("/").filter(Boolean);
      return parts.length ? parts[parts.length - 1] : "";
    }
  }

  loadLinkHistory() {
    if (!this.recordId) {
      this.linkHistory = [];
      this.selectedLinkKey = "";
      return Promise.resolve();
    }
    return getLinkHistory({ leadId: this.recordId })
      .then((rows) => {
        this.linkHistory = (rows || []).map((row) => {
          const url = row.url || "";
          const linkKey = this.extractLinkKey(url);
          return {
            id: row.id,
            type: row.type || "-",
            projectName: row.projectName || "-",
            status: row.status || "-",
            url,
            linkKey,
            createdAt: row.createdAt
              ? new Date(row.createdAt).toLocaleString()
              : "-"
          };
        });
        // Default insights to the latest shared link.
        this.selectedLinkKey = this.linkHistory[0]?.linkKey || "";
        this.bumpIframeCache();
      })
      .catch(() => {
        this.linkHistory = [];
        this.selectedLinkKey = "";
      });
  }

  get showSiteVisitManagerField() {
    return Boolean(this.siteVisitProject) && this.siteVisitManagerOptions.length > 0;
  }

  get primaryMicrositeLabel() {
    return this.hasMicrosite ? "Regenerate Microsite" : "Generate Microsite";
  }

  get showSiteVisitToolbar() {
    return this.showSiteVisitButtonEnabled || this.showPostVisitButtonEnabled;
  }

  get siteVisitToolbarRowClass() {
    const bothVisible =
      this.showSiteVisitButtonEnabled && this.showPostVisitButtonEnabled;
    return bothVisible
      ? "pf-toolbar-row pf-toolbar-row-split"
      : "pf-toolbar-row";
  }

  get siteVisitButtonClass() {
    return this.showPostVisitButtonEnabled
      ? "pf-btn pf-btn-secondary"
      : "pf-btn pf-btn-secondary pf-btn-full";
  }

  get postVisitButtonClass() {
    return this.showSiteVisitButtonEnabled
      ? "pf-btn pf-btn-secondary"
      : "pf-btn pf-btn-secondary pf-btn-full";
  }

  get iframeSrc() {
    if (!this.buyerInsightsEmbedUrl) return "";
    const params = new URLSearchParams();
    if (this.selectedLinkKey) {
      params.set("linkUrl", this.selectedLinkKey);
    }
    params.set("_pf", String(this.iframeBust || Date.now()));
    const separator = this.buyerInsightsEmbedUrl.includes("?") ? "&" : "?";
    return `${this.buyerInsightsEmbedUrl}${separator}${params.toString()}`;
  }

  get embedFrameClass() {
    return this.previewExpanded
      ? "pf-embed-frame pf-embed-frame_expanded"
      : "pf-embed-frame pf-embed-frame_collapsed";
  }
  get embedIframeClass() {
    return this.previewExpanded
      ? "pf-embed pf-embed_expanded"
      : "pf-embed pf-embed_collapsed";
  }
  get previewToggleLabel() {
    return this.previewExpanded ? "Collapse preview" : "Expand preview";
  }
  get previewToggleIconName() {
    return this.previewExpanded ? "utility:chevronup" : "utility:chevrondown";
  }
  get modalTitle() {
    if (this.showCopySuccess) return "Copy WhatsApp message";
    if (this.modalAction === "siteVisit") return "Confirm site visit";
    if (this.modalAction === "postVisit") return "Generate post visit page";
    return this.hasMicrosite
      ? "Regenerate Propfocus microsite"
      : "Generate Propfocus microsite";
  }
  get modalSubmitLabel() {
    if (this.modalAction === "siteVisit") return "Confirm";
    if (this.modalAction === "postVisit") return "Generate";
    return this.hasMicrosite ? "Regenerate" : "Generate";
  }
  get showSiteVisitFields() {
    return this.modalAction === "siteVisit";
  }
  get showPostVisitFields() {
    return this.modalAction === "postVisit";
  }
  get showPostVisitConfigurationField() {
    return Boolean(this.postVisitProject);
  }

  get postVisitReassignPlaceholder() {
    return this.salesTeamOptions.length > 0
      ? "Select sales person"
      : "No sales team members available";
  }
  get showMicrositeFields() {
    return this.modalAction === "microsite";
  }
  get micrositeLeadTypeOptions() {
    return MICROSITE_LEAD_TYPE_OPTIONS;
  }
  get hasHistory() {
    return this.linkHistory.length > 0;
  }

  get lastReloadDisplay() {
    if (!this.lastReloadAt) {
      return "";
    }
    return this.lastReloadAt.toLocaleString();
  }

  get visibleHistory() {
    const rows =
      this.historyExpanded || this.linkHistory.length <= 2
        ? this.linkHistory
        : this.linkHistory.slice(0, 2);
    const selectedKey = this.selectedLinkKey;
    const insightsOpen = this.showBuyerInsightsEmbed;
    return rows.map((item) => {
      const isSelected = Boolean(item.linkKey && item.linkKey === selectedKey);
      const statusDisplay = resolveHistoryStatus(item.type, item.status);
      return {
        ...item,
        displayStatus: statusDisplay.label,
        statusClass: statusDisplay.statusClass,
        itemClass: isSelected
          ? "pf-history-item pf-history-item_selected"
          : "pf-history-item",
        showInsightsButton:
          Boolean(item.linkKey) && !(insightsOpen && isSelected)
      };
    });
  }

  get showHistoryToggle() {
    return this.linkHistory.length > 2;
  }

  get historyToggleLabel() {
    if (this.historyExpanded) {
      return "Show less";
    }
    return `View all (${this.linkHistory.length})`;
  }

  toggleHistoryExpanded() {
    this.historyExpanded = !this.historyExpanded;
  }

  handleViewInsights(event) {
    const linkKey = event.currentTarget?.dataset?.linkKey || "";
    if (!linkKey || linkKey === this.selectedLinkKey) {
      return;
    }
    this.selectedLinkKey = linkKey;
    this.bumpIframeCache();
  }

  togglePreviewExpanded() {
    this.previewExpanded = !this.previewExpanded;
  }
  bumpIframeCache() {
    this.iframeBust = Date.now();
  }

  handlePrimaryMicrosite() {
    this.openMicrositeModal({ skipIfExists: false });
  }

  openMicrositeModal({ skipIfExists = false, autoCreate = false } = {}) {
    if (!this.recordId) {
      this.showToast("Error", "Record Id not available", "error");
      return;
    }
    this.isLoading = true;
    getLeadDetails({ leadId: this.recordId })
      .then((lead) => {
        this.applyLeadLinkFromResponse(lead);
        // Auto-open path: a microsite already exists, so do not pop the modal.
        if (skipIfExists && this.hasMicrosite) {
          return;
        }
        this.clientName = lead?.[LEAD_BUYER_NAME_FIELD];
        if (lead?.[LEAD_PROJECT_FIELD]) {
          const p = String(lead[LEAD_PROJECT_FIELD]).trim();
          const m = this.projectOptions?.find((o) => o.value === p);
          if (m) this.selectedProjects = [m.value];
        }
        this.micrositeLeadType = resolveDefaultMicrositeLeadType(
          lead?.[LEAD_STATUS_FIELD]
        );
        this.selectedConfigurations = [];
        this.configurationOptions = [];
        this.modalAction = "microsite";
        // Auto-create: all mandatory fields already known → generate silently.
        if (autoCreate && this.isAutoCreateReady("microsite")) {
          this.submitGenerate();
          return;
        }
        this.isModalOpen = true;
        this.loadConfigurationsForSelectedProjects();
      })
      .catch((error) =>
        this.showToast("Error", CUSTOMER_SUPPORT_MESSAGE, "error")
      )
      .finally(() => {
        this.isLoading = false;
      });
  }

  closeModal() {
    const wasSpecialFlow =
      this.modalAction === "siteVisit" || this.modalAction === "postVisit";
    this.isModalOpen = false;
    this.modalAction = "microsite";
    this.siteVisitProject = "";
    this.siteVisitManager = "";
    this.siteVisitManagerOptions = [];
    this.isLoadingSiteVisitManagers = false;
    this.postVisitProject = "";
    this.postVisitSelectedConfigurations = [];
    this.postVisitConfigurationOptions = [];
    this.isLoadingPostVisitConfigurations = false;
    this.postVisitReassignTo = "";
    this.salesTeamOptions = [];
    this.isLoadingSalesTeam = false;
    this.micrositeLeadType = "new";
    this.selectedConfigurations = [];
    this.configurationOptions = [];
    this.showCopySuccess = false;
    this.successCopyText = "";
    this.copyButtonLabel = "Copy message";
    this.pendingAutoCopy = false;
    if (wasSpecialFlow) this.loadProjects();
  }

  handleMicrositeLeadTypeChange(event) {
    this.micrositeLeadType = event.detail.value;
  }
  handleConfigurationChange(event) {
    this.selectedConfigurations = event.detail.value || [];
  }

  loadConfigurationsForSelectedProjects() {
    if (!this.selectedProjects?.length) {
      this.configurationOptions = [];
      this.selectedConfigurations = [];
      this.isLoadingConfigurations = false;
      return Promise.resolve();
    }
    this.isLoadingConfigurations = true;
    return getConfigurationsForProjects({ projectNames: this.selectedProjects })
      .then((labels) => {
        const options = (labels || []).map((label) => ({
          label,
          value: label
        }));
        this.configurationOptions = options;
        const allowed = new Set(options.map((o) => o.value));
        this.selectedConfigurations = (this.selectedConfigurations || []).filter(
          (value) => allowed.has(value)
        );
      })
      .catch(() => {
        this.configurationOptions = [];
        this.selectedConfigurations = [];
        this.showToast("Warning", CUSTOMER_SUPPORT_MESSAGE, "warning");
      })
      .finally(() => {
        this.isLoadingConfigurations = false;
      });
  }

  handleNameChange(event) {
    this.clientName = event.target.value;
  }
  handleSiteVisitDateTimeChange(event) {
    this.siteVisitDateTime = normalizeSiteVisitDateTime(event.target.value);
  }
  handleSiteVisitProjectChange(event) {
    this.siteVisitProject = event.detail.value || "";
    this.siteVisitManager = "";
    this.siteVisitManagerOptions = [];
    if (this.siteVisitProject) {
      this.loadSiteVisitManagers(this.siteVisitProject);
    }
  }
  handleSiteVisitManagerChange(event) {
    this.siteVisitManager = event.detail.value || "";
  }

  buildSiteVisitManagerPayload() {
    if (!this.siteVisitManager) {
      return undefined;
    }
    const selected = (this.siteVisitManagerOptions || []).find(
      (option) => option.value === this.siteVisitManager
    );
    const payload = { id: this.siteVisitManager };
    if (selected?.name) {
      payload.name = selected.name;
    }
    return payload;
  }
  handlePostVisitProjectChange(event) {
    this.postVisitProject = event.detail.value || "";
    this.postVisitSelectedConfigurations = [];
    this.postVisitConfigurationOptions = [];
    if (this.postVisitProject) {
      this.loadPostVisitConfigurations(this.postVisitProject);
    }
  }
  handlePostVisitConfigurationChange(event) {
    const selected = event.detail.value || [];
    this.postVisitSelectedConfigurations = selected.includes(
      ALL_CONFIG_OPTION_VALUE
    )
      ? [ALL_CONFIG_OPTION_VALUE]
      : selected;
  }

  handlePostVisitReassignChange(event) {
    this.postVisitReassignTo = event.detail.value || "";
  }

  loadSalesTeam() {
    this.isLoadingSalesTeam = true;
    return getSalesTeam()
      .then((rows) => {
        const options = (rows || []).map((row) => ({
          label: row.displayName || row.name,
          value: row.id
        }));
        this.salesTeamOptions = options;
        if (
          this.postVisitReassignTo &&
          !options.some((option) => option.value === this.postVisitReassignTo)
        ) {
          this.postVisitReassignTo = "";
        }
        return options;
      })
      .catch(() => {
        this.salesTeamOptions = [];
        this.postVisitReassignTo = "";
        return [];
      })
      .finally(() => {
        this.isLoadingSalesTeam = false;
      });
  }

  getResolvedPostVisitConfigurations() {
    const selected = this.postVisitSelectedConfigurations || [];
    if (selected.includes(ALL_CONFIG_OPTION_VALUE)) {
      return [ALL_CONFIG_API_VALUE];
    }
    return selected;
  }
  loadPostVisitConfigurations(projectName) {
    const normalizedProject = (projectName || "").trim();
    if (!normalizedProject) {
      this.postVisitConfigurationOptions = [];
      this.postVisitSelectedConfigurations = [];
      this.isLoadingPostVisitConfigurations = false;
      return Promise.resolve([]);
    }
    this.isLoadingPostVisitConfigurations = true;
    return getConfigurationsForProjects({ projectNames: [normalizedProject] })
      .then((labels) => {
        const specificOptions = (labels || []).map((label) => ({
          label,
          value: label
        }));
        this.postVisitConfigurationOptions = [
          { label: "All", value: ALL_CONFIG_OPTION_VALUE },
          ...specificOptions
        ];
        const allowed = new Set(
          this.postVisitConfigurationOptions.map((o) => o.value)
        );
        this.postVisitSelectedConfigurations = (
          this.postVisitSelectedConfigurations || []
        ).filter((value) => allowed.has(value));
        return this.postVisitConfigurationOptions;
      })
      .catch(() => {
        this.showToast("Warning", CUSTOMER_SUPPORT_MESSAGE, "warning");
        this.postVisitConfigurationOptions = [
          { label: "All", value: ALL_CONFIG_OPTION_VALUE }
        ];
        this.postVisitSelectedConfigurations = [];
        return [];
      })
      .finally(() => {
        this.isLoadingPostVisitConfigurations = false;
      });
  }
  handleProjectChange(event) {
    this.selectedProjects = event.detail.value || [];
    if (this.modalAction === "microsite") {
      this.loadConfigurationsForSelectedProjects();
    }
  }

  handleConfirmSiteVisit() {
    this.openSiteVisitModal({ skipIfExists: false });
  }

  openSiteVisitModal({ skipIfExists = false, autoCreate = false } = {}) {
    if (!this.recordId) {
      this.showToast("Error", "Record Id not available", "error");
      return;
    }
    this.isLoading = true;
    Promise.allSettled([
      getLeadDetails({ leadId: this.recordId }),
      this.loadSiteVisitProjects(),
      getLatestSiteVisitDateTime({ leadId: this.recordId })
    ])
      .then(([leadResult, optsResult, dtResult]) => {
        if (leadResult.status !== "fulfilled") {
          throw leadResult.reason;
        }
        if (optsResult.status !== "fulfilled") {
          throw optsResult.reason;
        }
        const lead = leadResult.value;
        const opts = optsResult.value;
        const dt = dtResult.status === "fulfilled" ? dtResult.value : null;
        this.applyLeadLinkFromResponse(lead);
        // Auto-open path: a site visit link already exists, so don't pop.
        if (skipIfExists && this.hasSiteVisit) {
          return;
        }
        this.clientName = lead?.[LEAD_BUYER_NAME_FIELD];
        this.siteVisitProject = "";
        if (lead?.[LEAD_PROJECT_FIELD]) {
          const p = String(lead[LEAD_PROJECT_FIELD]).trim();
          const m = opts?.find((o) => o.value === p);
          if (m) this.siteVisitProject = m.value;
        }
        this.projectOptions = opts;
        this.siteVisitManager = "";
        this.siteVisitManagerOptions = [];
        this.siteVisitDateTime = normalizeSiteVisitDateTime(dt || new Date());
        this.modalAction = "siteVisit";
        // Auto-create: all mandatory fields already known → confirm silently.
        if (autoCreate && this.isAutoCreateReady("siteVisit")) {
          this.submitSiteVisit();
          return;
        }
        this.isModalOpen = true;
        if (this.siteVisitProject) {
          this.loadSiteVisitManagers(this.siteVisitProject);
        }
      })
      .catch((error) =>
        this.showToast("Error", CUSTOMER_SUPPORT_MESSAGE, "error")
      )
      .finally(() => {
        this.isLoading = false;
      });
  }

  handleGeneratePostVisit() {
    this.openPostVisitModal({ skipIfExists: false });
  }

  openPostVisitModal({ skipIfExists = false, autoCreate = false } = {}) {
    if (!this.recordId) {
      this.showToast("Error", "Record Id not available", "error");
      return;
    }
    this.isLoading = true;
    Promise.allSettled([
      getLeadDetails({ leadId: this.recordId }),
      this.loadSiteVisitProjects(),
      this.loadSalesTeam()
    ])
      .then(([leadResult, optsResult]) => {
        if (leadResult.status !== "fulfilled") {
          throw leadResult.reason;
        }
        if (optsResult.status !== "fulfilled") {
          throw optsResult.reason;
        }
        const lead = leadResult.value;
        const opts = optsResult.value;
        this.applyLeadLinkFromResponse(lead);
        // Auto-open path: a post visit link already exists, so don't pop.
        if (skipIfExists && this.hasPostVisit) {
          return;
        }
        this.clientName = lead?.[LEAD_BUYER_NAME_FIELD];
        this.postVisitProject = "";
        this.postVisitReassignTo = "";
        if (lead?.[LEAD_PROJECT_FIELD]) {
          const p = String(lead[LEAD_PROJECT_FIELD]).trim();
          const m = opts?.find((o) => o.value === p);
          if (m) this.postVisitProject = m.value;
        }
        this.projectOptions = opts;
        this.postVisitSelectedConfigurations = [];
        this.postVisitConfigurationOptions = [];
        this.modalAction = "postVisit";
        // Post visit needs a configuration selection, which can't be inferred,
        // so this normally falls through to the modal.
        if (autoCreate && this.isAutoCreateReady("postVisit")) {
          this.submitPostVisit();
          return;
        }
        this.isModalOpen = true;
        if (this.postVisitProject) {
          this.loadPostVisitConfigurations(this.postVisitProject);
        }
      })
      .catch((error) =>
        this.showToast("Error", CUSTOMER_SUPPORT_MESSAGE, "error")
      )
      .finally(() => {
        this.isLoading = false;
      });
  }

  submitSiteVisit() {
    const nameValidation = validateFullName(this.clientName);
    if (!nameValidation.valid) {
      this.showToast("Error", nameValidation.message, "error");
      return;
    }
    const buyerName = nameValidation.value;
    if (!this.siteVisitProject) {
      this.showToast("Error", "Select a project", "error");
      return;
    }
    if (!this.siteVisitDateTime) {
      this.showToast("Error", "Please select visit date and time", "error");
      return;
    }
    this.siteVisitDateTime = normalizeSiteVisitDateTime(this.siteVisitDateTime);
    const chosenDateTime = new Date(this.siteVisitDateTime);
    if (Number.isNaN(chosenDateTime.getTime())) {
      this.showToast("Error", "Invalid visit date and time", "error");
      return;
    }
    this.isLoading = true;
    const finishDeferredCopy = beginDeferredClipboardCopy();
    generatePropfocusTemplate({
      leadId: this.recordId,
      communicationType: COMM_TYPE_SITE_VISIT,
      contextJson: JSON.stringify({
        buyerName,
        projectName: this.siteVisitProject,
        visitDateTime: chosenDateTime.toISOString(),
        visitDate: chosenDateTime.toISOString().slice(0, 10),
        visitTime: `${String(chosenDateTime.getHours()).padStart(2, "0")}:${String(chosenDateTime.getMinutes()).padStart(2, "0")}`,
        siteVisitManager: this.buildSiteVisitManagerPayload()
      })
    })
      .then(async (result) => {
        await this.presentSuccessWithCopy(
          result,
          finishDeferredCopy,
          "Site visit confirmed"
        );
        await this.loadLinkHistory();
        this.markDataReloaded();
      })
      .catch(() =>
        this.showToast("Error", CUSTOMER_SUPPORT_MESSAGE, "error")
      )
      .finally(() => {
        this.isLoading = false;
      });
  }

  submitPostVisit() {
    const nameValidation = validateFullName(this.clientName);
    if (!nameValidation.valid) {
      this.showToast("Error", nameValidation.message, "error");
      return;
    }
    const buyerName = nameValidation.value;
    if (!this.postVisitProject) {
      this.showToast("Error", "Select a project", "error");
      return;
    }
    const selectedConfigurations = this.getResolvedPostVisitConfigurations();
    const visitedConfiguration =
      selectedConfigurations.length > 0 ? selectedConfigurations.join(", ") : "";
    if (!visitedConfiguration) {
      this.showToast("Error", "Select at least one configuration", "error");
      return;
    }

    this.isLoading = true;
    const finishDeferredCopy = beginDeferredClipboardCopy();
    const context = {
      buyerName,
      projectName: this.postVisitProject,
      visitedConfiguration
    };
    if (this.postVisitReassignTo) {
      context.assignedBrokerId = this.postVisitReassignTo;
    }
    generatePropfocusTemplate({
      leadId: this.recordId,
      communicationType: COMM_TYPE_POST_VISIT,
      contextJson: JSON.stringify(context)
    })
      .then(async (result) => {
        await this.presentSuccessWithCopy(
          result,
          finishDeferredCopy,
          "Post visit page generated"
        );
        await this.loadLinkHistory();
        this.markDataReloaded();
      })
      .catch(() =>
        this.showToast("Error", CUSTOMER_SUPPORT_MESSAGE, "error")
      )
      .finally(() => {
        this.isLoading = false;
      });
  }

  submitGenerate() {
    if (this.modalAction === "siteVisit") {
      this.submitSiteVisit();
      return;
    }
    if (this.modalAction === "postVisit") {
      this.submitPostVisit();
      return;
    }
    const nameValidation = validateFullName(this.clientName);
    if (!nameValidation.valid) {
      this.showToast("Error", nameValidation.message, "error");
      return;
    }
    const clientName = nameValidation.value;
    if (!this.selectedProjects.length) {
      this.showToast("Error", "Select at least one project", "error");
      return;
    }
    this.isLoading = true;
    const finishDeferredCopy = beginDeferredClipboardCopy();
    const configurationFilter =
      this.selectedConfigurations?.length > 0
        ? this.selectedConfigurations.join(", ")
        : "";
    generatePropfocusTemplate({
      leadId: this.recordId,
      communicationType: COMM_TYPE_MICROSITE,
      contextJson: JSON.stringify({
        buyerName: clientName,
        clientName,
        projects: this.selectedProjects,
        projectName:
          this.selectedProjects?.length === 1
            ? this.selectedProjects[0]
            : undefined,
        leadType: this.micrositeLeadType,
        configurationFilter
      })
    })
      .then(async (result) => {
        await this.presentSuccessWithCopy(
          result,
          finishDeferredCopy,
          "Microsite link generated"
        );
        await this.refreshMicrositeState();
        await this.loadLinkHistory();
        this.bumpIframeCache();
        this.markDataReloaded();
      })
      .catch(() =>
        this.showToast("Error", CUSTOMER_SUPPORT_MESSAGE, "error")
      )
      .finally(() => {
        this.isLoading = false;
      });
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  get showBuyerInsightsEmbed() {
    return (
      this.recordId != null &&
      String(this.recordId).trim().length > 0 &&
      !!this.buyerInsightsEmbedUrl &&
      this.hasMicrosite &&
      this.hasValidBuyerInsights
    );
  }
  get missingRecordContext() {
    return !this.recordId;
  }
  get showBodySpinner() {
    return this.isLoading && !this.isModalOpen;
  }

  renderedCallback() {
    if (!this.showCopySuccess) {
      return;
    }

    const messageField = this.template.querySelector("[data-success-message]");
    if (messageField && messageField.value !== this.successCopyText) {
      messageField.value = this.successCopyText;
    }

    if (!this.pendingAutoCopy) {
      return;
    }
    this.pendingAutoCopy = false;
    requestAnimationFrame(() => {
      if (!messageField) {
        return;
      }
      messageField.focus();
      messageField.select();
      if (typeof messageField.setSelectionRange === "function") {
        messageField.setSelectionRange(0, messageField.value.length);
      }
      void this.copyFromMessageField(messageField);
    });
  }

  resolveWhatsappMessageText(result) {
    const apiMessage =
      result && typeof result === "object"
        ? result.whatsappMessage ||
          result.WhatsAppMessage ||
          result.template ||
          result.Template
        : null;
    if (apiMessage && String(apiMessage).trim()) {
      return String(apiMessage).trim();
    }
    const url =
      typeof result === "string"
        ? result.trim()
        : String(result?.url || result?.Url || result?.link || "").trim();
    if (!url) {
      return "";
    }
    if (this.modalAction === "siteVisit") {
      return buildSiteVisitWhatsAppMessage(
        this.clientName,
        this.siteVisitProject,
        url
      );
    }
    if (this.modalAction === "postVisit") {
      const selectedConfigurations = this.getResolvedPostVisitConfigurations();
      return buildPostVisitWhatsAppMessage(
        this.clientName,
        this.postVisitProject,
        selectedConfigurations.includes(ALL_CONFIG_API_VALUE)
          ? "All Configurations"
          : selectedConfigurations.join(", "),
        url
      );
    }
    return buildMicrositeWhatsAppMessage(
      this.clientName,
      this.selectedProjects,
      url
    );
  }

  async copyFromMessageField(messageField) {
    const fieldText = String(messageField?.value || this.successCopyText || "").trim();
    if (!fieldText) {
      return false;
    }
    try {
      messageField.focus();
      messageField.select();
      if (typeof messageField.setSelectionRange === "function") {
        messageField.setSelectionRange(0, messageField.value.length);
      }
      if (document.execCommand("copy")) {
        return true;
      }
    } catch {
      // Fall through to clipboard API / hidden textarea.
    }
    return this.copyTextNow(fieldText);
  }

  async copyTextNow(text) {
    const value = String(text || "").trim();
    if (!value) {
      return false;
    }
    if (navigator.clipboard?.writeText) {
      try {
        await navigator.clipboard.writeText(value);
        return true;
      } catch {
        // Fall through to textarea fallback.
      }
    }
    return copyWithTextarea(value);
  }

  async handleCopySuccessMessage() {
    const messageField = this.template.querySelector("[data-success-message]");
    const copied = await this.copyFromMessageField(messageField);
    this.copyButtonLabel = copied ? "Copied!" : "Copy message";
    if (copied) {
      this.showToast("Success", "WhatsApp message copied", "success");
      window.setTimeout(() => {
        this.copyButtonLabel = "Copy message";
        this.closeModal();
      }, 600);
      return;
    }
    if (!String(this.successCopyText || "").trim()) {
      this.showToast(
        "Error",
        "No message available to copy. Please try generating again.",
        "error"
      );
      return;
    }
    this.showToast(
      "Error",
      "Could not copy automatically. Select the message above and press Ctrl+C (Cmd+C on Mac).",
      "warning"
    );
  }

  async presentSuccessWithCopy(result, finishDeferredCopy, successToast) {
    const text = this.resolveWhatsappMessageText(result);
    if (typeof finishDeferredCopy === "function") {
      finishDeferredCopy(text);
    }
    if (successToast) {
      this.showToast("Success", successToast, "success");
    }
    if (!this.showCopyModalEnabled) {
      this.closeModal();
      return;
    }
    this.successCopyText = text;
    this.showCopySuccess = true;
    // Ensure the success/copy view is visible even on the auto-create path,
    // where the form modal was never opened.
    this.isModalOpen = true;
    this.pendingAutoCopy = Boolean(text);
    this.copyButtonLabel = "Copy message";
  }
}
