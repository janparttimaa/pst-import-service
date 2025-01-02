# PST Import Service

Outsource PST-file imports to Exchange Online from employees to IT-department in modern and secure manner.

## What is PST Import Service?
PST Import Service is an easy way to import your old PST-files from past years into your mailbox in the cloud to Exchange Online. With this service, migration of your files will be done on your behalf in a secure manner. Once the migration is done, your old PST data are safely stored in the cloud, and you are able to access the data also on mobile devices.

Purpose and goal of PST Import Service is that employee can share PST-files to IT Department in secure manner, which will then migrate those data to Exchange Online using azcopy and Azure Blob Storage (See [documentation](https://learn.microsoft.com/en-us/purview/use-network-upload-to-import-pst-files#optional-step-3-view-a-list-of-the-pst-files-uploaded-to-microsoft-365) "Use network upload to import your organization's PST files to Microsoft 365" from Microsoft).

## Prerequisites
- Windows Server as Terminal Server, where we are use it for following purpose:
    - Distributing folder share to employees so they can move their PST-files.
    - Uploading PST-files to Azure Blob Storage for migration.
- Separate hard drive to Windows Server called "PST Import Service".
    - Hard drive must have following 2 folders (one hidden folder and one visible folder):
        - PST Import Service$
        - Tools
- Admin and Remote Desktop access to Windows Server.
- Access to [Microsoft Purview](https://compliance.microsoft.com/) -portal as Admin.
- Make sure that you are following [requirements](https://learn.microsoft.com/en-us/purview/use-network-upload-to-import-pst-files#optional-step-3-view-a-list-of-the-pst-files-uploaded-to-microsoft-365) from Microsoft.
- Ticketing system e.g. Jira Service Management, where employees can send onboarding requests regarding to PST Import Service.
- Intranet-site running, for example, on SharePoint Online.

## Intranet-page of PST Import Service
First, create dedicated Intranet-page of PST Import Service on your company's local Intranet-site so users can read more information regarding to the PST Import Servcie and they can also have access to send onboarding request to the service if needed. Here is the example how the Intranet-page should look like:

[Screenshot]

## Dedicated ticket category of PST Import Service
Second, create dedicated ticket category to your ticketing system so employees can send onboarding requests. Link the ticket category to your Intranet-page as well. In this example, we created dedicated ticket category using Jira Service Management as ticketing system:

[Screenshot]

## Prepare Terminal Server to PST Import Service
