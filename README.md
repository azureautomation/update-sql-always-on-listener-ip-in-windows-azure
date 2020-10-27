Update SQL Always On Listener IP in Windows Azure
=================================================

            

The SQL Server Always On Listener uses the IP Address of the Cloud Service for virtualized connectivity.


If all of the VMs in the cloud service are shut down the IP address changes and the SQL Server is no longer available via the listener name.


This script updates the IP Address for the listener to use the current IP Address of the cloud service.


Example 

**You must enable CredSSP on the client and server for this to work and install the WinRM certificates for the VM first.
**
[http://gallery.technet.microsoft.com/scriptcenter/Configures-Secure-Remote-b137f2fe](http://gallery.technet.microsoft.com/scriptcenter/Configures-Secure-Remote-b137f2fe)
 
**Client**


**Example:** 
enable-wsmancredssp -role client -delegatecomputer '*.cloudapp.net'


**Run GPEdit.msc** You must also enable delegating of fresh credentials using group policy editor on your client machine. Computer Configuration -> Administrative Templates -> System -> Credentials
 Delegation and then change the state of 'Allow Delegating Fresh Credentials with NTLM-only server authentication' to 'Enabled.' Its default state will say, 'Not configured.'


**Server**


**enable-wsmancredssp -role server**


        
    
TechNet gallery is retiring! This script was migrated from TechNet script center to GitHub by Microsoft Azure Automation product group. All the Script Center fields like Rating, RatingCount and DownloadCount have been carried over to Github as-is for the migrated scripts only. Note : The Script Center fields will not be applicable for the new repositories created in Github & hence those fields will not show up for new Github repositories.
