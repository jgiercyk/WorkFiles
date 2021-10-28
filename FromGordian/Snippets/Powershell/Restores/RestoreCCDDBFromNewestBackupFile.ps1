import-module dbatools

$targetServer = 'GVL-SQL-RSMDEV'
$database = 'CCD-2018'
$filepath = '\\10.90.17.152\livedbbk\TGG-CCD01\FULL\CCD-2018'
$filename = (get-childitem $filepath | sort-object -property LastWriteTime -Descending | select -ExpandProperty name -first 1) 
$fileToRestore =  $filepath + '\' + $filename

$filemap = $null
$filemap = @{} 
 

        $TargetDatabaseFiles = Get-DbaDatabaseFile -SqlInstance $targetServer -Database $database
        $BackupDatabaseFiles = (read-dbabackupheader -sqlinstance $targetServer -path $fileToRestore).filelist
        If ($TargetDatabaseFiles.PhysicalName -ne $BackupDatabaseFiles.physicalName)
                {
                foreach($targetfile in $TargetDatabaseFiles)
                    {
                       foreach($backupefile in $BackupDatabaseFiles) 
                       { 
                        if ($targetfile.logicalname -eq $backupefile.logicalname)
                            {
                            $filemap.add($targetfile.LogicalName,$targetfile.PhysicalName)
                            }
                       }
                    }
                }


$sqlcmd = Restore-dbaDatabase -OutputScriptOnly -SqlInstance $targetServer -DatabaseName $database -FileMapping $filemap -path $fileToRestore -withReplace

#Invoke-Sqlcmd -ServerInstance $targetServer -Database master -Query $sqlcmd -QueryTimeout 0 -ConnectionTimeout 0 -Verbose

Invoke-Sqlcmd -ServerInstance $targetServer -Database 'master' -Query "ALTER DATABASE [${database}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE"

Invoke-Sqlcmd -ServerInstance $targetServer -Database 'master' -Query $sqlcmd -verbose -QueryTimeout 0 -ConnectionTimeout 0

Invoke-Sqlcmd -ServerInstance $targetServer -Database 'master' -Query "ALTER DATABASE [${database}] SET MULTI_USER" -verbose
