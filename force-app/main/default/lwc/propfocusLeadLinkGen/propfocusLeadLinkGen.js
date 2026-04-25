import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CurrentPageReference } from 'lightning/navigation';

import getLeadDetails from '@salesforce/apex/PropFocusLeadService.getLeadDetails';
import getProjects from '@salesforce/apex/PropFocusLeadService.getProjects';
import getProjectsForSiteVisit from '@salesforce/apex/PropFocusLeadService.getProjectsForSiteVisit';
import generateMicrositeLink from '@salesforce/apex/PropFocusLeadService.generateMicrositeLink';
import generateSiteVisitWithProjectAndDateTime from '@salesforce/apex/PropFocusLeadService.generateSiteVisitWithProjectAndDateTime';
import getLatestSiteVisitDateTime from '@salesforce/apex/PropFocusLeadService.getLatestSiteVisitDateTime';
import isSiteVisitAvailable from '@salesforce/apex/PropFocusLeadService.isSiteVisitAvailable';
import isBuyerInsightsAvailable from '@salesforce/apex/PropFocusLeadService.isBuyerInsightsAvailable';
import getLinkHistory from '@salesforce/apex/PropFocusLeadService.getLinkHistory';
import getUiConfiguration from '@salesforce/apex/PropfocusConfigService.getUiConfiguration';

const LEAD_PROFOCUS_LINK_FIELD = 'Propfocus_Link__c';
const LEAD_BUYER_ID_FIELD = 'buyerId';
const LEAD_BUYER_NAME_FIELD = 'buyerName';
const LEAD_PROJECT_FIELD = 'projectName';

function formatDateTimeLocalInput(value) {
    const d = value instanceof Date ? value : new Date(value);
    if (Number.isNaN(d.getTime())) {
        return '';
    }
    const pad2 = (n) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}T${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}

function getPropfocusLinkFromLead(lead) {
    if (!lead) return '';
    const v = lead[LEAD_PROFOCUS_LINK_FIELD];
    return v != null && String(v).trim() ? String(v).trim() : '';
}

