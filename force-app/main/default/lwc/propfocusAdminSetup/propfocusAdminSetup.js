import { LightningElement } from 'lwc';
import getUiConfiguration from '@salesforce/apex/PropfocusConfigService.getUiConfiguration';
import testConnection from '@salesforce/apex/PropfocusConfigService.testConnection';

export default class PropfocusAdminSetup extends LightningElement {
    config = {};
    isLoading = true;
    isTesting = false;
    testResult;
    testVariant = 'info';

    connectedCallback() { this.loadConfig(); }

    loadConfig() {
        this.isLoading = true;
        getUiConfiguration()
            .then((cfg) => { this.config = cfg || {}; })
            .catch(() => { this.config = {}; })
            .finally(() => { this.isLoading = false; });
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

    get apiNamedCredential() { return this.config?.apiNamedCredential || ''; }
    get embedBaseUrl() { return this.config?.embedBaseUrl || ''; }
    get organizationId() { return this.config?.organizationId || ''; }
    get logoUrl() { return this.config?.logoUrl || ''; }
    get buyerIdField() { return this.config?.buyerIdField || ''; }
    get buyerNameField() { return this.config?.buyerNameField || ''; }
    get leadStatusField() { return this.config?.leadStatusField || ''; }
    get projectField() { return this.config?.projectField || ''; }
    get resultClass() {
        return this.testVariant === 'success' ? 'result result_success' : 'result result_error';
    }
}
