param(
    [ValidateSet('test','analyze','android','web','devices','camera')][string]$Task = 'test',
    [string]$Device = 'emulator-5554',
    [string[]]$TestFiles = @()
)
$ErrorActionPreference = 'Stop'
$taskProjectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$taskDrive = $null
$taskExit = 1
try {
    $taskRunPath = $taskProjectPath
    if ($taskProjectPath.Contains("'") -and $Task -notin @('analyze','devices')) {
        foreach ($letter in 'M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z') {
            if (!(Test-Path -LiteralPath ($letter + ':\'))) { $taskDrive = $letter + ':'; break }
        }
        if ($null -eq $taskDrive) { throw 'No unused drive letter available.' }
        subst $taskDrive $taskProjectPath
        if ($LASTEXITCODE -ne 0) { throw 'Drive mapping failed.' }
        $taskRunPath = $taskDrive + '\'
    }
    Push-Location -LiteralPath $taskRunPath
    try {
        $taskPreviousErrorPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        switch ($Task) {
            'test' { flutter test --no-pub --reporter expanded @TestFiles }
            'analyze' { flutter analyze --no-pub --no-fatal-infos }
            'android' { flutter build apk --debug --no-pub }
            'web' { flutter build web --no-pub }
            'devices' { flutter devices }
            'camera' { flutter test integration_test/batch_qr_camera_test.dart -d $Device --no-pub --reporter expanded }
        }
        $taskExit = $LASTEXITCODE
    } finally { $ErrorActionPreference = $taskPreviousErrorPreference; Pop-Location }
} finally { if ($null -ne $taskDrive) { subst $taskDrive /d } }
exit $taskExit
