<#
.SYNOPSIS
A module used to create new PS Modules with.

.DESCRIPTION
This module uses Plaster to create all the essential parts of a PowerShell Module. It runs on PSCore and all supported platforms.

.PARAMETER NewModuleName
The name you wish to give your new module

.PARAMETER BaseManifest
You are selecting from 3 Plaster manifests located in the /PlasterTemplate directory - Advanced is the best choice

.PARAMETER ModuleRoot
Where do you want your new module to live? The default is to put it in a /Modules folder off your drive root

.EXAMPLE
New-PSNowModule -NewModuleName "MyFabModule" -BaseManifest basic

Creates the new PS Module using the "basic" plaster mainfest which creates a minimal module for you

.EXAMPLE
New-PSNowModule -NewModuleName "MyFabModule" -BaseManifest Extended -ModuleRoot ~/modules/myfabmodule

This choice uses the Extended manifest and create the module in /modules. Note that the module and pathing work for all versions of PS Core and PS Windows - Linux and OSX are supported platforms

.EXAMPLE
New-PSNowModule -NewModuleName "MyFabModule" -BaseManifest Advanced -ModuleRoot c:\myfabmodule

This choice creates a fully fleshed out PowerShell module with full support for Pester, Git, PlatyPS and more. See the Advanced.xml file located in /PlasterTemplate

.NOTES
General Notes
#>
function New-PSNowModule {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$NewModuleName,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Basic", "Extended", "Advanced")]
        [string]$BaseManifest,

        [Parameter(Mandatory = $false)]
        [string]$ModuleRoot = ""
    )

    begin {
        $ErrorActionPreference = 'Stop'
    }

    process {

        $templateroot = $MyInvocation.MyCommand.Module.ModuleBase

        Set-Location $templateroot

        # check for old plastermanifest and delete it.
        if (Test-Path $templateroot\PlasterManifest.xml -PathType Leaf)
            {
                Remove-Item -Path PlasterManifest.xml
            }

        $plasterdoc = Get-ChildItem "$templateroot\PlasterTemplate" -Filter "$basemanifest.xml" | ForEach-Object { $_.FullName }

        Copy-Item -Path $plasterdoc "$templateroot\PlasterManifest.xml"

        if ($PSVersionTable.PSEdition -eq "Desktop") {

            if (!$moduleroot){
                $moduleroot = "c:\modules"
            }
            if (-not (Test-Path -path $moduleroot) ) {

                New-Item -Path "$moduleroot" -ItemType Directory
            }

            Set-Location $moduleroot
            $PathDivider = "\"

        }
        elseif ($PSVersionTable.PSEdition -eq "Core") {

            if (($isMACOS) -or ($isLinux)) {

                if (!$moduleroot) {
                    $moduleroot = "~/modules"
                }
                if (-not (Test-Path -path $moduleroot) ) {

                    New-Item -Path "$moduleroot" -ItemType Directory
                }

                Set-Location $ModuleRoot
                $PathDivider = "/"

            }
            else {

                if (!$moduleroot) {
                    $moduleroot = "c:\modules"
                }
                if (-not (Test-Path -path $moduleroot) ) {

                    New-Item -Path "$moduleroot" -ItemType Directory
                }

                Set-Location $moduleroot
                $PathDivider = "\"

            }
        }

        $PlasterParams = @{
            TemplatePath       = $templateroot #where the plaster manifest xml file lives
            Destination        = $moduleroot #where my new module is going to live
            ModuleName         = $NewModuleName
            #Description       = 'PowerShell Script Module Building Toolkit'
            #Version           = '1.0.0'
            ModuleAuthor       = '<Your Full Name Goes Here>'
            #CompanyName       = 'ACME Corp'
            #FunctionFolders   = 'public', 'private'
            #Git               = 'Yes'
            GitHubUserName	   = $env:BHGitHubUser
            #GitHubRepo        = 'ModuleBuildTools'
            #Options           = ('License', 'Readme', 'GitIgnore', 'GitAttributes')
            PowerShellVersion  = '3.0' #minimum PS version
            # Apart from Templatepath and Destination, these parameters need to match what's in the <parameters> section of the manifest.
        }

        Invoke-Plaster @PlasterParams -Force -Verbose

        $NewModuleName = $NewModuleName -replace '.ps1', ''

        $Path = "$moduleroot$PathDivider$NewModuleName"

        Write-Output "`nYour module was built at: [$Path]`n"

        if (-not (& Test-Path -Path $Path)) {
            New-Item -ItemType "file" -Path $templateroot -Name "currentmodules.txt" -Value $Path | Out-Null
            Add-Content -path $doc  -value $Path | Out-Null
        }
        else{
            $doc = "$templateroot$PathDivider" + "Currentmodules.txt"
            Add-Content -path $doc  -value $Path | Out-Null
        }

    }
    end{}
}

