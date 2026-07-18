import { LightningElement } from 'lwc';
import getUiConfiguration from '@salesforce/apex/PropfocusConfigService.getUiConfiguration';
import testConnection from '@salesforce/apex/PropfocusConfigService.testConnection';
import getInboundEndpoint from '@salesforce/apex/PropfocusConfigService.getInboundEndpoint';

export default class PropfocusAdminSetup extends LightningElement {
    config = {};
    isLoading = true;
    isTesting = false;
    testResult;
    testVariant = 'info';
    inboundEndpoint = '';
    endpointCopied = false;

    connectedCallback() {
        this.loadConfig();
        this.loadInboundEndpoint();
    }

    loadConfig() {
        this.isLoading = true;
        getUiConfiguration()
            .then((cfg) => { this.config = cfg || {}; })
            .catch(() => { this.config = {}; })
            .finally(() => { this.isLoading = false; });
    }

    loadInboundEndpoint() {
        getInboundEndpoint()
            .then((url) => { this.inboundEndpoint = url || ''; })
            .catch(() => { this.inboundEndpoint = ''; });
    }

    handleTestConnection() {
        this.isTesting = true;
        this.testResult = null;
        testConnection()
            .then((result) => {
                this.testResult = result?.message || 'No response';
                this.testVariant = result?.success ? 'success' : 'error';
            })
            .catch((error) => {
                this.testResult = error?.body?.message || error?.message || 'Connection test failed';
                this.testVariant = 'error';
            })
            .finally(() => { this.isTesting = false; });
    }

    handleCopyEndpoint() {
        navigator.clipboard.writeText(this.inboundEndpoint).then(() => {
            this.endpointCopied = true;
            setTimeout(() => { this.endpointCopied = false; }, 2000);
        });
    }

    get apiNamedCredential() { return this.config?.apiNamedCredential || ''; }
    get embedBaseUrl() { return this.config?.embedBaseUrl || ''; }
    get organizationId() { return this.config?.organizationId || ''; }
    get logoUrl() { return this.config?.logoUrl || ''; }
    get buyerIdField() { return this.config?.buyerIdField || ''; }
    get buyerNameField() { return this.config?.buyerNameField || ''; }
    get leadStatusField() { return this.config?.leadStatusField || ''; }
    get projectField() { return this.config?.projectField || ''; }
    get opportunityBuyerIdField() { return this.config?.opportunityBuyerIdField || ''; }
    get opportunityBuyerNameField() { return this.config?.opportunityBuyerNameField || ''; }
    get opportunityStatusField() { return this.config?.opportunityStatusField || ''; }
    get opportunityProjectField() { return this.config?.opportunityProjectField || ''; }
    get siteVisitOpportunityLookupField() { return this.config?.siteVisitOpportunityLookupField || ''; }
    get copyEndpointLabel() { return this.endpointCopied ? 'Copied!' : 'Copy'; }
    get resultClass() {
        return this.testVariant === 'success' ? 'result result_success' : 'result result_error';
    }
}
