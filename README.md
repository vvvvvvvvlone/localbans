# h1 localbans:
Simple banning plugin for CS:GO using database.
Plugin has a configuration file - localbans.cfg.
The same way you can follow the admins actions. (addons\sourcemod\logs\localbans.txt)

## h4 Commands:

##### h5 sm_ban:

Usage: sm_ban <#userid|name> <minutes|0> [reason] (ADMFLAG_BAN for acces)
Example: sm_ban Nickname 60 abusive
Note: use sm_ban without arguments to open ingame menu.

##### h5 sm_addban:

Usage: sm_addban <steamid> <time> [reason] (ADMFLAG_RCON for acces)
Example: sm_addban STEAM_1:1:117572732 60 wh
  
##### h5 sm_banip: 

Usage: sm_banip <ip> <time> [reason] (ADMFLAG_RCON for acces)
Example: sm_banip 156.241.54.24 60 aimbot

##### h5 sm_unban:

Usage: sm_unban <steamid|ip> (ADMFLAG_UNBAN for acces)
Example: sm_unban STEAM_1:1:117572732

##### h5 sm_searchban:

Usage: sm_searchban <steamid|ip> (ADMFLAG_UNBAN for acces)
Example: sm_searchban STEAM_1:1:117572732

##### h5 sm_bans/sm_banlist: Opens banlist menu. (ADMFLAG_UNBAN for acces)

##### h5 Also plugin has an extensive API. (localbans.inc)

# h2 Requirements:
SourceMod 1.7 or above

# h2 Install
1. Compile source.
2. Add plugin to 'plugins' folder. (addons\sourcemod\plugins)
3. Add localbans.cfg to 'confgis' folder. (addons\sourcemod\configs)
4. Add localbans folder to 'logs' folder. (addons\sourcemod\logs)