export default class PropfocusLeadLinkGen extends LightningElement {
    recordId;
    isLoading = false;
    isModalOpen = false;
    iframeBust = 0;
    storedPropfocusLink = '';
    enquiryRefNo = '';
    logoUrl = '';
    buyerInsightsEmbedBase = '';
    clientName;
    selectedProjects = [];
    modalAction = 'microsite';
    siteVisitDateTime = '';
    projectOptions;
    isSiteVisitAvailableBool = false;
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
            this.checkSiteVisitAvailability();
            this.loadLinkHistory();
        } else {
            this.recordId = undefined;
            this.storedPropfocusLink = '';
            this.enquiryRefNo = '';
            this.hasMicrosite = false;
            this.hasValidBuyerInsights = false;
            this.isSiteVisitAvailableBool = false;
            this.linkHistory = [];
        }
    }

    connectedCallback() {
        this.loadUiConfig();
        this.loadProjects();
    }

    loadUiConfig() {
        getUiConfiguration()
            .then((cfg) => {
                this.logoUrl = cfg?.logoUrl || '';
                this.buyerInsightsEmbedBase = cfg?.embedBaseUrl || '';
            })
            .catch(() => {
                this.logoUrl = '';
                this.buyerInsightsEmbedBase = '';
            });
    }

    applyLeadLinkFromResponse(lead) {
        this.storedPropfocusLink = getPropfocusLinkFromLead(lead);
        this.enquiryRefNo =
            lead?.[LEAD_BUYER_ID_FIELD] != null && String(lead[LEAD_BUYER_ID_FIELD]).trim()
                ? String(lead[LEAD_BUYER_ID_FIELD]).trim()
                : '';
        this.hasMicrosite = !!this.storedPropfocusLink;
    }

    refreshMicrositeState() {
        if (!this.recordId) {
            this.storedPropfocusLink = '';
            this.enquiryRefNo = '';
            this.hasMicrosite = false;
            this.hasValidBuyerInsights = false;
            return Promise.resolve();
        }
        return getLeadDetails({ leadId: this.recordId })
            .then((lead) => {
                this.applyLeadLinkFromResponse(lead);
                if (!this.hasMicrosite) {
                    this.hasValidBuyerInsights = false;
                    return;
                }
                return isBuyerInsightsAvailable({ leadId: this.recordId })
                    .then((isAvailable) => {
                        this.hasValidBuyerInsights = !!isAvailable;
                    })
                    .catch(() => {
                        this.hasValidBuyerInsights = false;
                    });
            })
            .catch(() => {
                this.storedPropfocusLink = '';
                this.enquiryRefNo = '';
                this.hasMicrosite = false;
                this.hasValidBuyerInsights = false;
            });
    }

    checkSiteVisitAvailability() {
        if (!this.recordId) {
            this.isSiteVisitAvailableBool = false;
            return;
        }
        isSiteVisitAvailable({ leadId: this.recordId })
            .then((result) => {
                this.isSiteVisitAvailableBool = result;
            })
            .catch(() => {
                this.isSiteVisitAvailableBool = false;
            });
    }

    loadProjects() {
        getProjects()
            .then((result) => {
                this.projectOptions = result.map((item) => ({ label: item, value: item }));
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
                    id: row.Id,
                    type: row.Type__c || '',
                    projectName: row.Project_Name__c || '-',
                    status: row.Status__c || '-',
                    url: row.URL__c || '',
                    createdAt: row.Created_At__c
                        ? new Date(row.Created_At__c).toLocaleString()
                        : '-'
                }));
            })
            .catch(() => {
                this.linkHistory = [];
            });
    }

    get primaryMicrositeLabel() {
        return this.hasMicrosite ? 'Regenerate Microsite' : 'Generate Microsite';
    }

    get iframeSrc() {
        if (!this.enquiryRefNo || !this.buyerInsightsEmbedBase) return '';
        const ts = this.iframeBust || Date.now();
        return `${this.buyerInsightsEmbedBase}/${encodeURIComponent(this.enquiryRefNo)}?_pf=${ts}`;
    }

    get embedFrameClass() {
        return this.previewExpanded ? 'pf-embed-frame pf-embed-frame_expanded' : 'pf-embed-frame pf-embed-frame_collapsed';
    }
    get embedIframeClass() {
        return this.previewExpanded ? 'pf-embed pf-embed_expanded' : 'pf-embed pf-embed_collapsed';
    }
    get previewToggleLabel() {
        return this.previewExpanded ? 'Collapse preview' : 'Expand preview';
    }
    get previewToggleIconName() {
        return this.previewExpanded ? 'utility:chevronup' : 'utility:chevrondown';
    }
    get modalTitle() {
        if (this.modalAction === 'siteVisit') return 'Confirm site visit';
        return this.hasMicrosite ? 'Regenerate Propfocus microsite' : 'Generate Propfocus microsite';
    }
    get modalSubmitLabel() {
        if (this.modalAction === 'siteVisit') return 'Confirm';
        return this.hasMicrosite ? 'Regenerate' : 'Generate';
    }
    get isSingleProjectSelection() {
        return this.modalAction === 'siteVisit';
    }
    get hasHistory() {
        return this.linkHistory.length > 0;
    }

    togglePreviewExpanded() { this.previewExpanded = !this.previewExpanded; }
    bumpIframeCache() { this.iframeBust = Date.now(); }

    handlePrimaryMicrosite() {
        if (!this.recordId) return this.showToast('Error', 'Lead Id not available', 'error');
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
                this.modalAction = 'microsite';
                this.isModalOpen = true;
            })
            .catch((error) => this.showToast('Error', error.body?.message || 'Failed to fetch Lead', 'error'))
            .finally(() => { this.isLoading = false; });
    }

    closeModal() {
        const wasSiteVisit = this.modalAction === 'siteVisit';
        this.isModalOpen = false;
        this.modalAction = 'microsite';
        if (wasSiteVisit) this.loadProjects();
    }

    handleNameChange(event) { this.clientName = event.target.value; }
    handleSiteVisitDateTimeChange(event) { this.siteVisitDateTime = event.target.value; }
    handleProjectChange(event) {
        const values = event.detail.value || [];
        if (this.isSingleProjectSelection && values.length > 1) {
            this.selectedProjects = [values[values.length - 1]];
            return;
        }
        this.selectedProjects = values;
    }

    handleConfirmSiteVisit() {
        if (!this.recordId) return this.showToast('Error', 'Lead Id not available', 'error');
        this.isLoading = true;
        Promise.allSettled([
            getLeadDetails({ leadId: this.recordId }),
            this.loadSiteVisitProjects(),
            getLatestSiteVisitDateTime({ leadId: this.recordId })
        ])
            .then(([leadResult, optsResult, dtResult]) => {
                if (leadResult.status !== 'fulfilled') {
                    throw leadResult.reason;
                }
                if (optsResult.status !== 'fulfilled') {
                    throw optsResult.reason;
                }
                const lead = leadResult.value;
                const opts = optsResult.value;
                const dt = dtResult.status === 'fulfilled' ? dtResult.value : null;
                this.clientName = lead?.[LEAD_BUYER_NAME_FIELD];
                this.selectedProjects = [];
                if (lead?.[LEAD_PROJECT_FIELD]) {
                    const p = String(lead[LEAD_PROJECT_FIELD]).trim();
                    const m = opts?.find((o) => o.value === p);
                    if (m) this.selectedProjects = [m.value];
                }
                this.projectOptions = opts;
                this.siteVisitDateTime = formatDateTimeLocalInput(dt || new Date());
                this.modalAction = 'siteVisit';
                this.isModalOpen = true;
            })
            .catch((error) => this.showToast('Error', error.body?.message || 'Failed to fetch Lead', 'error'))
            .finally(() => { this.isLoading = false; });
    }

    submitSiteVisit() {
        const buyerName = this.clientName?.trim();
        if (!buyerName) return this.showToast('Error', 'Full Name cannot be empty', 'error');
        if (this.selectedProjects.length !== 1) return this.showToast('Error', 'Select exactly one project', 'error');
        if (!this.siteVisitDateTime) return this.showToast('Error', 'Please select visit date and time', 'error');
        const chosenDateTime = new Date(this.siteVisitDateTime);
        if (Number.isNaN(chosenDateTime.getTime())) return this.showToast('Error', 'Invalid visit date and time', 'error');
        this.isLoading = true;
        generateSiteVisitWithProjectAndDateTime({ leadId: this.recordId, buyerName, projectName: this.selectedProjects[0], visitDateTime: chosenDateTime.toISOString() })
            .then(() => {
                this.showToast('Success', 'Site visit confirmed', 'success');
                this.checkSiteVisitAvailability();
                this.loadLinkHistory();
                this.closeModal();
            })
            .catch((error) => this.showToast('Error', error.body?.message || 'Request failed', 'error'))
            .finally(() => { this.isLoading = false; });
    }

    submitGenerate() {
        if (this.modalAction === 'siteVisit') return this.submitSiteVisit();
        const clientName = this.clientName?.trim();
        if (!clientName) return this.showToast('Error', 'Full Name cannot be empty', 'error');
        const nameRegex = /^[A-Za-z\s]+$/;
        if (!nameRegex.test(clientName)) return this.showToast('Error', 'Full Name should contain only letters and spaces', 'error');
        if (!this.selectedProjects.length) return this.showToast('Error', 'Select at least one project', 'error');
        this.isLoading = true;
        generateMicrositeLink({ leadId: this.recordId, clientName, listProj: this.selectedProjects })
            .then(async () => {
                this.showToast('Success', 'Microsite link generated', 'success');
                await this.refreshMicrositeState();
                await this.loadLinkHistory();
                this.bumpIframeCache();
                this.closeModal();
            })
            .catch((error) => this.showToast('Error', error.body?.message || 'Generation failed', 'error'))
            .finally(() => { this.isLoading = false; });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    get showBuyerInsightsEmbed() {
        return this.recordId != null && String(this.recordId).trim().length > 0 && this.enquiryRefNo.length > 0 && this.hasMicrosite && this.hasValidBuyerInsights;
    }
    get missingRecordContext() { return !this.recordId; }
    get showBodySpinner() { return this.isLoading && !this.isModalOpen; }
}
