Describe "Here is a Test Block" {
    BeforeAll {
    $srv = New-Object Microsoft.SqlServer.Management.Smo.Server .\SQL2016
    }
    It "Should have a good message now " {
        $true | Should be $true
    }
    It "Should have a database" {
        $srv.Databases.Name -contains 'ProviderDemo' | Should Be $true
    }
}


