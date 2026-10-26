param([string]$HardwareDirectory = '')
$ErrorActionPreference = 'Stop'

$baadRoot = Split-Path $PSScriptRoot -Parent
if (!$HardwareDirectory) { $HardwareDirectory = Join-Path $baadRoot 'build/hardware_release' }
$HardwareDirectory = [IO.Path]::GetFullPath($HardwareDirectory)
$reportDirectory = Join-Path $HardwareDirectory 'reports'

function Read-Report([string]$name) {
    $path = Join-Path $reportDirectory $name
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing report: $path" }
    return Get-Content -Raw -LiteralPath $path
}

function Require-Match([string]$text, [string]$pattern, [string]$description) {
    $match = [regex]::Match($text, $pattern, [Text.RegularExpressions.RegexOptions]::Multiline)
    if (!$match.Success) { throw "Could not parse $description" }
    return $match
}

$timing = Read-Report 'timing.rpt'
$timingMatch = Require-Match $timing '(?m)^\s*(?<wns>-?\d+\.\d+)\s+(?<tns>-?\d+\.\d+)\s+(?<setupFail>\d+)\s+\d+\s+(?<whs>-?\d+\.\d+)\s+(?<ths>-?\d+\.\d+)\s+(?<holdFail>\d+)\s+\d+\s+(?<wpws>-?\d+\.\d+)\s+(?<tpws>-?\d+\.\d+)\s+(?<pulseFail>\d+)\s+\d+\s*$' 'design timing summary'
$wns = [double]$timingMatch.Groups['wns'].Value
$tns = [double]$timingMatch.Groups['tns'].Value
$whs = [double]$timingMatch.Groups['whs'].Value
$ths = [double]$timingMatch.Groups['ths'].Value
$wpws = [double]$timingMatch.Groups['wpws'].Value
$tpws = [double]$timingMatch.Groups['tpws'].Value
if ($wns -lt 0 -or $tns -lt 0 -or $whs -lt 0 -or $ths -lt 0 -or $wpws -lt 0 -or $tpws -lt 0) { throw 'Negative timing slack detected' }
if ([int]$timingMatch.Groups['setupFail'].Value -ne 0 -or [int]$timingMatch.Groups['holdFail'].Value -ne 0 -or [int]$timingMatch.Groups['pulseFail'].Value -ne 0) { throw 'Timing report has failing endpoints' }
if ($timing -notmatch 'All user specified timing constraints are met') { throw 'Vivado did not report all timing constraints met' }

$checkTiming = Read-Report 'check_timing.rpt'
$nonzeroTimingChecks = @([regex]::Matches($checkTiming, '(?m)^\d+\. checking [^(]+\((?<count>\d+)\)') | Where-Object { [int]$_.Groups['count'].Value -ne 0 })
if ($nonzeroTimingChecks.Count -ne 0) { throw 'check_timing contains nonzero findings' }

$drc = Read-Report 'drc.rpt'
$drcBad = @([regex]::Matches($drc, '(?m)^\|\s*[^|]+\|\s*(?<severity>Error|Critical Warning)\s*\|'))
if ($drcBad.Count -ne 0) { throw 'Final routed DRC contains error or critical-warning checks' }
$drcChecks = [int](Require-Match $drc '(?m)^\s*Checks found:\s*(?<count>\d+)\s*$' 'DRC check count').Groups['count'].Value

$methodology = Read-Report 'methodology.rpt'
$methodologyBad = @([regex]::Matches($methodology, '(?m)^\|\s*[^|]+\|\s*(?<severity>Error|Critical Warning)\s*\|'))
if ($methodologyBad.Count -ne 0) { throw 'Final methodology report contains error or critical-warning checks' }
$methodologyChecks = [int](Require-Match $methodology '(?m)^\s*Checks found:\s*(?<count>\d+)\s*$' 'methodology check count').Groups['count'].Value

$cdc = Read-Report 'cdc.rpt'
$cdcRows = @([regex]::Matches($cdc, '(?m)^(?:Warning|Info)\s+.+?\s+(?<endpoints>\d+)\s+(?<safe>\d+)\s+(?<unsafe>\d+)\s+(?<unknown>\d+)\s+(?<noAsync>\d+)\s*$'))
if ($cdcRows.Count -eq 0) { throw 'No CDC summary rows parsed' }
$cdcEndpoints = 0; $cdcSafe = 0; $cdcUnsafe = 0; $cdcUnknown = 0
foreach ($row in $cdcRows) {
    $cdcEndpoints += [int]$row.Groups['endpoints'].Value
    $cdcSafe += [int]$row.Groups['safe'].Value
    $cdcUnsafe += [int]$row.Groups['unsafe'].Value
    $cdcUnknown += [int]$row.Groups['unknown'].Value
}
if ($cdcUnsafe -ne 0 -or $cdcUnknown -ne 0 -or $cdcSafe -ne $cdcEndpoints) { throw 'CDC report contains unsafe, unknown, or unaccounted endpoints' }

$busSkew = Read-Report 'bus_skew.rpt'
$skewMatches = @([regex]::Matches($busSkew, 'Slack \(MET\)\s*:\s*(?<slack>-?\d+\.\d+)ns'))
if ($skewMatches.Count -eq 0) { throw 'No bus-skew constraints parsed' }
$skewValues = @($skewMatches | ForEach-Object { [double]$_.Groups['slack'].Value })
$minimumBusSkewSlack = ($skewValues | Measure-Object -Minimum).Minimum
if ($minimumBusSkewSlack -lt 0) { throw 'A bus-skew constraint failed' }

