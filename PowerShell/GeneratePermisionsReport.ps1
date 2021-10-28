import-module dbatools
import-module importexcel

$server = 'mmcvsrvrd01'  #<<<<<<<-------  Only variable needed is $server


##########################################################################################################################################
##   Script creates directory "C:\Permissions Reports\" if it does not exist.  It writes output files to that directory                 ##
##   The output files are names Permissions + servername and timestamp.                                                                 ##
##########################################################################################################################################

$path = "C:\Permissions Reports\"
$filedate = get-date -Format yyyymmddssmm
$outputfile = $path + 'Permissions_' + $server + '_' + $filedate + '.xlsx'

If (!(test-path $path))
    {
        md $path
    }

$databases = get-dbadatabase -SqlInstance $server | select -ExpandProperty Name


$perms = Get-DbaDbRoleMember -SqlInstance $server | ?{$_.LoginType -eq 'WindowsUser'} | select * 
$perms = $perms +  (Get-DbaDbRoleMember -SqlInstance $server | ?{$_.LoginType -eq 'WindowsGroup'} | select *)

Foreach($db in $databases)   ### Collect individual user assignments
{
    try {
           $dbperms = Get-DbaDbRoleMember -SqlInstance $server -Database $db | ?{$_.LoginType -in ('WindowsGroup','WindowsUser')} | select * 
        }
    catch {$ERROR[0]
            write-host $ERROR[0] -BackgroundColor Red
            Write-Host database $db -BackgroundColor Red
            Write-Host users $dbusers -BackgroundColor red
            Write-Host groups $dbgroups -BackgroundColor red

            EXIT
          }
    foreach($dbperm in $dbperms)
    {
        IF($dbperm.Logintype -eq 'WindowsGroup')   ### Collect group members
        {
            $members = invoke-sqlcmd -ServerInstance $server -query ("xp_logininfo @acctname = '" + $dbperm.Login + "', @option = 'members'")
            foreach($member in $members)
                    {  
                    $newrec = New-Object -TypeName PSCustomObject
                    $newrec | Add-Member -Name 'ComputerName' -value $dbperm.ComputerName -MemberType NoteProperty
                    $newrec | Add-Member -Name 'InstanceName' -value $dbperm.InstanceName -MemberType NoteProperty
                    $newrec | Add-Member -Name 'SqlInstance' -value $dbperm.SqlInstance -MemberType NoteProperty
                    $newrec | Add-Member -Name 'Database' -value $dbperm.Database -MemberType NoteProperty
                    $newrec | Add-Member -Name 'Role' -value $dbperm.Role -MemberType NoteProperty
                    $newrec | Add-Member -Name 'UserName' -value $member.'mapped login name' -MemberType NoteProperty
                    $newrec | Add-Member -Name 'Login' -value $member.'permission path' -MemberType NoteProperty
                    $newrec | Add-Member -Name 'IsSystemObject' -value $dbperm.IsSystemObject -MemberType NoteProperty
                    $newrec | Add-Member -Name 'LoginType' -value 'PermissionsViaGroup' -MemberType NoteProperty
                        TRY
                        {
                            $perms = $perms + $newrec
                            $newrec = @{}
                        } 
                        CATCH
                        {
                         $ERROR[0]
                         Write-host $ERROR[0] -ForegroundColor Red
                         write-host Record Causing Error = $newrec -BackgroundColor red 
                         EXIT
                        }
                    }
        }
        
    }
}

####  Write output file   ####

$perms | Export-Excel -Path $outputfile -WorksheetName 'All Databases' -AutoSize -AutoFilter -FreezeTopRow

Get-DbaServerRoleMember -SqlInstance $server | Export-Excel -Path $outputfile -WorksheetName 'Sysadmins' -AutoSize -AutoFilter -FreezeTopRow   ### Collect and write administrator priv

foreach($db in $databases)
    {
    $perms | ?{$_.database -eq $db} | Export-Excel -Path $outputfile -WorksheetName $db -AutoSize -AutoFilter -FreezeTopRow
    }


#$perms | Out-GridView