Describe "Last Backup Test results" -Tag Database, Backup {
    $Results = Test-DbaLastBackup -SqlServer .\SQL2016 -Destination .\SQL2016
    foreach($result in $results)
    {
       $skipexists = $false
       $skipdbcc = $false
       $SkipRestore = $false
       ## Avoid test you know will fail using the skip
        if($result.FileExists -ne $true -and $result.FileExists -ne $false)
        {
            $skipexists = $true
        }
        if($result.DBCCResult -like '*DBCC CHECKTABLE skipped for restored master*' -or $result.DBCCResult -eq 'Skipped')
        {
            $skipDBCC = $true
        }
        if($Result.RestoreResult -eq 'Restore not located on shared location')
        {
            $SkipRestore =$true
        }
        It "$($Result.Database) on $($Result.SourceServer) File Should Exist" -Skip:$skipExists  {
            $Result.FileExists| Should Be 'True'
        }
        It "$($Result.Database) on $($Result.SourceServer) Restore should be Success" -skip:$SkipRestore{
            $Result.RestoreResult| Should Be 'Success'
        }
        It "$($Result.Database) on $($Result.SourceServer) DBCC should be Success" -Skip:$SkipDBCC{
            $Result.DBCCResult| Should Be 'Success'
        }
        It "$($Result.Database) on $($Result.SourceServer) Backup Should be less than 7 days old" {
            $Result.BackupTaken| Should BeGreaterThan (Get-Date).AddDays(-7) 
        }
    }        
}