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

        # If specifed the servers will power off at the battery threshold.
        [Parameter(Mandatory=$false,
                   Position=2)]

        [Switch]
        $PowerDownAtThreshold
    )

    Begin
    {
        $batteryStatus = Get-CimInstance -ClassName Win32_Battery -Namespace root\cimv2 -ComputerName $ComputerName
        $batteryStatus | ForEach-Object{
            Get-EventLog -Source Test-UPSBattery -LogName Application -ComputerName $_.PSComputerName -ErrorAction SilentlyContinue | Out-Null
            if(-not $?)
            {
                New-EventLog -Source Test-UPSBattery -LogName Application -ComputerName $_.PSComputerName -ErrorAction SilentlyContinue | Out-Null
            }
        }
    }
    Process
    {
        $batteryStatus | ForEach-Object{
            if($_.EstimatedChargeRemaining -le $BatteryThreshold)
            {
                if($PowerDownAtThreshold)
                {
                    Invoke-Command -ComputerName $_.PSComputerName -ScriptBlock `
                    {
                        Write-EventLog -Source Test-UPSBattery -LogName Application  -EventId 3001 `
                            -Message "The UPS has initiated a shutdown due to a low battery threshold of $BatteryThreshold percent."; 
                        Stop-Computer -Force
                    }
                }
                else
                {
                    Invoke-Command -ComputerName $_.PSComputerName -ScriptBlock `
                    {
                        Write-EventLog -Source Test-UPSBattery -LogName Application  -EventId 3002 `
                            -Message "The UPS has reached a low battery threshold of $BatteryThreshold percent."
                    }
                }
            }
        }
    }
    End
    {
        $batteryNotFound = @((Compare-Object $ComputerName $batteryStatus.PSComputerName -ErrorAction SilentlyContinue).InputObject)
        if($batteryNotFound)
        {
            Write-Warning -Message "The following computers do not have any detected UPSs. `n`r$batteryNotFound"
        }
    }
}