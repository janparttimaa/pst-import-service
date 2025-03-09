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
    - Size of the hard drive must be 100 GB or larger, e.g. 250 GB is suitable.
- Admin and Remote Desktop access to Windows Server.
- Access to [Microsoft Purview](https://compliance.microsoft.com/) -portal as Admin.
- Make sure that you are following [requirements](https://learn.microsoft.com/en-us/purview/use-network-upload-to-import-pst-files#optional-step-3-view-a-list-of-the-pst-files-uploaded-to-microsoft-365) from Microsoft.
- Ticketing system e.g. Jira Service Management, where employees can send onboarding requests regarding to PST Import Service.
- Intranet-site running, for example, on SharePoint Online.
- Security Group where we can share folder when users can move their PST-files. Name of the securitry group can be e.g. "CC-SG PST Import Service Users". Replace "CC" with your country code.
- Security Group where we can add operators of PST Import Service. name of the security group can be e.g. "CC-SG Intune PST Import Service Operators". Replace "CC" with your country code.

## Intranet-page of PST Import Service
First, create dedicated Intranet-page of PST Import Service on your company's local Intranet-site so users can read more information regarding to the PST Import Servcie and they can also have access to send onboarding request to the service if needed. Here is the example how the Intranet-page should look like:

![Screenshot](/img/intranet.png)

## Dedicated ticket category of PST Import Service
Second, create dedicated ticket category to your ticketing system so employees can send onboarding requests. Link the ticket category to your Intranet-page as well. In this example, we created dedicated ticket category using Jira Service Management as ticketing system:

![Screenshot](/img/ticketcategory.png)

Add appropriate description. Make ticket category also as simple as possible. In this example, only think employee needs to do is click "Create".

## Prepare Terminal Server to PST Import Service
Now, you need to prepare your Terminal Server for the PST Import Service.
1. Run "install.ps1" to Terminal Server. This script will create following:
    -  Hidden folder "PST Import Service$", where users can move their PST-files for migration.
    -  "Tools"-folder that includes needed tools. This folder includes following tools:
        - azcopy.exe from Microsoft.
        - Script "pstis.bat" that will migrate PST-files from "PST Import Service$" to Azure Blob Storage.
    -  Shortcut "Execute PST Import Service" -script. This is shortcut of "pstis.bat" -script.

    Screenshots:
    ![Screenshot](/img/fileexplorer1.png)
    ![Screenshot](/img/fileexplorer2.png)
2. Share folder "PST Import Service$" to security group "CC-SG PST Import Service Users". Users that are part of the Security group must have full control. Screenhots of permissions:
   ![Screenshot](/img/permissions1.png)
   ![Screenshot](/img/permissions2.png)
   ![Screenshot](/img/permissions3.png)
   ![Screenshot](/img/permissions4.png)
   ![Screenshot](/img/permissions5.png)
   ![Screenshot](/img/permissions6.png)
   ![Screenshot](/img/permissions7.png)
   ![Screenshot](/img/permissions8.png)
3. Make sure that security group "CC-SG Intune PST Import Service Operators" is part of the following built-in restricted groups from the server:
    - Administrators
    - Remote Desktop Users
  
## Prepare network drive deployment
Next, create either Group Policy or Intune Configuration Profile that will mount following network drive location to users that are part of "CC-SG PST Import Service Users":

```
\\terminalserver.example.com\PST Import Service$\%username%
```
Replace "terminalserver.example.com" to your terminal server address. 

Note that variable "%username%" is really important as this is the way, we can only give access to dedicated folder for users where users can migrate their PST-files and cannot access to another user's uploaded PST-files.

Here is the example of GPO:
![Screenshot](/img/gpo1.png)
![Screenshot](/img/gpo2.png)
![Screenshot](/img/gpo3.png)

Make sure that when user have removed from security group, network drive will be also removed from user automatically.