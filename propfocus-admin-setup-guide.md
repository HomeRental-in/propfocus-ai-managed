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
3. Scroll to the custom fields section and set:
   - **API Named Credential** = `Propfocus_API`
   - **Buyer Id Field** = `Enquiry_Ref_No__c`
   - **Buyer Name Field** = `Full_Name__c`
   - **Lead Status Field** = `Lead_Status__c`
   - **Project Field** = `Project_Interested__c`
   - **Pre-Sales Rep Source Field** = `Pre_Sales_Rep_Source__c` (or any Lead field API name to map)
   - **Lead Id Field** = `Lead__c`
   - **Site Visit Status Field** = `Status__c`
   - **Site Visit Object** = `Site_Visit__c` (if object exists)
   - **Embed Base URL** = your real embed URL
   - **Notification Type Developer Name** = `PropFocus_Notification` (or your org-specific developer name)
   - **Organization Id** = your real org id
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