$clocks = Read-Report 'clocks.rpt'
$clockRows = @([regex]::Matches($clocks, '(?m)^.+?\s+(?<wns>-?\d+\.\d+)\s+(?<tns>-?\d+\.\d+)\s+(?<failing>\d+)\s+(?<total>\d+)\s+\d+\.\d+\s+(?:Clean|Ignored)\s+.+$'))
if ($clockRows.Count -eq 0) { throw 'No clock-interaction rows parsed' }
foreach ($row in $clockRows) {
    if ([double]$row.Groups['wns'].Value -lt 0 -or [double]$row.Groups['tns'].Value -lt 0 -or [int]$row.Groups['failing'].Value -ne 0) { throw 'Clock-interaction report contains a failing path group' }
}

$power = Read-Report 'power_estimated.rpt'
$powerWatts = [double](Require-Match $power '\| Total On-Chip Power \(W\)\s*\|\s*(?<watts>\d+\.\d+)\s*\|' 'estimated power').Groups['watts'].Value
$powerConfidence = (Require-Match $power '\| Confidence Level\s*\|\s*(?<confidence>[^|]+?)\s*\|' 'power confidence').Groups['confidence'].Value.Trim()

$utilization = Read-Report 'utilization.rpt'
$utilMatch = Require-Match $utilization '(?m)^\| BAAD_BD_wrapper\s+\|\s+\(top\)\s+\|\s*(?<luts>\d+)\s*\|\s*(?<logic>\d+)\s*\|\s*(?<lutram>\d+)\s*\|\s*(?<srl>\d+)\s*\|\s*(?<ffs>\d+)\s*\|\s*(?<bram36>\d+)\s*\|\s*(?<bram18>\d+)\s*\|\s*(?<uram>\d+)\s*\|\s*(?<dsp>\d+)\s*\|' 'top-level utilization'

$artifacts = @()
foreach ($name in @('BAAD_BD_wrapper.bit', 'BAAD_BD_wrapper.ltx', 'BAAD_BD_wrapper.xsa')) {
    $path = Join-Path $HardwareDirectory $name
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing hardware artifact: $path" }
    $file = Get-Item -LiteralPath $path
    $artifacts += [ordered]@{ name = $name; bytes = $file.Length; sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
}

$reviewedReports = @('timing.rpt','check_timing.rpt','drc.rpt','methodology.rpt','cdc.rpt','bus_skew.rpt','clocks.rpt','power_estimated.rpt','utilization.rpt')
$reportHashes = @($reviewedReports | ForEach-Object {
    [ordered]@{ name = $_; sha256 = (Get-FileHash -LiteralPath (Join-Path $reportDirectory $_) -Algorithm SHA256).Hash }
})

$review = [ordered]@{
    approved_for_board_testing = $true
    approval_scope = 'Build and software evidence only; physical board acceptance remains pending user execution.'
    reviewed_utc = [DateTime]::UtcNow.ToString('o')
    tool = 'Vivado 2025.2'
    timing = [ordered]@{ wns_ns=$wns; tns_ns=$tns; setup_failing_endpoints=0; whs_ns=$whs; ths_ns=$ths; hold_failing_endpoints=0; wpws_ns=$wpws; tpws_ns=$tpws; pulse_width_failing_endpoints=0; check_timing_nonzero_findings=0 }
    drc = [ordered]@{ checks=$drcChecks; errors=0; critical_warnings=0; warnings=$drcChecks }
    methodology = [ordered]@{ checks=$methodologyChecks; errors=0; critical_warnings=0; reviewed_warnings='DPIR-2 asynchronous DSP merge optimization; LUTAR-1 LUT async-reset optimization; XDCB-5 runtime efficiency; CLKC-56 clock LOC advisory.' }
    cdc = [ordered]@{ endpoints=$cdcEndpoints; safe=$cdcSafe; unsafe=$cdcUnsafe; unknown=$cdcUnknown }
    bus_skew = [ordered]@{ constraints=$skewMatches.Count; minimum_slack_ns=$minimumBusSkewSlack }
    clock_interaction = [ordered]@{ groups=$clockRows.Count; failing_groups=0; note='Clean same-clock groups; inter-clock paths are vendor constrained Max Delay Datapath Only.' }
    utilization = [ordered]@{ total_luts=[int]$utilMatch.Groups['luts'].Value; logic_luts=[int]$utilMatch.Groups['logic'].Value; lutrams=[int]$utilMatch.Groups['lutram'].Value; srls=[int]$utilMatch.Groups['srl'].Value; ffs=[int]$utilMatch.Groups['ffs'].Value; ramb36=[int]$utilMatch.Groups['bram36'].Value; ramb18=[int]$utilMatch.Groups['bram18'].Value; uram=[int]$utilMatch.Groups['uram'].Value; dsp_blocks=[int]$utilMatch.Groups['dsp'].Value }
    estimated_power = [ordered]@{ watts=$powerWatts; confidence=$powerConfidence; board_measurement=$false; note='Vectorless estimate only; reset activity warning can reduce accuracy.' }
    reviewed_integration_warnings = @(
        'BD 41-1347: intentional same-62-MHz-domain software FIFO flush; documented in IP_VALIDATION_REVIEW.md.',
        'BD 41-237: AXI4-Lite MAX_BURST_LENGTH metadata mismatch; no burst signals exist; documented and AXI behavior simulated.',
        'Startup Common 17-356: installed Tcl-app configuration error occurred before script execution; explicit build and report gates succeeded.'
    )
    artifacts = $artifacts
    report_hashes = $reportHashes
}

$output = Join-Path $reportDirectory 'release_review.json'
$review | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $output -Encoding UTF8
Write-Output "PASS: hardware reports approved for board testing; WNS=$wns ns, WHS=$whs ns, CDC unsafe/unknown=0/0, minimum bus-skew slack=$minimumBusSkewSlack ns."
Write-Output "Review: $output"
