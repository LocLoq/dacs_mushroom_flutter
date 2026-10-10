param([switch]$Live,[switch]$All)
$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$testDrive = $null
$mapped = $false
$exitCode = 1
try {
    $testPath = $projectPath
    if ($projectPath.Contains("'")) {
        foreach ($letter in 'M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z') {
            if (!(Test-Path -LiteralPath ($letter + ':\'))) { $testDrive = $letter + ':'; break }
        }
        if ($null -eq $testDrive) { throw 'No unused drive letter available.' }
        subst $testDrive $projectPath
        if ($LASTEXITCODE -ne 0) { throw 'Drive mapping failed.' }
        $mapped = $true
        $testPath = $testDrive + '\'
    }
    Push-Location -LiteralPath $testPath
    try {
        $testArguments = @('test','--no-pub','--reporter','expanded')
        if (!$All) { $testArguments += @('test/api_client_test.dart','test/api_live_test.dart') }
        if ($Live) { $testArguments += '--dart-define=LIVE_API_TEST=true' }
        flutter @testArguments
        $exitCode = $LASTEXITCODE
    } finally { Pop-Location }
} finally { if ($mapped) { subst $testDrive /d } }
exit $exitCode
