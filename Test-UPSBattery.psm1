function Test-UPSBattery
{
<#
.Synopsis
   Checks that status of the system battery.
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
.INPUTS
   Inputs to this cmdlet (if any)
.OUTPUTS
   Output from this cmdlet (if any)
.NOTES
   General notes
.COMPONENT
   The component this cmdlet belongs to
.ROLE
   The role this cmdlet belongs to
.FUNCTIONALITY
   The functionality that best describes this cmdlet
#>
    [CmdletBinding(SupportsShouldProcess=$true, 
                   PositionalBinding=$false,
                   ConfirmImpact='High')]
    [OutputType()]
    Param
    (
        # The computers to shutdown.
        [Parameter(Mandatory=$false,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   ValueFromRemainingArguments=$false,
                   Position=0)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Alias("ServerName","Node")]
        [String[]]
        $ComputerName = @($env:COMPUTERNAME),

        # The Battery level to trigger action.
        [Parameter(Mandatory=$false,
                   Position=1)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [ValidateRange(0,100)]
        [Alias("Threshold")]
        [Int16]
        $BatteryThreshold = 25,

        # If specified the servers will power off at the battery threshold.
        [Parameter(Mandatory=$false,
                   Position=2)]
        [Switch]
        $PowerDownAtThreshold
    )

    Begin
    {
        $batteryStatus = Get-CimInstance -ClassName Win32_Battery -Namespace root\cimv2 -ComputerName $ComputerName
        $batteryStatus | ForEach-Object{
            Get-EventLog -Source Test-UPSBattery -LogName Application -ComputerName $_.SystemName -ErrorAction SilentlyContinue | Out-Null
            if(-not $?)
            {
                New-EventLog -Source Test-UPSBattery -LogName Application -ComputerName $_.SystemName -ErrorAction SilentlyContinue | Out-Null
            }
        }
    }
    Process
    {
        $batteryStatus | ForEach-Object{
            if($_.EstimatedChargeRemaining -le $BatteryThreshold -and $_.BatteryStatus -eq 1)
            #A BatteryStatus of 1 represents the battery is discharging.
            {
                if($PowerDownAtThreshold)
                {
                    $eventlogParams = @{'source'='Test-UPSBattery';
                                        'logname'='Application';
                                        'eventid'='3001';
                                        'message'="The UPS has initiated a shutdown due to a low battery threshold of $BatteryThreshold percent.";
                                        }
                    Invoke-Command -ComputerName $_.SystemName -ScriptBlock {Write-EventLog @eventlogParams; Stop-Computer}
                }
                else
                {
                    $eventlogParams = @{'source'='Test-UPSBattery';
                                        'logname'='Application';
                                        'eventid'='3001';
                                        'message'="The UPS has reached a low battery threshold of $BatteryThreshold percent.";
                                        }
                    Invoke-Command -ComputerName $_.SystemName -ScriptBlock {Write-EventLog @eventlogParams}
                }
            }
        }
    }
    End
    {
        $batteryNotFound = @((Compare-Object $ComputerName $batteryStatus.SystemName).InputObject)
        if($batteryNotFound)
        {
            Write-Warning -Message "The following computers do not have any detected UPSs. `n`r$batteryNotFound"
        }
    }
}