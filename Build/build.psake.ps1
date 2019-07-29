[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingCmdletAliases", "")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
[cmdletbinding()]
param()
# PSake makes variables declared here available in other scriptblocks
Properties {
    $ProjectRoot = $ENV:BHProjectPath
    if (-not $ProjectRoot) {
        $ProjectRoot = $PSScriptRoot
    }

    $Timestamp = Get-Date -UFormat '%Y%m%d-%H%M%S'
    $PSVersion = $PSVersionTable.PSVersion.Major
    $lines = '----------------------------------------------------------------------'

    # Pester
    $TestScripts = Get-ChildItem "$ProjectRoot\Tests\*\*Tests.ps1"
    $TestFile = "Test-Unit_$($TimeStamp).xml"

    # Script Analyzer
    [ValidateSet('Error', 'Warning', 'Any', 'None')]
    $ScriptAnalysisFailBuildOnSeverityLevel = 'Error'
    $ScriptAnalyzerSettingsPath = "$ProjectRoot\Build\PSScriptAnalyzerSettings.psd1"

    # Build
    $ArtifactFolder = Join-Path -Path $ProjectRoot -ChildPath 'Artifacts'

    # Staging
    $StagingFolder = Join-Path -Path $ProjectRoot -ChildPath 'Staging'
    $StagingModulePath = Join-Path -Path $StagingFolder -ChildPath $env:BHProjectName
    $StagingModuleManifestPath = Join-Path -Path $StagingModulePath -ChildPath "$($env:BHProjectName).psd1"

    # Documentation
    $DocumentationPath = Join-Path -Path $StagingModulePath -ChildPath 'Documentation'
}


# Define top-level tasks
Task 'Default' -Depends 'Test'


# Show build variables
Task 'Init' {
    $lines
    Write-Output "Settng up Staging and Artifacts folders in .gitignore`n"
    Set-Location $ProjectRoot

    #Add Folders to gitignore. You don't need this in your repo
    $file = Get-Content "./.gitignore"
    $containsWord = $file | % { $_ -match "Staging|Artifacts" }
    if ($containsWord -notcontains $true) {
        Add-Content -Path .gitignore -Value "Staging/"
        Add-Content -Path .gitignore -Value "Artifacts/"
    }
    "`n"
    "Build System Details:`n"
    Get-Item ENV:BH*
    "`n"
}


# Clean the Artifact and Staging folders
Task 'Clean' -Depends 'Init' {
    $lines
    Write-Output "Resetting Staging and Artifacts Folders`n"

    $foldersToClean = @(
        $ArtifactFolder
        $StagingFolder
    )

    # Remove folders
    foreach ($folderPath in $foldersToClean) {
        Remove-Item -Path $folderPath -Recurse -Force -ErrorAction 'SilentlyContinue'
        New-Item -Path $folderPath -ItemType 'Directory' -Force | Out-String | Write-Verbose
    }
}

# Create a single .psm1 module file containing all functions
# Copy new module and other supporting files (Documentation / Examples) to Staging folder
Task 'CombineFunctionsAndStage' -Depends 'Clean' {
    $lines
    Write-Output "Combining Functions into one PSM1 and Staging`n"

    # Create folders
    New-Item -Path $StagingFolder -ItemType 'Directory' -Force | Out-String | Write-Verbose
    New-Item -Path $StagingModulePath -ItemType 'Directory' -Force | Out-String | Write-Verbose

    # Get public and private function files
    $publicFunctions = @( Get-ChildItem -Path "$env:BHModulePath\Public\*.ps1" -Recurse -ErrorAction 'SilentlyContinue' )
    $privateFunctions = @( Get-ChildItem -Path "$env:BHModulePath\Private\*.ps1" -Recurse -ErrorAction 'SilentlyContinue' )

    # Combine functions into a single .psm1 module
    $combinedModulePath = Join-Path -Path $StagingModulePath -ChildPath "$($env:BHProjectName).psm1"
    @($publicFunctions + $privateFunctions) | Get-Content | Add-Content -Path $combinedModulePath

    # Copy other required folders and files
    $pathsToCopy = @(
        Join-Path -Path $ProjectRoot -ChildPath 'Documentation'
        Join-Path -Path $ProjectRoot -ChildPath 'Examples'
        # Join-Path -Path $ProjectRoot -ChildPath 'CHANGELOG.md'
        Join-Path -Path $ProjectRoot -ChildPath 'README.md'
    )
    Copy-Item -Path $pathsToCopy -Destination $StagingFolder -Recurse

    # Copy existing manifest
    Copy-Item -Path $env:BHPSModuleManifest -Destination $StagingModulePath -Recurse
}


# Create a folder structure containing Public, Private and whatever else folders
# Copy new module and other supporting files (Documentation / Examples) to Staging folder
Task 'Stage' -Depends 'Clean' {
    $lines
    Write-Output "Building a Module folder at: [$StagingModulePath]`n"

    # Create folders
    New-Item -Path $StagingFolder -ItemType 'Directory' -Force | Out-String | Write-Verbose
    New-Item -Path $StagingModulePath -ItemType 'Directory' -Force | Out-String | Write-Verbose

    "`n"
    Write-Output "Staging Module Path is: $StagingModulePath "
    Write-Output "Staging Folder Path is: $StagingFolder"

    # Copy required folders and files
    $pathsToCopy = @(
        Join-Path -Path $ProjectRoot -ChildPath 'en-US'
        Join-Path -Path $ProjectRoot -ChildPath 'Docs'
        Join-Path -Path $ProjectRoot -ChildPath 'Build'
        Join-Path -Path $ProjectRoot -ChildPath 'Certs'
        Join-Path -Path $ProjectRoot -ChildPath 'PlasterTemplate'
        Join-Path -Path $ProjectRoot -ChildPath 'Scaffold'
        Join-Path -Path $ProjectRoot -ChildPath 'Spec'
        Join-Path -Path $ProjectRoot -ChildPath 'Public'
        Join-Path -Path $ProjectRoot -ChildPath 'Private'
        Join-Path -Path $ProjectRoot -ChildPath 'Tests'
        Join-Path -Path $ProjectRoot -ChildPath 'PSNow.nuspec'
        Join-Path -Path $ProjectRoot -ChildPath 'PSNow.psm1'
        Join-Path -Path $ProjectRoot -ChildPath 'PSNow.psd1'
        Join-Path -Path $ProjectRoot -ChildPath 'readme.md'
        Join-Path -Path $ProjectRoot -ChildPath 'LICENSE.md'
        Join-Path -Path $ProjectRoot -ChildPath '.gitignore'
    )
    Copy-Item -Path $pathsToCopy -Destination $StagingModulePath -Recurse

}

# Import new module
Task 'ImportStagingModule' -Depends 'Init' {
    $lines
    Write-Output "Reloading staged module from path: [$StagingModulePath]`n"

    # Reload module
    if (Get-Module -Name $env:BHProjectName) {
        Remove-Module -Name $env:BHProjectName
    }
    # Global scope used for UpdateDocumentation (PlatyPS)
    Import-Module -Name $StagingModulePath -ErrorAction 'Stop' -Force -Global
}


# Run PSScriptAnalyzer against code to ensure quality and best practices are used
Task 'Analyze' -Depends 'ImportStagingModule' {
    $lines
    Write-Output "Running PSScriptAnalyzer on path: [$StagingModulePath]`n"

    $Results = Invoke-ScriptAnalyzer -Path $StagingFolder -Recurse -Settings $ScriptAnalyzerSettingsPath -Verbose:$VerbosePreference
    #$Results | Select-Object 'RuleName', 'Severity', 'ScriptName', 'Line', 'Message' | Format-List
    $Results | Select-Object 'RuleName', 'Severity', 'ScriptName', 'Line', 'Message' | foreach {
        if($_.Severity -eq 'Error'){
            [console]::ForegroundColor = 'Red'; $_;
        }
        elseif ($_.Severity -eq 'Warning') {
            [console]::ForegroundColor = 'Yellow'; $_;
        }
        else {
            $_
        }
    } | Format-List
    [console]::ForegroundColor = 'White'

    switch ($ScriptAnalysisFailBuildOnSeverityLevel) {
        'None' {
            return
        }
        'Error' {
            Assert -conditionToCheck (
                ($Results | Where-Object 'Severity' -eq 'Error').Count -eq 0
            ) -failureMessage 'One or more ScriptAnalyzer errors were found. Build cannot continue!'
        }
        'Warning' {
            Assert -conditionToCheck (
                ($Results | Where-Object {
                        $_.Severity -eq 'Warning' -or $_.Severity -eq 'Error'
                    }).Count -eq 0) -failureMessage 'One or more ScriptAnalyzer warnings were found. Build cannot continue!'
        }
        default {
            Assert -conditionToCheck ($analysisResult.Count -eq 0) -failureMessage 'One or more ScriptAnalyzer issues were found. Build cannot continue!'
        }
    }
}


# Run Pester tests
# Unit tests: verify inputs / outputs / expected execution path
# Misc tests: verify manifest data, check comment-based help exists
Task 'Test' -Depends 'ImportStagingModule' {
    $lines
    Write-Output "Running Tests against the module`n"

    # PSScriptAnalyzer doesn't ignore files, only rules. Temporarily renaming files here which can safely skip Linting
    $directoriestoexclude = @('Spec' <#,'Scaffold'#>)
    foreach($directory in $directoriestoexclude){
        $insidepath = $env:BHModulePath + "/" + $directory
        $filestorename = @( Get-ChildItem -Path "$insidepath/*.ps1" -Recurse -ErrorAction 'SilentlyContinue' )
        foreach($file in $filestorename){
            $newname = $file.Name + ".hold"
            Rename-Item -path $file.PSPath -NewName $newname
        }
    }

    # Gather test results. Store them in a variable and file
    $TestFilePath = Join-Path -Path $StagingFolder -ChildPath $TestFile
    $TestResults = Invoke-Pester -Script $TestScripts -PassThru -OutputFormat 'NUnitXml' -OutputFile $TestFilePath -PesterOption @{IncludeVSCodeMarker = $true }

    # Fail build if any tests fail
    if ($TestResults.FailedCount -gt 0) {
        Write-Error "Failed '$($TestResults.FailedCount)' tests, build failed"
    }

    # PSScriptAnalyzer doesn't ignore files, only rules. Renaming the files back again
    foreach ($directory in $directoriestoexclude) {
        $insidepath = $env:BHProjectPath + "/" + $directory
        $filestorename = @( Get-ChildItem -Path "$insidepath/*.hold" -Recurse -ErrorAction 'SilentlyContinue' )
        foreach ($file in $filestorename) {
            $newname = (Get-Item $file).Basename
            Rename-Item -path $file.PSPath -NewName $newname
        }
    }


}


# Create new Documentation markdown files from comment-based help
Task 'UpdateDocumentation' -Depends 'ImportStagingModule' {
    $lines
    Write-Output "Updating Markdown help in Staging folder: [$DocumentationPath]`n"

    # $null = Import-Module -Name $env:BHPSModuleManifest -Global -Force -PassThru -Verbose

    # Cleanup
    Remove-Item -Path $DocumentationPath -Recurse -Force -ErrorAction 'SilentlyContinue'
    Start-Sleep -Seconds 5
    New-Item -Path $DocumentationPath -ItemType 'Directory' | Out-Null

    # Create new Documentation markdown files
    $platyPSParams = @{
        Module       = $env:BHProjectName
        OutputFolder = $DocumentationPath
        NoMetadata   = $true
    }
    New-MarkdownHelp @platyPSParams -ErrorAction 'SilentlyContinue' -Verbose | Out-Null

    # Update index.md
    Write-Output "Copying index.md...`n"
    Copy-Item -Path "$env:BHProjectPath\README.md" -Destination "$($DocumentationPath)\index.md" -Force -Verbose | Out-Null
}

Task 'UpdateBuildVersion' -Depends 'UpdateDocumentation' {
    $lines
    Write-Output "Updating the Module Version`n"

    $manifest = Import-PowerShellDataFile (Get-item Env:\BHPSModuleManifest).Value
    [version]$Version = $manifest.ModuleVersion
    switch ( $BuildRev ) {
        Major { [version]$NewVersion = "{0}.{1}.{2}.{3}" -f ($Version.Major + 1), $Version.Minor, $Version.Build, $version.Revision }
        Minor { [version]$NewVersion = "{0}.{1}.{2}.{3}" -f $Version.Major, ($Version.Minor + 1), $Version.Build, $version.Revision }
        Build { [version]$NewVersion = "{0}.{1}.{2}.{3}" -f $Version.Major, $Version.Minor, ($Version.Build + 1), $version.Revision }
        Revision { [version]$NewVersion = "{0}.{1}.{2}.{3}" -f $Version.Major, $Version.Minor, $Version.Build, ($version.Revision + 1) }
    }
    Update-ModuleManifest -Path (Get-Item env:\BHPSModuleManifest).Value -ModuleVersion $NewVersion
    Set-Item -Path Env:BHBuildNumber -Value $NewVersion

    $MonolithFile = "$env:BHProjectPath/$env:BHProjectName.nuspec"
    #Import the New PSD file
    $newString = Import-PowerShellDataFile $env:BHPSModuleManifest
    #Create a new file and Update each time.
    $xmlFile = New-Object xml
    $xmlFile.Load($MonolithFile)
    #Set the version to the one that is in the manifest.
    $xmlFile.package.metadata.version = $newString.ModuleVersion
    $xmlFile.Save($MonolithFile)

    #exec { git commit $manifest -m "Updated the module version" }

}

Task 'UpdateRepo' -Depends 'Init' {
    $lines
    Write-Output "Updating the repository`n"

    if ( ($env:BHCommitFlag -eq 0) -or (  (Test-Path -Path Env:BHCommitFlag) -eq $false   ) ) {
        $results = $false
    }
    else {
        $results = $true
    }
    Assert -conditionToCheck $results -failureMessage 'Please pass in a commit message. Build cannot continue!'

    #does my current build number match what I already pushed to git? If yes, don't tag
    $gittagversion = git tag --merged
    if ($gittagversion.Contains("v" + "$env:BHBuildNumber") ) {
        Exec { git add -u }
        Exec { git commit -m $env:BHCommitMessage }
        Exec { git push }
        Exec { git push origin $env:BHBranchName }
    }
    else {
        Exec { git add -u }
        Exec { git commit -m $env:BHCommitMessage }
        Exec { git push }
        Exec { git tag -a "v$env:BHBuildNumber" -m "v$env:BHBuildNumber" }
        Exec { git push origin $env:BHBranchName }
    }
}

Task 'BuildNuget' -Depends 'UpdateBuildVersion' {
    $lines
    Write-Output "Creating a Nuget Package in Aritfacts folder: [$ArtifactFolder]`n"

    exec { nuget pack "$env:BHProjectName.nuspec" -Version $env:BHBuildNumber }
    $newpackagename = $env:BHProjectName + "." + $env:BHBuildNumber + ".nupkg"
    Move-Item -Path $newpackagename -Destination $ArtifactFolder
    Set-Location -Path $Env:BHModulePath
}

# Create a versioned zip file of all staged files
# NOTE: Admin Rights are needed if you run this locally
Task 'BuildZip' -Depends 'Init' {
    $lines
    Write-Output "`nCreating a Build Artifact"

    # Create /Release folder
    New-Item -Path $ArtifactFolder -ItemType 'Directory' -Force | Out-String | Write-Verbose

    # Get current manifest version
    try {
        $manifest = Test-ModuleManifest -Path $StagingModuleManifestPath -ErrorAction 'Stop'
        [Version]$manifestVersion = $manifest.Version

    }
    catch {
        throw "Could not get manifest version from [$StagingModuleManifestPath]"
    }

    # Create zip file
    try {
        $releaseFilename = "$($env:BHProjectName)-v$($manifestVersion.ToString()).zip"
        $releasePath = Join-Path -Path $ArtifactFolder -ChildPath $releaseFilename
        Write-Host "Creating release artifact [$releasePath] using manifest version [$manifestVersion]" -ForegroundColor 'Yellow'
        Compress-Archive -Path "$StagingFolder/*" -DestinationPath $releasePath -Force -Verbose -ErrorAction 'Stop'
    }
    catch {
        throw "Could not create release artifact [$releasePath] using manifest version [$manifestVersion]"
    }

    Write-Output "`nFINISHED: Release artifact creation."
}

Task 'DeployAzure' -Depends 'Init' {
    $lines
    Write-Output "Deploying to Azure Repo"

    $patUser = $env:BHChefITAzureBuildUser
    $patToken = $env:BHChefITAzureBuildPassword
    $securePat = ConvertTo-SecureString -String $patToken -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($patUser, $securePat)

    Publish-Module  -Path $env:BHModulePath -Repository $env:BHPublishRepo -Credential $credential -Verbose
    #Do I need a NuGetAPIKey parameter here?
}

Task 'Sign' {
    $Lines
    Write-Output "Checking for Self-Signed Certs and Signing Your Code`n"

    if ($PSVersionTable.PSEdition -eq "Desktop") {

        $OSVer = Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object Version
        if ($OSVer.Version.StartsWith(10)){

            $ExistingCerts = Get-ChildItem -Path cert:\LocalMachine\My -Recurse -CodeSigningCert
            if (-not ($ExistingCerts)){
            # specific to Win 10 and Server 2019 and later
                New-SelfSignedCertificate -Type CodeSigningCert -Subject $env:BHProjectName | Out-Null
                $ExistingCerts = Get-ChildItem -Path Cert:\LocalMachine\My -CodeSigningCert
            }

            $publicFunctions = @( Get-ChildItem -Path "$env:BHModulePath\Public\*.ps1" -Recurse -ErrorAction 'SilentlyContinue' )
            foreach($function in $publicFunctions){
                Set-AuthenticodeSignature -FilePath $function -Certificate $ExistingCerts[0]
            }

        }

    }
    elseif ($PSVersionTable.PSEdition -eq "Core") {

        if (($isMACOS) -or ($isLinux)) {

            Write-Output "You are going to need to enter a password for your pfx file"

            # using this article as a reference - http://thecuriousgeek.org/2014/02/creating-openssl-code-signing-certs-on-windows/
            Exec {openssl genrsa -out $env:BHModulePath/Certs/ca.key 2048}
            Exec {openssl req -config $env:BHModulePath/Certs/openssl.cfg -new -x509 -days 1826 -key $env:BHModulePath/Certs/ca.key -out $env:BHModulePath/Certs/ca.crt}
            Exec {openssl genrsa -out $env:BHModulePath/Certs/codesign.key 2048} ## Can I delete this line?
            Exec {openssl req -config $env:BHModulePath/Certs/openssl.cfg -new -key $env:BHModulePath/Certs/codesign.key -reqexts v3_req -out $env:BHModulePath/Certs/codesign.csr}
            Exec {openssl x509 -req -days 1826 -in $env:BHModulePath/Certs/codesign.csr -CA $env:BHModulePath/Certs/ca.crt -CAkey $env:BHModulePath/Certs/ca.key -extfile $env:BHModulePath/Certs/openssl.cfg -set_serial 01 -out $env:BHModulePath/Certs/codesign.crt}
            Exec {openssl pkcs12 -export -out $env:BHModulePath/Certs/codesign.pfx -inkey $env:BHModulePath/Certs/codesign.key -in $env:BHModulePath/Certs/codesign.crt}
            $MyCertFromPfx = Get-PfxCertificate -FilePath $env:BHModulePath/Certs/codesign.pfx

            $publicFunctions = @( Get-ChildItem -Path "$env:BHModulePath\Public\*.ps1" -Recurse -ErrorAction 'SilentlyContinue' )
            foreach($function in $publicFunctions){
                Set-AuthenticodeSignature -FilePath $function -Certificate $MyCertFromPfx
            }

        }
        else {

            # If this is PS Core Running on Windows, what version is it? If Win10, great, here's something to try.
            if ($OSVer.Version.StartsWith(10)) {

                $ExistingCerts = Get-ChildItem -Path cert:\LocalMachine\My -Recurse -CodeSigningCert
                if (-not ($ExistingCerts)) {
                    # specific to Win 10 and Server 2019 and later
                    New-SelfSignedCertificate -Type CodeSigningCert -Subject $env:BHProjectName | Out-Null
                    $ExistingCerts = Get-ChildItem -Path Cert:\LocalMachine\My -CodeSigningCert
                }

                $publicFunctions = @( Get-ChildItem -Path "$env:BHModulePath\Public\*.ps1" -Recurse -ErrorAction 'SilentlyContinue' )
                foreach ($function in $publicFunctions) {
                    Set-AuthenticodeSignature -FilePath $function -Certificate $ExistingCerts[0]
                }

            }
            # If not win10, soorrrryyyyy
            else {
                Write-Output "Sorry, no soup for you - no cert options configured"
            }




        }
    }

}


#region NOT USED FOR THIS DEMO
# Task 'Release' -Depends 'Clean', 'Test', 'UpdateDocumentation', 'CombineFunctionsAndStage', 'CreateBuildArtifact' #'UpdateManifest', 'UpdateTag'
Task 'Build' -Depends 'Init' {
    $lines

    # Load the module, read the exported functions, update the psd1 FunctionsToExport
    Set-ModuleFunctions -Name $env:BHPSModuleManifest

    # Bump the module version
    try {
        $Version = Get-NextPSGalleryVersion -Name $env:BHProjectName -ErrorAction 'Stop'
        Update-Metadata -Path $env:BHPSModuleManifest -PropertyName 'ModuleVersion' -Value $Version -ErrorAction 'Stop'
    }
    catch {
        "Failed to update version for '$env:BHProjectName': $_.`nContinuing with existing version"
    }
}


Task 'DeployToPSGallery' -Depends 'Init' {
    $lines

    $Params = @{
        Path    = "$ProjectRoot"
        Force   = $true
        Recurse = $false
    }
    Invoke-PSDeploy @Verbose @Params
}
#endregion NOT USED FOR THIS DEMO
