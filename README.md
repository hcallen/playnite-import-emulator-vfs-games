# Import Emulator VFS (Virtual File System) Games
Extension for [Playnite](https://playnite.link/) to import games installed to an emulator's VFS.
*Currently only supports RPCS3 and Vita3k.*

**Notes**

* The target emulator must be configured in Playnite.
* The first Emulator found configured in Playnite for the target emulator is used for import configuration.
* The target emulator configuration file(s) are parsed to determine the VFS path.
* For RPCS3 & Vita3k, the game's [PARAM.SFO]((https://www.psdevwiki.com/ps3/PARAM.SFO)) file is used to define the game's metadata.
* A game will not be imported if the Game ID is already exists in the Playnite database or if there a Game Action's Arguments that contain the Game ID.

## Installation
Download and open the most recent Playnite Extension (.pext) file from [Releases](https://github.com/hcallen/playnite-import-emulator-vfs-games/releases).

## Usage

Select the target emulator from "Import Emulator VFS Games" sub-menu; found in the main menu, under the "Extensions" sub-menu (only available in Desktop mode).