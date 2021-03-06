$BHPathDivider = [System.IO.Path]::DirectorySeparatorChar

if (-not (Get-Module -Name 'Plaster' -ListAvailable)) {
    Write-Output "`nPlaster is not yet installed...installing Plaster now..."
    Install-Module -Name 'Plaster' -Scope 'CurrentUser' -Repository PSGALLERY -Force
}

if (-not (Test-Path -path .gitignore)){
    New-Item -ItemType File -Name ".gitignore"
    Add-Content -Path $($PSScriptRoot + $BHPathDivider + ".gitignore") -Value ".vscode/"
    Add-Content -Path $($PSScriptRoot + $BHPathDivider + ".gitignore") -Value ".github/"
}

$Public = @( Get-ChildItem -Path $($PSScriptRoot + $BHPathDivider + "Public" + $BHPathDivider + "*.ps1") -ErrorAction SilentlyContinue )
$Private = @( Get-ChildItem -Path $($PSScriptRoot + $BHPathDivider + "Private" + $BHPathDivider + "*.ps1") -ErrorAction SilentlyContinue )

#Dot source the files
Foreach ($import in @($Public + $Private)) {
    Try {
        . $import.fullname
    }
    Catch {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}

Export-ModuleMember -Function $Public.Basename
