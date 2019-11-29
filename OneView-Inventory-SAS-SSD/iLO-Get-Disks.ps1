# ------------------ Parameters
Param (                    
        [string]$CSVfile,

        [string]$interfaceType             = 'SAS',
        [string]$mediaType                 = 'SSD'
      )



Function Get-disk (
    [string]$serverName,
    [string]$iloName,
    [string]$interfaceType, 
    [string]$mediaType,

    $iloSession
    )

    
{
    $data = @()
    $systems= Get-HPERedfishDataRaw  -session $iloSession -DisableCertificateAuthentication  -odataid '/redfish/v1/Systems'                                                                                                     
    foreach ($sys in $systems.Members.'@odata.id' )
    {
        $arrayControllerOdataid =   $sys + 'SmartStorage/ArrayControllers'
        $arrayControllers       =   Get-HPERedfishDataRaw -session $iloSession -DisableCertificateAuthentication  -odataid $arrayControllerOdataid
        foreach ($controllerOdataid in $arrayControllers.Members.'@odata.id')
        {
            $controller         = Get-HPERedfishDataRaw -session $iloSession -DisableCertificateAuthentication  -odataid $controllerOdataid
            $ddOdataid          = $controller.links.PhysicalDrives.'@odata.id'
            $diskDrives         = Get-HPERedfishDataRaw -session $iloSession -DisableCertificateAuthentication  -odataid $ddOdataid
            foreach ($diskOdataid in $diskDrives.Members.'@odata.id')
            {
                $pd             = Get-HPERedfishDataRaw -session $iloSession -DisableCertificateAuthentication  -odataid $diskOdataid
                if (($pd.InterfaceType -eq $interfaceType) -and ($pd.MediaType -eq $mediaType))
                {
                    $sn         = $pd.serialNumber
                    $interface  = $pd.InterfaceType
                    $model      = $pd.Model
                    $fw         = $pd.firmwareversion.current.versionstring
                    if ($sn)
                    {
                        $data   += "$serverName,$iloName,$interface,$model,$sn,$fw" + $CR
                   
                    }
                }
            }

        }
    }

    return $data
}



$CR             = "`n"
$COMMA          = ","

$diskInventory  = @()
$diskInventory  = "Server,iloName,Interface,Model,SerialNumber,firmware" + $CR

$date           = (get-date).toString('MM_dd_yyyy') 
$outFile        = "iLO_" + $date + "_disk_Inventory.csv"


### Access CSV
if (test-path $CSVfile)
{
    $CSV        = import-csv $CSVFile
    foreach ($ilo in $CSV)
    {
        $iloName        = $ilo.iloName
        if ( ($iloName) -or ($iloName -notlike '#*')) 
        {
            $username       = $ilo.userName
            $securePassword = $ilo.password | ConvertTo-SecureString -AsPlainText -Force
            $cred           = New-Object System.Management.Automation.PSCredential  -ArgumentList $userName, $securePassword


            ## Connect to iLO
            $iloSession     = Connect-HPERedfish -Address $iloName -Cred $cred -DisableCertificateAuthentication

            ## Get server name
            $systems= Get-HPERedfishDataRaw  -session $iloSession -DisableCertificateAuthentication  -odataid '/redfish/v1/Systems'                                                                                                     
            foreach ($sysOdataid in $systems.Members.'@odata.id' )
            {
                $computerSystem = Get-HPERedfishDataRaw  -session $iloSession -DisableCertificateAuthentication  -odataid $sysOdataid
                $sName          = $computerSystem.HostName
            }
            write-host "---- Collecting disk of type $interfaceType-$mediaType on server ---> $sName"
            $data = Get-disk -serverName $sName -iloSession $iloSession -iloName $iloName -interfaceType $interfaceType -mediaType $mediaType   
            if ($data)
            {
                $diskInventory += $data
            }
        }

    }

    $diskInventory | Out-File $outFile
    
    write-host -foreground CYAN "Inventory complete --> file: $outFile "
}
else 
{
    write-host -ForegroundColor YELLOW "Cannot find CSV file wih iLO information ---> $CSVFile . Skip inventory"
}
