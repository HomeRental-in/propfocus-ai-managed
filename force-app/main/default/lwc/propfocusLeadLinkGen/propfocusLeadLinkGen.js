import { LightningElement, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { CurrentPageReference } from "lightning/navigation";

import getLeadDetails from "@salesforce/apex/PropFocusLeadService.getLeadDetails";
import getProjects from "@salesforce/apex/PropFocusLeadService.getProjects";
import getProjectsForSiteVisit from "@salesforce/apex/PropFocusLeadService.getProjectsForSiteVisit";
import generateMicrositeLink from "@salesforce/apex/PropFocusLeadService.generateMicrositeLink";
import generateSiteVisitWithProjectAndDateTime from "@salesforce/apex/PropFocusLeadService.generateSiteVisitWithProjectAndDateTime";
import getLatestSiteVisitDateTime from "@salesforce/apex/PropFocusLeadService.getLatestSiteVisitDateTime";
import getLinkHistory from "@salesforce/apex/PropFocusLeadService.getLinkHistory";
import getBuyerInsightsEmbedContext from "@salesforce/apex/PropFocusLeadService.getBuyerInsightsEmbedContext";
import getUiConfiguration from "@salesforce/apex/PropfocusConfigService.getUiConfiguration";

const LEAD_PROFOCUS_LINK_FIELD = "Propfocus_Link__c";
const LEAD_BUYER_ID_FIELD = "buyerId";
const LEAD_BUYER_NAME_FIELD = "buyerName";
const LEAD_PROJECT_FIELD = "projectName";

function formatDateTimeLocalInput(value) {
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) {
    return "";
  }
  const pad2 = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}T${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}

