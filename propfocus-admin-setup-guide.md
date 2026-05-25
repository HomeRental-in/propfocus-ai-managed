# Propfocus Salesforce Setup Guide

Use this checklist to complete the Propfocus app setup in Salesforce.

## 1) Show the Admin Tab in the App

1. Go to **App Manager** (Service setup)
2. Open your app (Developer Edition app you are using) and click **Edit**.
3. Go to **Navigation Items**.
4. Add **propfocusAI Admin Setup**.
5. Click **Save** and refresh the app.

## 2) Add Lead LWC to Lead Record Page

1. Open any **Lead** record.
2. Click the **gear icon** and choose **Edit Page**.
3. In Lightning App Builder, search for **propfocusLeadLinkGen**.
4. Drag the component onto the page (for example, right sidebar or details area).
5. Click **Save** and **Activate**.
6. Assign as one of the following:
   - **Org Default**, or
   - **App + Record Type** for your current app.
7. Refresh the record page.

## 3) Update Custom Metadata Type Page Layout

1. Go to **Setup -> Custom Metadata Types**.
2. Click the label **Propfocus Config**.
3. On the detail page, scroll below the fields list.
4. Find **Page Layouts** and click **Edit**.
5. Add all fields to the layout and save.

## 4) Configure Propfocus Config Values

1. Go to **Setup -> Custom Metadata Types**.
2. Click **Manage**, then click **Edit** for **Propfocus Config**.
3. Scroll to the custom fields section and set each value to the API name of the Lead/Site Visit field in **your** org that should be mapped to the corresponding Propfocus concept. The package ships no Lead custom fields of its own for these mappings — use whatever you already have.
   - **API Named Credential** = `Propfocus_API`
   - **Buyer Id Field** = API name of the Lead field that uniquely identifies the buyer (e.g. an enquiry reference number, account number, or `Email`).
   - **Buyer Name Field** = API name of the Lead field holding the buyer's full name (e.g. `LastName` or a custom full-name field).
   - **Lead Status Field** = API name of the Lead field holding the lead status (e.g. `Status` or a custom status field).
   - **Project Field** = API name of the Lead field holding the project the buyer is interested in (e.g. `Company` or a custom project field).
   - **Pre-Sales Rep Source Field** = API name of the Lead field holding the pre-sales rep, or leave blank to fall back to `Owner.Name`.
   - **Lead Id Field** = lookup field API name on the Site Visit object that points to the Lead (e.g. `Lead__c`).
   - **Site Visit Status Field** = API name of the status field on the Site Visit object (e.g. `Status__c`).
   - **Site Visit Object** = API name of the Site Visit object if you have one (e.g. `Site_Visit__c`).
   - **Embed Base URL** = your real embed URL.
   - **Notification Type Developer Name** = `PropFocus_Notification` (or your org-specific developer name).
   - **Organization Id** = your real org id.
4. Click **Save**.

## 5) Add CSP Trusted Site

1. Go to **Setup -> CSP Trusted Sites**.
2. Click **New Trusted Site**.
3. Add:
   - **Trusted Site Name**: `PropfocusCDN` (any name is fine)
   - **Trusted Site URL**: `https://propfocus.in`
4. Click **Save**.
5. Ensure it is active for Lightning Experience (default is usually fine).
6. Hard refresh the page.

## 6) Update Named Credential URL

1. Go to **Setup -> Named Credentials**.
2. Open **Propfocus API**.
3. Change the URL to `https://dev.propfocus.in`.
4. Save changes.

