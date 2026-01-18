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

    $gameInstallationSearchPath = Get-GameInstallationSearchPath -Emulator $emulator -Content (Get-ConfigContent -Emulator $emulator)
    $gameInstallationPaths = (Get-GameInstallationPaths -Emulator $emulator -Path $gameInstallationSearchPath)
    $__logger.Info("Found $(($gameInstallationPaths | Measure-Object).Count) game installations")

    $gamesAdded = ($gameInstallationPaths | ForEach-Object { (Add-VFSGameToLibrary $emulator $platform $_) }) | Where-Object {$_ -eq $true}
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