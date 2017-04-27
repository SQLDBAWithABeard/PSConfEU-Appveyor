# This script will invoke pester tests
# It should invoke on PowerShell v2 and later
# We serialize XML results and pull them in appveyor.yml

#If Finalize is specified, we collect XML output, upload tests, and indicate build errors
param([switch]$Finalize)

#Initialize some variables, move to the project root
    $PSVersion = $PSVersionTable.PSVersion.Major
    $TestFile = "TestResultsPS$PSVersion.xml"
    $ProjectRoot = $ENV:APPVEYOR_BUILD_FOLDER
    Set-Location $ProjectRoot
   $ENV:APPVEYOR_BUILD_FOLDER

#Run a test with the current version of PowerShell
#Make things faster by removing most output
    if(-not $Finalize)
    {
        Import-Module sqlserver
        ## Restore a database onto the local instance
        Set-Location SQLSERVER:\SQL\localhost
        $Instance = Get-Item SQL2016
        $defaultbackup = $Instance.BackupDirectory
        $BackupFile = "$defaultbackup\ProviderDemo.bak" 
        Invoke-WebRequest -Uri 'https://onedrive.live.com/download?cid=C802DF42025D5E1F&resid=C802DF42025D5E1F%21418412&authkey=ACrHu72Apu0dIsQ' -OutFile $BackupFile
        $DataFile = $($Instance.DefaultFile) + 'ProviderDemo.mdf'
        $LogFile = $($Instance.DefaultLog) + 'ProviderDemo.ldf'
        $RelocateData = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile("ProviderDemo", $DataFile)
        $RelocateLog = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile("ProviderDemo_Log", $LogFile)
        Restore-SqlDatabase -ServerInstance 'localhost\SQL2016' -Database ProviderDemo -BackupFile $BackupFile -ReplaceDatabase -RestoreAction Database -RelocateFile @($RelocateData,$RelocateLog)
      
        "`n`tSTATUS: Testing with PowerShell $PSVersion`n"
        Import-Module Pester
		Set-Variable ProgressPreference -Value SilentlyContinue
        Invoke-Pester -Quiet -Path "$ProjectRoot\Tests" -OutputFormat NUnitXml -OutputFile "$ProjectRoot\$TestFile" -PassThru |
        Export-Clixml -Path "$ProjectRoot\PesterResults$PSVersion.xml"
        $ProjectRoot = $ENV:APPVEYOR_BUILD_FOLDER
        CD C:
    }

#If finalize is specified, check for failures and 
    else
    {
        #Show status...
            $AllFiles = Get-ChildItem -Path $ProjectRoot\*Results*.xml | Select -ExpandProperty FullName
            "`n`tSTATUS: Finalizing results`n"
            "COLLATING FILES:`n$($AllFiles | Out-String)"

        #Upload results for test page
            Get-ChildItem -Path "$ProjectRoot\TestResultsPS*.xml" | Foreach-Object {
        
                $Address = "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)"
                $Source = $_.FullName

                "UPLOADING FILES: $Address $Source"

                (New-Object 'System.Net.WebClient').UploadFile( $Address, $Source )
            }

        #What failed?
            $Results = @( Get-ChildItem -Path "$ProjectRoot\PesterResults*.xml" | Import-Clixml )
            
            $FailedCount = $Results |
                Select -ExpandProperty FailedCount |
                Measure-Object -Sum |
                Select -ExpandProperty Sum
    
            if ($FailedCount -gt 0) {

                $FailedItems = $Results |
                    Select -ExpandProperty TestResult |
                    Where {$_.Passed -notlike $True}

                "FAILED TESTS SUMMARY:`n"
                $FailedItems | ForEach-Object {
                    $Test = $_
                    [pscustomobject]@{
                        Describe = $Test.Describe
                        Context = $Test.Context
                        Name = "It $($Test.Name)"
                        Result = $Test.Result
                    }
                } |
                    Sort Describe, Context, Name, Result |
                    Format-List

                throw "$FailedCount tests failed."
            }
    }
0
