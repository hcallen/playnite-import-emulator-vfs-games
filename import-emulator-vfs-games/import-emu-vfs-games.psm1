function GetMainMenuItems() {
    param($getMainMenuItemsArgs)

    Import-Module "$($CurrentExtensionInstallPath)/lib/import-emu-vfs-games-shared.ps1"
    

    $section = "@Import Emulator VFS Games"
    $supportedEmulators = @('RPCS3', 'Vita3k')

    $menuItems = @()

    foreach ($emu in $supportedEmulators) {
        $menuItem = New-Object Playnite.SDK.Plugins.ScriptMainMenuItem
        $menuItem.Description = $emu
        $menuItem.MenuSection = $section
        $menuItem.FunctionName = "Import-$($emu)VFSGames"
        $menuItems += $menuItem
    }

    return $menuItems
}

function Import-VFSGames() {
    param (
        [string]$EmulatorName
    )

    $emulator = Get-Emulator -EmulatorName $EmulatorName
    $platform = Get-Platform -Emulator $emulator

    $metaDataSearchPath = Get-MetaDataSearchPath -Emulator $emulator -Content (Get-ConfigContent -Emulator $emulator)
    $metaDataPaths = (Get-GameMetaDataDirPaths -Emulator $emulator -Path $metaDataSearchPath) | ForEach-Object { (Get-MetaDataFilePath  -Emulator $emulator -Path $_) }
    $metaDataTables = $metaDataPaths | ForEach-Object { ConvertTo-MetaDataTable -Emulator $emulator -Path $_ }
    $__logger.Info("Found $(($metaDataTables | Measure-Object).Count) game metadata files")

    $gamesAdded = ($metaDataTables | ForEach-Object { (Add-VFSGameToLibrary $emulator $platform $_) }) | Where-Object {$_ -eq $true}
    $__logger.Info("Added $(($gamesAdded | Measure-Object).Count) game(s)")

}

function Import-RPCS3VFSGames() {
    param($scriptMainMenuItemActionArgs)
    Import-VFSGames "RPCS3"

}

function Import-Vita3kVFSGames() {
    param($scriptMainMenuItemActionArgs)
    Import-VFSGames "Vita3k"
}