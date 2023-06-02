import-module dbatools
import-module importexcel

$server = 'aaa-ciadwdev01'  #<<<<<<<-------  Only variable needed is $server


$dbaver = get-module -Name dbatools | select -ExpandProperty version | select -expandproperty major

if ($dbaver -gt 1)
    {
      $dbaver
      Set-DbatoolsInsecureConnection -SessionOnly  
    }

Set-DbatoolsConfig -FullName 'sql.connection.trustcert' -Value $true -Register
$cred = get-credential

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

$databases = get-dbadatabase -SqlInstance $server -SqlCredential $cred -debug | select -ExpandProperty Name


$perms = Get-Dbalogin -SqlInstance $server  -SqlCredential $cred | ?{$_.LoginType -ne 'SqlLogin'} | select * 
$Groupperms = Get-Dbalogin -SqlInstance $server  -SqlCredential $cred | ?{$_.LoginType -eq 'WindowsGroup'} | select *

Foreach($db in $databases)   ### Collect individual user assignments
{
    try {
           $dbperms = Get-DbaDbRoleMember -SqlInstance $server -Database $db -SqlCredential $cred | ?{$_.UserName -in $perms.name} | select * 
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
        IF($dbperm.Username -in $Groupperms.name)   ### Collect group members
        {
            $members = Invoke-DbaQuery -SqlInstance $server -SqlCredential $cred -query ("xp_logininfo @acctname = '" + $dbperm.Login + "', @option = 'members'") 
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

Get-DbaServerRoleMember -SqlInstance $server -SqlCredential $cred -debug | Export-Excel -Path $outputfile -WorksheetName 'Sysadmins' -AutoSize -AutoFilter -FreezeTopRow   ### Collect and write administrator priv

foreach($db in $databases)
    {
    $perms | ?{$_.database -eq $db} | Export-Excel -Path $outputfile -WorksheetName $db -AutoSize -AutoFilter -FreezeTopRow
    }


#$perms | Out-GridView

