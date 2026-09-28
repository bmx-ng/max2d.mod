param(
    [ValidateSet('core','sdl','software','gl','d3d9','d3d11')]
    [string[]]$Profiles = @('core','gl','sdl','d3d9','d3d11'),
    [string]$Sdk = (Resolve-Path "$PSScriptRoot\..\..\.."),
    [switch]$DebugBuild,
    [string[]]$Tests = @()
)
# Native compiler diagnostics can arrive on stderr even after successful builds.
$ErrorActionPreference = 'Continue'
$suites = @{
    core = @('text_layout','input_mapping','collisions','camera_math','paragraph_layout','paragraph_unicode','paragraph_interaction','text_selection','text_colors','text_styles','text_bidi')
    sdl = @('integration','api_coverage','dirty_regions','collision_render','viewport','sdl_mipmap_capability','camera_render','drawing_state','paragraph_render','text_colors_render')
    software = @('integration','api_coverage','dirty_regions','collision_render','viewport','sdl_mipmap_capability','camera_render','drawing_state','paragraph_render','text_colors_render')
    gl = @('integration','api_coverage','dirty_regions','viewport','gl_targets','gl_mipmaps','camera_render','drawing_state','paragraph_render','text_colors_render')
    d3d9 = @('d3d9_render','d3d9_targets','d3d9_mipmaps','viewport','camera_render','drawing_state','paragraph_render','text_colors_render')
    d3d11 = @('d3d11_render','d3d11_targets','d3d11_mipmaps','viewport','camera_render','drawing_state','paragraph_render','text_colors_render')
}
$output = Join-Path ([IO.Path]::GetTempPath()) ('max2d-regressions-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $output -ErrorAction Stop | Out-Null
Write-Output "Logs and executables: $output"
$results = @()
foreach ($profile in $Profiles) {
    $oldVideo = $env:SDL_VIDEODRIVER
    $oldRenderer = $env:SDL_RENDER_DRIVER
    try {
        if ($profile -eq 'software') {
            $env:SDL_VIDEODRIVER = 'dummy'
            $env:SDL_RENDER_DRIVER = 'software'
        }
        $selected = @($suites[$profile] | Where-Object { !$Tests.Count -or $_ -in $Tests })
        if (!$selected.Count) { throw "No selected tests in profile $profile" }
        foreach ($test in $selected) {
            $name = "$profile-$test"
            $exe = Join-Path $output "$name.exe"
            $arguments = @('makeapp')
            if (!$DebugBuild) { $arguments += '-r' }
            if ($profile -in @('gl','d3d9','d3d11')) { $arguments += @('-ud',"max2d_$profile") }
            $arguments += @('-o',$exe,"$Sdk\mod\max2d.mod\tests\$test.bmx")
            & "$Sdk\bin\bmk.exe" @arguments *> "$output\$name-build.log"
            if ($LASTEXITCODE -ne 0) { throw "$name build failed; see $output\$name-build.log" }
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo.FileName = $exe
            $process.StartInfo.WorkingDirectory = $output
            $process.StartInfo.UseShellExecute = $false
            $process.StartInfo.RedirectStandardOutput = $true
            $process.StartInfo.RedirectStandardError = $true
            $process.Start() | Out-Null
            $stdout = $process.StandardOutput.ReadToEndAsync()
            $stderr = $process.StandardError.ReadToEndAsync()
            if (!$process.WaitForExit(60000)) {
                $process.Kill()
                $process.WaitForExit()
                $stdout.Result | Set-Content "$output\$name-run.log"
                $stderr.Result | Set-Content "$output\$name-error.log"
                $process.Dispose()
                throw "$name timed out"
            }
            $process.WaitForExit()
            $stdout.Result | Set-Content "$output\$name-run.log"
            $stderr.Result | Set-Content "$output\$name-error.log"
            $text = $stdout.Result + $stderr.Result
            $exitCode = $process.ExitCode
            $process.Dispose()
            if ($exitCode -ne 0 -or $text -notmatch 'passed' -or $text -match 'FAILED:') { throw "$name failed; see $output" }
            $results += @{profile=$profile; test=$test; status='PASS'; debug=[bool]$DebugBuild}
            ConvertTo-Json -InputObject $results | Set-Content "$output\results.json"
            Write-Output "${name}: PASS"
        }
    } catch {
        $results += @{profile=$profile; test=$test; status='FAIL'; error=$_.ToString(); debug=[bool]$DebugBuild}
        ConvertTo-Json -InputObject $results | Set-Content "$output\results.json"
        Write-Output $_
        exit 1
    } finally {
        $env:SDL_VIDEODRIVER = $oldVideo
        $env:SDL_RENDER_DRIVER = $oldRenderer
    }
}
