Param(
    [Parameter(Mandatory=$True)]
    [string]$ParamatersFile,
    [switch]$UpdateUsers
)


$ParametersContent = Get-Content $ParamatersFile
$Parameters = $ParametersContent | ConvertFrom-Json


function createUser ($site) {
    $sqlcommand = @{
        'Database' = $site.db_name
        'ServerInstance' =  $Parameters.parameters.db_server.value + '.database.windows.net'
        'Username' = $Parameters.parameters.db_admin_login.value
        'Password' = $Parameters.parameters.db_admin_password.value
        'OutputSqlErrors' = $true
        'Query' = "CREATE USER " + $site.db_login + " WITH PASSWORD = '" + $site.db_password + "';"
    }
    try {
        Invoke-Sqlcmd  @sqlcommand -ErrorAction 'Stop'
    } catch {
        if ($_ -like '*already exists*') {
            if ($UpdateUsers) {
                Write-Host 'User already exist, updating'
                updateUser $site
            } else {
                Write-Host 'User already exist, use -UpdateUsers to alter users, eg. to change password'
            }
        }
    }
}

function addUserPermission ($site) {
    $sqlcommand = @{
        'Database' = $site.db_name
        'ServerInstance' =  $Parameters.parameters.db_server.value + '.database.windows.net'
        'Username' = $Parameters.parameters.db_admin_login.value
        'Password' = $Parameters.parameters.db_admin_password.value
        'OutputSqlErrors' = $true
        'Query' = "ALTER ROLE db_owner ADD MEMBER " +  $site.db_login + ";" 
    }
    Invoke-Sqlcmd  @sqlcommand
}

function updateUser ($site) {
    $sqlcommand = @{
        'Database' = $site.db_name
        'ServerInstance' =  $Parameters.parameters.db_server.value + '.database.windows.net'
        'Username' = $Parameters.parameters.db_admin_login.value
        'Password' = $Parameters.parameters.db_admin_password.value
        'OutputSqlErrors' = $true
        'Query' = "ALTER USER " + $site.db_login + " WITH PASSWORD = '" + $site.db_password + "';"
    }
    Invoke-Sqlcmd  @sqlcommand
}

foreach ($site in $Parameters.parameters.sitesobject.value.sites) {
    Write-Host 'Configuring user for' $site.db_name
    createUser $site
    addUserPermission $site
}