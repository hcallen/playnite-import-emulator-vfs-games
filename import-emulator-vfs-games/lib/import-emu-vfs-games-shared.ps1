<# 
Get the content of emulator configuration file.
#>
function Get-ConfigContent() {
    param (
        [System.Object]$Emulator
    )

    if ($Emulator -is [String]) {
        $Emulator = Get-Emulator $Emulator
    }

    $configPath = switch ($Emulator.BuiltInConfigId) {
        "rpcs3" { [IO.Path]::Combine($Emulator.InstallDir, 'config', 'vfs.yml') }
        "vita3k" { [IO.Path]::Combine($Emulator.InstallDir, 'config.yml') }
    }
    
    $__logger.Trace("Get-ConfigContent - configPath=$($configPath)")

    $configContent = (Get-Content -Path $configPath | Out-String)
    $__logger.Trace("Get-ConfigContent - configContent=$($configContent)")

    return $configContent
    
}

function Get-GameInstallationSearchPath() {
    param (
        [Parameter(Mandatory, Position = 0)][System.Object]$Emulator,
        [Parameter(Mandatory, Position = 1)][string]$Content
    )

    if ($Emulator -is [String]) {
        $Emulator = Get-Emulator $Emulator
    }

    $searchPath = switch ($Emulator.BuiltInConfigId) {
        "rpcs3" {
            $emuPathRegex = "\$\(EmulatorDir\):\s?""(?<emuPath>.*)"""
            $Content -match $emuPathRegex | Out-Null
            $emuPath = $matches["emuPath"].Trim()
            $hddRegex = "/dev_hdd0/:(?<hddPath>.*)`n"
            $Content -match $hddRegex | Out-Null
            $hddPath = $matches["hddPath"].Trim().TrimEnd('/', '\')
            
            if (-not $emuPath) {
                $emuPath = $Emulator.InstallDir
            }

            if ($hddPath.Contains('$(EmulatorDir)')) {
                $hddPath = $hddPath.replace('$(EmulatorDir)', "$($emuPath)\")
            }
            [IO.Path]::Combine($hddPath, 'game')
        }
        "vita3k" { 
            $regex = "pref-path:(?<pathMatch>.*)`n"
            $Content -match $regex | Out-Null
            $pathMatch = $matches["pathMatch"].Trim()
            [IO.Path]::Combine($pathMatch, 'ux0', 'app')
        }
    }

    If (-not (Test-Path $searchPath)) {
        $__logger.Error("Invalid search path: $searchPath")
        $PlayniteApi.Dialogs.ShowErrorMessage("Invalid search path: $searchPath", "Error");
        Exit
    }

    $__logger.Trace("Get-GameInstallationSearchPath - searchPath=$($searchPath)")
    return $searchPath
}

function Get-GameInstallationPaths {
    param (
        [Parameter(Mandatory, Position = 0)][System.Object]$Emulator,
        [Parameter(Mandatory, Position = 1)][string][string]$Path
    )

    if ($Emulator -is [String]) {
        $Emulator = Get-Emulator $Emulator
    }

    $dataDirs = switch ($Emulator.BuiltInConfigId) {
        "rpcs3" { (Get-Childitem -Path $($Path) | Where-Object { ($_.PSIsContainer -eq $true) -and ($_.Name.StartsWith("NP")) } ) }
        "vita3k" { (Get-Childitem -Path $($Path) | Where-Object { ($_.PSIsContainer -eq $true) -and ($_.Name.StartsWith("PCS")) } ) }
    }

    $dataDirs = ($dataDirs | ForEach-Object { $_.FullName })

    $__logger.Trace("Get-GameInstallationPaths - dataDirs.Count=$(($dataDirs | Measure-Object).Count)")
    return $dataDirs
}

function Get-MetaDataFilePath {
    param (
        [Parameter(Mandatory, Position = 0)][System.Object]$Emulator,
        [Parameter(Mandatory, Position = 1)][string[]]$Path
    )

    if ($Emulator -is [String]) {
        $Emulator = Get-Emulator $Emulator
    }
    
    $filePath = switch ($Emulator.BuiltInConfigId) {
        "rpcs3" {
            If (Test-Path ([IO.Path]::Combine($Path, 'C00', 'PARAM.SFO') )) {
                [IO.Path]::Combine($Path, 'C00', 'PARAM.SFO')
            }
            elseif (Test-Path ([IO.Path]::Combine($Path, 'PARAM.SFO'))) {
                [IO.Path]::Combine($Path, 'PARAM.SFO')
            }
            else {
                $null
            }
        } 
        "vita3k" {
            If (Test-Path ([IO.Path]::Combine($Path, 'sce_sys', 'param.sfo') )) {
                [IO.Path]::Combine($Path, 'sce_sys', 'param.sfo')
            }
            else {
                $null
            }
        }
    }

    $__logger.Trace("Get-MetaDataFilePath - filePath=$($filePath)")

    return $filePath
}

function ConvertTo-MetaDataTable() {
    param (
        [Parameter(Mandatory, Position = 0)][System.Object]$Emulator,
        [Parameter(Position = 1)][string]$Path
    )

    if ($Emulator -is [String]) {
        $Emulator = Get-Emulator $Emulator
    }

    if (-not $Path) {
        Return
    }

    $data = [System.IO.File]::ReadAllBytes($Path)
    
    $metaDataTable = switch ($Emulator.BuiltInConfigId) {
        "rpcs3" { $(ConvertTo-ParamTable $data) }
        "vita3k" { $(ConvertTo-ParamTable $data) }
    }
    return $metaDataTable
}

function Get-Platform() {
    param (
        [System.Object]$Emulator
    )

    if ($Emulator -is [String]) {
        $Emulator = Get-Emulator $Emulator
    }

    $platformName = switch ($Emulator.BuiltInConfigId) {
        "rpcs3" { "Sony Playstation 3" }
        "vita3k" { "Sony Playstation Vita" }
    }
    $platform = $PlayniteApi.Database.Platforms | Where-Object { $_.Name -eq $platformName }
    $__logger.Trace("Get-Platform - platform=$($platform)")
    return $platform
}

function Get-Emulator() {
    param (
        [string]$EmulatorName
    )
    
    $emulator = ($PlayniteApi.Database.Emulators | Where-Object { $_.BuiltInConfigId -eq $EmulatorName.ToLower() }) | Select-Object -First 1
    $__logger.Trace("Get-Emulator - emulator.BuiltInConfigId=$($emulator.BuiltInConfigId)")

    If (-not $Emulator) {
        $__logger.Error("Unable to locate $EmulatorName")
        $PlayniteApi.Dialogs.ShowErrorMessage("Unable to locate $EmulatorName", "Error");
        Exit
    }

    $__logger.Trace("Get-Emulator - emulator=$($emulator)")
    
    return $emulator

}

function Get-IsGameDuplicate {
    param (
        [Playnite.SDK.Models.Emulator]$Emulator,
        [Playnite.SDK.Models.Game]$NewGame
    )

    if ((($PlayniteApi.Database.Games | Where-Object { $_.GameId -eq $NewGame.GameId }) | Measure-Object).Count -ge 1) {
        $isDuplicate = $true
    }
    elseif ((($PlayniteApi.Database.Games.GameActions | Where-Object { $_.Arguments -like "*$($NewGame.GameId)*" }) | Measure-Object).Count -ge 1) {
        $isDuplicate = $true
    }
    else {
        $isDuplicate = $false
    }

    $__logger.Trace("Get-IsGameDuplicate - isDuplicate=$($isDuplicate)")
    return $isDuplicate
}

function Get-IsGameValid {
    param (
        [Playnite.SDK.Models.Emulator]$Emulator,
        [Playnite.SDK.Models.Game]$NewGame,
        [hashtable] $GameMetadata
    )

    $isValid = switch ($Emulator.BuiltInConfigId) {
        "rpcs3" { ($NewGame.GameId.StartsWith("NP")) -and ($GameMetadata.CATEGORY -eq 'HG') }
        "vita3k" { $NewGame.GameId.StartsWith("PCS") }
    }

    $__logger.Trace("Get-IsGameValid - isValid=$($isValid)")
    return $isValid

    
}

function Get-GameRegionId {
    param (
        [Playnite.SDK.Models.Emulator]$Emulator,
        [hashtable] $GameMetadata
    )

    $regionName = switch ($Emulator.BuiltInConfigId) {
        "rpcs3" {
            switch ($GameMetadata.TITLE_ID[2]) {
                'A' { 'Asia' }
                'E' { 'Europe' }
                'H' { 'Hong Kong' }
                'J' { 'Japan' }
                'K' { 'Korea' }
                'U' { 'USA' }
                Default { $null }
            }
        }
        "vita3k" {
            switch ($GameMetadata.TITLE_ID[3]) {
                'A' { 'USA' }
                'B' { 'Europe' }
                'C' { 'Japan' }
                'D' { 'Asia' }
                'E' { 'USA' }
                'F' { 'Europe' }
                'G' { 'Japan' }
                'H' { 'Asia' }
                Default { $null }
            } 
        }
    }

    $__logger.Trace("Get-GameRegionId - regionName=$($regionName)")

    $regionId = ($PlayniteApi.Database.Regions | Where-Object { $_.Name -eq $regionName } | Select-Object -First 1).Id
    if (-not $regionId) {
        $newRegion = New-Object 'Playnite.SDK.Models.Region'
        $newRegion.Name = $regionName
        $newRegion.SpecificationId = $regionName.ToLower()
        $PlayniteApi.Database.Regions.Add($newRegion)
        $__logger.Trace("Get-GameRegionId - newRegion.Name=$($newRegion.Name)")
        $regionId = ($PlayniteApi.Database.Regions | Where-Object { $_.Name -eq $regionName } | Select-Object -First 1).Id
    }

    $__logger.Trace("Get-GameRegionId - regionId=$($regionId)")

    return $regionId
}

function Add-VFSGameToLibrary() {
    param (
        [Playnite.SDK.Models.Emulator]$Emulator,
        [Playnite.SDK.Models.Platform]$Platform,
        [string[]]$GameInstallPath
    )

    $gameMetadataPath = Get-MetaDataFilePath $Emulator $GameInstallPath
    $gameMetaData = ConvertTo-MetaDataTable $Emulator $gameMetadataPath

    $newGame = New-Object "Playnite.SDK.Models.Game"
    $newGame.InstallDirectory = $GameInstallPath
    $newGame.GameId = switch ($Emulator.BuiltInConfigId) {
        "rpcs3" { $gameMetaData.TITLE_ID }
        "vita3k" { $gameMetaData.TITLE_ID }
    }
    $newGame.Name = switch ($Emulator.BuiltInConfigId) {
        "rpcs3" { $gameMetaData.TITLE }
        "vita3k" { $gameMetaData.TITLE }
    }
    $newGame.Name = ($newGame.Name -creplace '\P{IsBasicLatin}').replace("`n", " ")
    $newGame.PlatformIds = $Platform.Id
    $newGame.IsInstalled = $true
    $newGame.RegionIds = Get-GameRegionId $Emulator $gameMetaData

    $newAction = New-Object "Playnite.SDK.Models.GameAction"
    $newAction.Type = "Emulator"
    $newAction.Name = $newGame.Name
    $newAction.IsPlayAction = $true
    $newAction.OverrideDefaultArgs = $true
    $newAction.Arguments = switch ($Emulator.BuiltInConfigId) {
        "rpcs3" { " --no-gui `"%RPCS3_GAMEID%:$($newGame.GameId)`"" }
        "vita3k" { " -r $($newGame.GameId)" }
    }
    $newAction.EmulatorId = $Emulator.Id
    $newAction.EmulatorProfileId = ($Emulator.AllProfiles | Select-Object -First 1).Id
    $newGame.GameActions = $newAction


    If ((Get-IsGameValid $emulator $newGame $gameMetaData) -and (-not (Get-IsGameDuplicate $emulator $newGame))) {
        $PlayniteApi.Database.Games.Add($newGame)
        $__logger.Info("Added game: $($newGame.Name)")
        return $true
    }
    Else {
        $__logger.Info("Skipped game: $($newGame.Name)")
        return $false
    }

}

function ConvertTo-ParamTable {
    param (
        [Parameter(Position = 0)][byte[]] $Data
    )

    $keyTableStart = [bitconverter]::ToInt32($Data[0x08..0x0B], 0) 
    $dataTableStart = [bitconverter]::ToInt32($Data[0x0C..0x0F], 0)
    $tableEntries = [bitconverter]::ToInt32($Data[0x10..0x14], 0)
    # $indexTable = $Data[0x14..($keyTableStart - 1)]
    $keyTable = [System.Text.Encoding]::UTF8.GetString($Data[$keyTableStart..($dataTableStart - 1)]).Replace("`0", "|").Trim("|").Split("|")
    $dataTable = $Data[$dataTableStart..($Data.Length - 1)]

    $__logger.Trace("ConvertTo-ParamTable - keyTableStart=$($keyTableStart)")
    $__logger.Trace("ConvertTo-ParamTable - dataTableStart=$($dataTableStart)")
    $__logger.Trace("ConvertTo-ParamTable - tableEntries=$($tableEntries)")
    $__logger.Trace("ConvertTo-ParamTable - keyTable=$($keyTable)")

    $paramHash = [hashtable]::new()

    for ($i = 0; $i -lt $tableEntries; $i++) {
        
        $indexTableEntry = $Data[$(0x14 + (16 * $i))..((0x14 + (16 * $i)) + 15)]
        $key = $keyTable[$i]
        $dataFmt = [bitconverter]::ToInt16($indexTableEntry[0x02..0x03], 0)
        $dataLen = [bitconverter]::ToInt32($indexTableEntry[0x04..0x07], 0)
        $dataOffset = [bitconverter]::ToInt32($indexTableEntry[0x0C..0x0F], 0)
        $valueData = $dataTable[$dataOffset..(($dataOffset + $dataLen) - 1)]

        $__logger.Trace("ConvertTo-ParamTable - i=$($i)")
        $__logger.Trace("ConvertTo-ParamTable - indexTableEntry=$($indexTableEntry)")
        $__logger.Trace("ConvertTo-ParamTable - dataFmt=$($dataFmt)")
        $__logger.Trace("ConvertTo-ParamTable - dataLen=$($dataLen)")
        $__logger.Trace("ConvertTo-ParamTable - dataOffset=$($dataOffset)")
        $__logger.Trace("ConvertTo-ParamTable - valueData=$($valueData)")

        # UTF8-S or UTF8
        if (@(0x0004, 0x0204) -contains $dataFmt) {
            $value = [System.Text.Encoding]::UTF8.GetString($valueData).Trim("`0")
        } 
        # Int32
        elseif ($dataFmt -eq 0x0404) {
            $value = [bitconverter]::ToInt32($valueData, 0)
        } 
        else {
            $__logger.Warn("Invalid data format: $($dataFmt)")
            $value = $dataFmt
        }

        $__logger.Trace("ConvertTo-ParamTable - key=$($key)")
        $__logger.Trace("ConvertTo-ParamTable - value=$($value)")

        $paramHash[$key] = $value

    }

    $__logger.Trace("ConvertTo-ParamTable - paramHash=@($($($paramHash.GetEnumerator() | ForEach-Object {"{0}={1}" -f $_.Name,($_.Value)}) -join ","))".replace("`n", ""))

    return  $paramHash
}