function getPropfocusLinkFromLead(lead) {
  if (!lead) return "";
  const v = lead[LEAD_PROFOCUS_LINK_FIELD];
  return v != null && String(v).trim() ? String(v).trim() : "";
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
  projectOptions;
  hasMicrosite = false;
  hasValidBuyerInsights = false;
  previewExpanded = false;
  linkHistory = [];

  @wire(CurrentPageReference)
  setPageRef(pageRef) {
    if (pageRef?.attributes?.recordId) {
      this.recordId = pageRef.attributes.recordId;
      this.iframeBust = Date.now();
      this.refreshMicrositeState();
      this.loadLinkHistory();
      this.loadBuyerInsightsEmbedContext();
    } else {
      this.recordId = undefined;
      this.storedPropfocusLink = "";
      this.enquiryRefNo = "";
      this.hasMicrosite = false;
      this.hasValidBuyerInsights = false;
      this.linkHistory = [];
      this.buyerInsightsEmbedUrl = "";
    }
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
      })
      .catch(() => {
        this.logoUrl = "";
        this.buyerInsightsEmbedBase = "";
        this.embedUsesSalesforceLeadId = false;
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
      this.hasValidBuyerInsights = false;
      return Promise.resolve();
    }
    return getLeadDetails({ leadId: this.recordId })
      .then((lead) => {
        this.applyLeadLinkFromResponse(lead);
      })
      .catch(() => {
        this.storedPropfocusLink = "";
        this.enquiryRefNo = "";
        this.hasMicrosite = false;
        this.hasValidBuyerInsights = false;
      })
      .finally(() => this.loadBuyerInsightsEmbedContext());
  }

  loadProjects() {
    getProjects()
      .then((result) => {
        this.projectOptions = result.map((item) => ({
          label: item,
          value: item
        }));
      })
      .catch(() => {});
  }

  loadSiteVisitProjects() {
    return getProjectsForSiteVisit()
      .then((result) => result.map((item) => ({ label: item, value: item })))
      .catch(() => this.projectOptions || []);
  }

  loadLinkHistory() {
    if (!this.recordId) {
      this.linkHistory = [];
      return Promise.resolve();
    }
    return getLinkHistory({ leadId: this.recordId })
      .then((rows) => {
        this.linkHistory = (rows || []).map((row) => ({
          id: row.id,
          type: row.type || "-",
          projectName: row.projectName || "-",
          status: row.status || "-",
          url: row.url || "",
          createdAt: row.createdAt
            ? new Date(row.createdAt).toLocaleString()
            : "-"
        }));
      })
      .catch(() => {
        this.linkHistory = [];
      });
  }

  get primaryMicrositeLabel() {
    return this.hasMicrosite ? "Regenerate Microsite" : "Generate Microsite";
  }

  get iframeSrc() {
    if (!this.buyerInsightsEmbedUrl) return "";
    const ts = this.iframeBust || Date.now();
    const separator = this.buyerInsightsEmbedUrl.includes("?") ? "&" : "?";
    return `${this.buyerInsightsEmbedUrl}${separator}_pf=${ts}`;
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
    if (this.modalAction === "siteVisit") return "Confirm site visit";
    return this.hasMicrosite
      ? "Regenerate Propfocus microsite"
      : "Generate Propfocus microsite";
  }
  get modalSubmitLabel() {
    if (this.modalAction === "siteVisit") return "Confirm";
    return this.hasMicrosite ? "Regenerate" : "Generate";
  }
  get isSingleProjectSelection() {
    return this.modalAction === "siteVisit";
  }
  get hasHistory() {
    return this.linkHistory.length > 0;
  }

  togglePreviewExpanded() {
    this.previewExpanded = !this.previewExpanded;
  }
  bumpIframeCache() {
    this.iframeBust = Date.now();
  }

  handlePrimaryMicrosite() {
    if (!this.recordId) {
      this.showToast("Error", "Lead Id not available", "error");
      return;
    }
    this.isLoading = true;
    getLeadDetails({ leadId: this.recordId })
      .then((lead) => {
        this.applyLeadLinkFromResponse(lead);
        this.clientName = lead?.[LEAD_BUYER_NAME_FIELD];
        if (lead?.[LEAD_PROJECT_FIELD]) {
          const p = String(lead[LEAD_PROJECT_FIELD]).trim();
          const m = this.projectOptions?.find((o) => o.value === p);
          if (m) this.selectedProjects = [m.value];
        }
        this.modalAction = "microsite";
        this.isModalOpen = true;
      })
      .catch((error) =>
        this.showToast(
          "Error",
          error.body?.message || "Failed to fetch Lead",
          "error"
        )
      )
      .finally(() => {
        this.isLoading = false;
      });
  }

  closeModal() {
    const wasSiteVisit = this.modalAction === "siteVisit";
    this.isModalOpen = false;
    this.modalAction = "microsite";
    if (wasSiteVisit) this.loadProjects();
  }

  handleNameChange(event) {
    this.clientName = event.target.value;
  }
  handleSiteVisitDateTimeChange(event) {
    this.siteVisitDateTime = event.target.value;
  }
  handleProjectChange(event) {
    const values = event.detail.value || [];
    if (this.isSingleProjectSelection && values.length > 1) {
      this.selectedProjects = [values[values.length - 1]];
      return;
    }
    this.selectedProjects = values;
  }

  handleConfirmSiteVisit() {
    if (!this.recordId) {
      this.showToast("Error", "Lead Id not available", "error");
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
        this.clientName = lead?.[LEAD_BUYER_NAME_FIELD];
        this.selectedProjects = [];
        if (lead?.[LEAD_PROJECT_FIELD]) {
          const p = String(lead[LEAD_PROJECT_FIELD]).trim();
          const m = opts?.find((o) => o.value === p);
          if (m) this.selectedProjects = [m.value];
        }
        this.projectOptions = opts;
        this.siteVisitDateTime = formatDateTimeLocalInput(dt || new Date());
        this.modalAction = "siteVisit";
        this.isModalOpen = true;
      })
      .catch((error) =>
        this.showToast(
          "Error",
          error.body?.message || "Failed to fetch Lead",
          "error"
        )
      )
      .finally(() => {
        this.isLoading = false;
      });
  }

  submitSiteVisit() {
    const buyerName = this.clientName?.trim();
    if (!buyerName) {
      this.showToast("Error", "Full Name cannot be empty", "error");
      return;
    }
    if (this.selectedProjects.length !== 1) {
      this.showToast("Error", "Select exactly one project", "error");
      return;
    }
    if (!this.siteVisitDateTime) {
      this.showToast("Error", "Please select visit date and time", "error");
      return;
    }
    const chosenDateTime = new Date(this.siteVisitDateTime);
    if (Number.isNaN(chosenDateTime.getTime())) {
      this.showToast("Error", "Invalid visit date and time", "error");
      return;
    }
    this.isLoading = true;
    generateSiteVisitWithProjectAndDateTime({
      leadId: this.recordId,
      buyerName,
      projectName: this.selectedProjects[0],
      visitDateTime: chosenDateTime.toISOString()
    })
      .then(() => {
        this.showToast("Success", "Site visit confirmed", "success");
        this.loadLinkHistory();
        this.closeModal();
      })
      .catch((error) =>
        this.showToast(
          "Error",
          error.body?.message || "Request failed",
          "error"
        )
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
    const clientName = this.clientName?.trim();
    if (!clientName) {
      this.showToast("Error", "Full Name cannot be empty", "error");
      return;
    }
    const nameRegex = /^[A-Za-z\s]+$/;
    if (!nameRegex.test(clientName)) {
      this.showToast(
        "Error",
        "Full Name should contain only letters and spaces",
        "error"
      );
      return;
    }
    if (!this.selectedProjects.length) {
      this.showToast("Error", "Select at least one project", "error");
      return;
    }
    this.isLoading = true;
    generateMicrositeLink({
      leadId: this.recordId,
      clientName,
      listProj: this.selectedProjects
    })
      .then(async () => {
        this.showToast("Success", "Microsite link generated", "success");
        await this.refreshMicrositeState();
        await this.loadLinkHistory();
        this.bumpIframeCache();
        this.closeModal();
      })
      .catch((error) =>
        this.showToast(
          "Error",
          error.body?.message || "Generation failed",
          "error"
        )
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
}
