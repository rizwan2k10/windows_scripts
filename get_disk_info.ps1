
# Author: rizwan2k10
# Created: 06/02/2017
# Requires powershell version 3.0
# Returns a json output for scsi disk and information for each scsi disk

function Escape-JSONString($str){
	if ($str -eq $null) {return ""}
	$str = $str.ToString().Replace('"','\"').Replace('\','\\').Replace("`n",'\n').Replace("`r",'\r').Replace("`t",'\t')
	return $str;
}

function Convert-Json($maxDepth = 10,$forceArray = $false) {
	begin {
		$data = @()
	}
	process{
		$data += $_
	}
	
	end{
	
		if ($data.length -eq 1 -and $forceArray -eq $false) {
			$value = $data[0]
		} else {	
			$value = $data
		}

		if ($value -eq $null) {
			return "null"
		}

		

		$dataType = $value.GetType().Name
		
		switch -regex ($dataType) {
	            'String'  {
					return  "`"{0}`"" -f (Escape-JSONString $value )
				}
	            '(System\.)?DateTime'  {return  "`"{0:yyyy-MM-dd}T{0:HH:mm:ss}`"" -f $value}
	            'Int32|Double' {return  "$value"}
				'Boolean' {return  "$value".ToLower()}
	            '(System\.)?Object\[\]' { # array
					
					if ($maxDepth -le 0){return "`"$value`""}
					
					$jsonResult = ''
					foreach($elem in $value){
						#if ($elem -eq $null) {continue}
						if ($jsonResult.Length -gt 0) {$jsonResult +=', '}				
						$jsonResult += ($elem | Convert-Json -maxDepth ($maxDepth -1))
					}
					return "[" + $jsonResult + "]"
	            }
				'(System\.)?Hashtable' { # hashtable
					$jsonResult = ''
					foreach($key in $value.Keys){
						if ($jsonResult.Length -gt 0) {$jsonResult +=', '}
						$jsonResult += 
@"
	"{0}": {1}
"@ -f $key , ($value[$key] | Convert-Json -maxDepth ($maxDepth -1) )
					}
					return "{" + $jsonResult + "}"
				}
	            default { #object
					if ($maxDepth -le 0){return  "`"{0}`"" -f (Escape-JSONString $value)}
					
					return "{" +
						(($value | Get-Member -MemberType *property | % { 
@"
	"{0}": {1}
"@ -f $_.Name , ($value.($_.Name) | Convert-Json -maxDepth ($maxDepth -1) )			
					
					}) -join ', ') + "}"
	    		}
		}
	}
}

function get_disk_info {

Get-WmiObject Win32_DiskDrive | % {
  $disk = $_
  $partitions = "ASSOCIATORS OF " +
                "{Win32_DiskDrive.DeviceID='$($disk.DeviceID)'} " +
                "WHERE AssocClass = Win32_DiskDriveToDiskPartition"
    New-Object -Type PSCustomObject -Property @{
      "($($disk.SCSIBus),$($disk.SCSITargetID))" =

  Get-WmiObject -Query $partitions | % {
    $partition = $_
    $drives = "ASSOCIATORS OF " +
              "{Win32_DiskPartition.DeviceID='$($partition.DeviceID)'} " +
              "WHERE AssocClass = Win32_LogicalDiskToPartition"
    Get-WmiObject -Query $drives | % {
        New-Object -Type PSCustomObject -Property @{
            Disk        = $disk.DeviceID
            DiskSize    = [string]$disk.Size
            DiskModel   = $disk.Model
            Partition   = $partition.Name
            RawSize     = [string]$partition.Size
            DriveLetter = $_.DeviceID
            VolumeName  = $_.VolumeName
            Size        = [string]$_.Size
            FreeSpace   = [string]$_.FreeSpace
            SCSI_Bus    = [string]$disk.SCSIBus
            SCSI_Port   = [string]$disk.SCSIPort
            SCSI_LogicalUnit = [string]$disk.SCSILogicalUnit
            SCSI_TargetID = [string]$disk.SCSITargetId
        }
      }
    }
  }
}
}

get_disk_info | Convert-Json