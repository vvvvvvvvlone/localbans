#pragma semicolon 1
#pragma newdecls required

#define MAX_REASON_LENGTH 64

public Plugin myinfo =
{
	name = "LocalBans",
	author = "88",
	description = "Basic banning commands using database",
	version = "1.0",
	url = "http://steamcommunity.com/profiles/76561198195411193"
};

static const char DBName[] = "localbans";

Database  g_hDB;
StringMap g_hBanCache;
KeyValues g_hLocalBans;

int       g_iBanTargetUserId[MAXPLAYERS + 1];
int       g_iBanTime[MAXPLAYERS + 1];
bool      g_bWaitForTime[MAXPLAYERS + 1];
bool      g_bWaitForReason[MAXPLAYERS + 1];

enum BanCache
{
	String:Auth[32],
	String:Ip[16],
	BanTime,
	BanType,
	String:Name[MAX_NAME_LENGTH],
	Timestamp,
	String:Reason[MAX_REASON_LENGTH],
	String:AdminAuth[32],
	String:AdminName[MAX_NAME_LENGTH]
};

enum
{
	BAN_DEFAULT,
	BAN_STEAMID,
	BAN_IP
};

public void OnPluginStart()
{
	g_hBanCache  = new StringMap();
	g_hLocalBans = new KeyValues("localbans");
	
	DB_Connect();

	RegAdminCmd("sm_ban", SM_Ban, ADMFLAG_BAN, "sm_ban <#userid|name> <minutes|0> [reason]");
	RegAdminCmd("sm_addban", SM_AddBan, ADMFLAG_RCON, "sm_addban <steamid> <time> [reason]");
	RegAdminCmd("sm_banip", SM_BanIp, ADMFLAG_BAN, "sm_banip <ip> <time> [reason]");
	RegAdminCmd("sm_unban", SM_UnBan, ADMFLAG_UNBAN, "");
	RegAdminCmd("sm_bans", SM_Bans, ADMFLAG_BAN, "");
	RegAdminCmd("sm_banlist", SM_Bans, ADMFLAG_BAN, "");
	
	LoadTranslations("common.phrases");
}

public void OnConfigsExecuted()
{
	LoadLocalbansConfig();
}

public void OnClientDisconnect(int client)
{
	g_bWaitForTime[client] = false;
	g_bWaitForReason[client] = false;
}

public void OnClientPostAdminCheck(int client)
{
	SearchBan(client);
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if(g_bWaitForTime[client])
	{
		g_bWaitForTime[client] = false;
	}
	
	if(g_bWaitForReason[client])
	{
		g_bWaitForReason[client] = false;
	}
	
	return Plugin_Continue;
}

public Action SM_Ban(int client, int args)
{
	if(args < 2)
	{
		if(client == 0)
		{
			ReplyToCommand(client, "Usage: sm_ban <#userid|name> <minutes|0> [reason]");
		}
		else
		{
			OpenPlayersMenu(client);
		}
		
		return Plugin_Handled;
	}
	
	char sArg[MAX_REASON_LENGTH];
	
	int target;
	GetCmdArg(1, sArg, sizeof(sArg));
	if((target = FindTarget(client, sArg, true, true)) == -1)
	{
		ReplyToCommand(client, "Cannot find the target.");
		return Plugin_Handled;
	}
	
	int time;
	GetCmdArg(2, sArg, sizeof(sArg));
	if((time = StringToInt(sArg)) < 0)
	{
		ReplyToCommand(client, "Invalid ban time.");
		return Plugin_Handled;
	}
	
	GetCmdArg(3, sArg, sizeof(sArg));
	
	char sName[MAX_NAME_LENGTH], sName2[MAX_NAME_LENGTH], sAuth[32], sIp[16];
	GetClientName(target, sName, sizeof(sName));
	GetClientName(client, sName2, sizeof(sName2));
	GetClientAuthId(target, AuthId_Steam2, sAuth, sizeof(sAuth));
	GetClientIP(target, sIp, sizeof(sIp), true);

	int timestamp = GetTime();
	int bantime = time * 60;
	
	if(client == 0)
	{
		DB_CreateBan(sAuth, sIp, bantime, BAN_DEFAULT, sName, timestamp, sArg, "Console", sName2);
	}
	else
	{
		char sAuth2[32];
		GetClientAuthId(client, AuthId_Steam2, sAuth2, sizeof(sAuth2));
		
		DB_CreateBan(sAuth, sIp, bantime, BAN_DEFAULT, sName, timestamp, sArg, sAuth2, sName2);
	}

	AdvancedKickClient(target, sArg, sName2, time, timestamp + time);
	BanNotify(sArg, sName, time);

	return Plugin_Handled;
}

public Action SM_AddBan(int client, int args)
{
	if(args < 2)
	{
		ReplyToCommand(client, "Usage: sm_addban <steamid> <time> [reason]");
		return Plugin_Handled;
	}
	
	char sAuth[32], sTime[16], sReason[MAX_REASON_LENGTH];
	
	GetCmdArg(1, sAuth, sizeof(sAuth));
	if(StrContains(sAuth, "STEAM_") == -1)
	{
		ReplyToCommand(client, "Invalid SteamID format.");
		return Plugin_Handled;
	}
	
	int time;
	GetCmdArg(2, sTime, sizeof(sTime));
	if((time = StringToInt(sTime)) < 0)
	{
		ReplyToCommand(client, "Invalid ban time.");
		return Plugin_Handled;
	}
	
	GetCmdArg(3, sReason, sizeof(sReason));
	
	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, sizeof(sName));

	int timestamp = GetTime();
	int bantime = time * 60;
	
	if(client == 0)
	{
		DB_CreateBan(sAuth, "N/A", bantime, BAN_STEAMID, "N/A", timestamp, sReason, "Console", sName);
	}
	else
	{
		char sAuth2[32];
		GetClientAuthId(client, AuthId_Steam2, sAuth2, sizeof(sAuth2));
		
		DB_CreateBan(sAuth, "N/A", bantime, BAN_STEAMID, "N/A", timestamp, sReason, sAuth2, sName);
	}
	
	return Plugin_Handled;
}

public Action SM_BanIp(int client, int args)
{
	if(args < 2)
	{
		ReplyToCommand(client, "Usage: sm_banip <ip> <time> [reason]");
		return Plugin_Handled;
	}
	
	char sIp[16], sTime[16], sReason[MAX_REASON_LENGTH];
	
	GetCmdArg(1, sIp, sizeof(sIp));
	/*if() // добавить проверку валидности айпи адреса
	{
		ReplyToCommand(client, "Invalid IP format.");
		return Plugin_Handled;
	}*/

	int time;
	GetCmdArg(2, sTime, sizeof(sTime));
	if((time = StringToInt(sTime)) < 0)
	{
		ReplyToCommand(client, "Invalid ban time.");
		return Plugin_Handled;
	}
	
	GetCmdArg(3, sReason, sizeof(sReason));
	
	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, sizeof(sName));

	int timestamp = GetTime();
	int bantime = time * 60;
	
	if(client == 0)
	{
		DB_CreateBan("N/A", sIp, bantime, BAN_IP, "N/A", timestamp, sReason, "Console", sName);
	}
	else
	{
		char sAuth[32];
		GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth));
		
		DB_CreateBan("N/A", sIp, bantime, BAN_IP, "N/A", timestamp, sReason, sAuth, sName);
	}
	
	return Plugin_Handled;
}

public Action SM_UnBan(int client, int args)
{
	return Plugin_Handled;
}

public Action SM_Bans(int client, int args)
{
	return Plugin_Handled;
}

void OpenPlayersMenu(int client)
{
	Menu menu = new Menu(Menu_Players);
	menu.SetTitle("Ban player\n \n");
	
	char sName[MAX_NAME_LENGTH], sInfo[8];
	for(int target = 1; target <= MaxClients; target++)
	{
		if(IsClientInGame(target) && !IsFakeClient(target) && CanUserTarget(client, target))
		{
			GetClientName(target, sName, sizeof(sName));
			IntToString(GetClientUserId(target), sInfo, sizeof(sInfo));
			menu.AddItem(sInfo, sName);
		}
	}
	
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_Players(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[8];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
	
		g_iBanTargetUserId[client] = StringToInt(sInfo);
		OpenBanTimeMenu(client);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
	
	return 0;
}

void OpenBanTimeMenu(int client)
{
	Menu menu = new Menu(Menu_BanTimes);
	menu.SetTitle("Ban time\n \n");
	
	char timeName[32], time[16];
	
	g_hLocalBans.JumpToKey("bantimes");
	g_hLocalBans.GotoFirstSubKey(false);
	
	do
	{
		g_hLocalBans.GetSectionName(time, sizeof(time));
		g_hLocalBans.GetString(NULL_STRING, timeName, sizeof(timeName));
		
		menu.AddItem(time, timeName);
	}
	while(g_hLocalBans.GotoNextKey(false));
	
	g_hLocalBans.Rewind();

	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_BanTimes(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[16];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		g_iBanTime[client] = StringToInt(sInfo);
		OpenReasonMenu(client);
	}
	else if(action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
		{
			OpenPlayersMenu(client);
		}
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
	
	return 0;
}

void OpenReasonMenu(int client)
{
	Menu menu = new Menu(Menu_Reason);
	menu.SetTitle("Ban reason\n \n");

	char reasonName[MAX_REASON_LENGTH], reasonFull[MAX_REASON_LENGTH];
	
	g_hLocalBans.JumpToKey("banreasons");
	g_hLocalBans.GotoFirstSubKey(false);
	
	do
	{
		g_hLocalBans.GetSectionName(reasonFull, sizeof(reasonFull));
		g_hLocalBans.GetString(NULL_STRING, reasonName, sizeof(reasonName));
		
		menu.AddItem(reasonFull, reasonName);
	}
	while(g_hLocalBans.GotoNextKey(false));
	
	g_hLocalBans.Rewind();
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_Reason(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		int target = GetClientOfUserId(g_iBanTargetUserId[client]);
		
		if(target != 0)
		{
			int timestamp = GetTime();
			char sName[MAX_NAME_LENGTH], sName2[MAX_NAME_LENGTH], sAuth[32], sAuth2[32], sReason[MAX_REASON_LENGTH], sIp[16];
			
			menu.GetItem(param2, sReason, sizeof(sReason));
			GetClientName(target, sName, sizeof(sName));
			GetClientName(client, sName2, sizeof(sName2));
			GetClientAuthId(target, AuthId_Steam2, sAuth, sizeof(sAuth));
			GetClientAuthId(client, AuthId_Steam2, sAuth2, sizeof(sAuth2));
			GetClientIP(target, sIp, sizeof(sIp), true);
			
			DB_CreateBan(sAuth, sIp, g_iBanTime[client] * 60, BAN_DEFAULT, sName, timestamp, sReason, sAuth2, sName2);
			AdvancedKickClient(target, sReason, sName2, g_iBanTime[client], timestamp + g_iBanTime[client]);
			BanNotify(sReason, sName, g_iBanTime[client]);
		}
		else
		{
			ReplyToCommand(client, "The player you selected is no longer available.");
		}
	}
	else if(action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
		{
			OpenBanTimeMenu(client);
		}
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
	
	return 0;
}

void DB_Connect()
{
	char sError[128];
	g_hDB = SQLite_UseDatabase(DBName, sError, sizeof(sError));
	
	if(g_hDB == null)
	{
		SetFailState(sError);
		return;
	}
	
	DB_CreateTable();
	DB_LoadBans();
}

void DB_CreateTable()
{
	char sQuery[400];
	FormatEx(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `%s` (`Id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, `SteamId` VARCHAR(32) NOT NULL, `Ip` VARCHAR(16) NOT NULL, `BanTime` INTEGER NOT NULL, `BanType` INTEGER NOT NULL, `Name` VARCHAR(%d) NOT NULL, `Timestamp` INTEGER NOT NULL, `Reason` VARCHAR(%d) NOT NULL, `AdminId` VARCHAR(32) NOT NULL, `AdminName` VARCHAR(%d) NOT NULL);", 
		DBName,
		MAX_NAME_LENGTH,
		MAX_REASON_LENGTH,
		MAX_NAME_LENGTH); 

	g_hDB.Query(DB_CreateTable_Callback, sQuery);
}

public void DB_CreateTable_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("DB_CreateTable_Callback: %s", error);
	}
}

void DB_LoadBans()
{
	char sQuery[128];
	FormatEx(sQuery, sizeof(sQuery), "SELECT `SteamId`, `Ip`, `BanTime`, `BanType`, `Name`, `Timestamp`, `Reason`, `AdminId`, `AdminName` FROM `%s`;", DBName);
	
	g_hDB.Query(DB_LoadBans_Callback, sQuery);
}

public void DB_LoadBans_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results != null)
	{
		g_hBanCache.Clear();

		char sKey[16];
		any[] pack = new any[BanCache];
		
		while(results.FetchRow())
		{
			results.FetchString(0, pack[Auth], 32);
			results.FetchString(1, pack[Ip], 16);
			pack[BanTime] = results.FetchInt(2);
			pack[BanType] = results.FetchInt(3);
			results.FetchString(4, pack[Name], MAX_NAME_LENGTH);
			pack[Timestamp] = results.FetchInt(5);
			results.FetchString(6, pack[Reason], MAX_REASON_LENGTH);
			results.FetchString(7, pack[AdminAuth], 32);
			results.FetchString(8, pack[AdminName], MAX_NAME_LENGTH);
			
			IntToString(g_hBanCache.Size, sKey, sizeof(sKey));
			g_hBanCache.SetArray(sKey, pack, view_as<int>(BanCache));
		}
	}
	else
	{
		LogError("DB_LoadBans_Callback: %s", error);
	}
}

void DB_CreateBan(char[] steamid, char[] ip, int bantime, int bantype, char[] name, int timestamp, char[] reason, char[] adminid, char[] adminname)
{
	any[] pack = new any[BanCache];
	
	FormatEx(pack[Auth], 32, "%s", steamid);
	FormatEx(pack[Ip], 16, "%s", ip);
	pack[BanTime] = bantime;
	FormatEx(pack[Name], MAX_NAME_LENGTH, "%s", name);
	pack[Timestamp] = timestamp;
	FormatEx(pack[Reason], MAX_REASON_LENGTH, "%s", reason);
	FormatEx(pack[AdminAuth], 32, "%s", adminid);
	FormatEx(pack[AdminName], MAX_NAME_LENGTH, "%s", adminname);

	char sKey[16];
	IntToString(g_hBanCache.Size, sKey, sizeof(sKey));
	g_hBanCache.SetArray(sKey, pack, view_as<int>(BanCache));
	
	char sQuery[312];
	FormatEx(sQuery, sizeof(sQuery), "INSERT INTO %s (`SteamId`, `Ip`, `BanTime`, `BanType`, `Name`, `Timestamp`, `Reason`, `AdminId`, `AdminName`) VALUES ('%s', '%s', '%d', '%d', '%s', '%d', '%s', '%s', '%s');", 
		DBName,
		steamid,
		ip,
		bantime,
		bantype,
		name,
		timestamp,
		reason,
		adminid,
		adminname);
		
	g_hDB.Query(DB_CreateBan_Callback, sQuery);
}

public void DB_CreateBan_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("DB_CreateBan_Callback: %s", error);
	}
}

void LoadLocalbansConfig()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/localbans.cfg");
	
	if(!FileExists(sPath) && !FileExists(sPath, true))
	{
		SetFailState("%s not exists.", sPath);
		return;
	}

	if(g_hLocalBans.ImportFromFile(sPath))
	{
		if(!g_hLocalBans.JumpToKey("bantimes", false) || !g_hLocalBans.GotoFirstSubKey(false))
		{
			SetFailState("Error in %s: Couldn't find 'bantimes' or their stuff.", sPath);
			return;
		}

		g_hLocalBans.Rewind();
		
		if(!g_hLocalBans.JumpToKey("banreasons", false) || !g_hLocalBans.GotoFirstSubKey(false))
		{
			SetFailState("Error in %s: Couldn't find 'banreasons' or their stuff.", sPath);
			return;
		}
		
		g_hLocalBans.Rewind();
	}
	else
	{
		SetFailState("Something went wrong reading from the %s.", sPath);
		return;
	}
}

void SearchBan(int target) // сделать нормальную логику функции
{
	any[] pack = new any[BanCache];
	
	char sKey[16], sAuth[32], sAuth2[32], sIp[16], sIp2[16];
	GetClientAuthId(target, AuthId_Steam2, sAuth, sizeof(sAuth));
	GetClientIP(target, sIp, sizeof(sIp), true);
	
	for(int idx, size = g_hBanCache.Size; idx < size; idx++)
	{
		IntToString(idx, sKey, sizeof(sKey));
		g_hBanCache.GetArray(sKey, pack, view_as<int>(BanCache));
		
		FormatEx(sAuth2, sizeof(sAuth2), "%s", pack[Auth]);
		FormatEx(sIp2, sizeof(sIp2), "%s", pack[Ip]);
		
		int unbantime = pack[Timestamp] + pack[BanTime];

		if(pack[BanTime] != 0 && unbantime < GetTime())
		{
			continue;
		}
		
		switch(pack[BanType])
		{
			case BAN_DEFAULT:
			{
				g_hLocalBans.Rewind();
				int checkMode = g_hLocalBans.GetNum("check_mode");
				
				if((checkMode == 0 && StrEqual(sAuth, sAuth2))
				|| (checkMode == 1 && (StrEqual(sAuth, sAuth2) || StrEqual(sIp, sIp2))))
				{
					AdvancedKickClient(target, pack[Reason], pack[AdminName], pack[BanTime], unbantime);
					return;
				}
			}
			
			case BAN_STEAMID:
			{
				if(StrEqual(sAuth, sAuth2))
				{
					AdvancedKickClient(target, pack[Reason], pack[AdminName], pack[BanTime], unbantime);
					return;
				}
			}
			
			case BAN_IP:
			{
				if(StrEqual(sIp, sIp2))
				{
					AdvancedKickClient(target, pack[Reason], pack[AdminName], pack[BanTime], unbantime);
					return;
				}
			}
		}
	}
}

void AdvancedKickClient(int target, char[] reason, char[] name, int bantime, int unbantime)
{
	char sUnban[32];
	if(bantime == 0)
	{
		FormatEx(sUnban, sizeof(sUnban), "Permanent");
	}
	else
	{
		FormatTime(sUnban, sizeof(sUnban), "%x %X", unbantime);
	}
	
	KickClient(target, "You are banned from this server.\nReason: %s\nBanned by: %s\nUnban: %s", (strlen(reason) > 1)? reason:"N/A", name, sUnban);
}

void BanNotify(char[] reason, char[] name, int bantime)
{
	if(bantime == 0)
	{
		PrintToChatAll("Permanently banned player %s. (Reason: %s)", name, (strlen(reason) > 1)? reason:"N/A");
	}
	else
	{
		PrintToChatAll("Banned player %s for %d minutes. (Reason: %s)", name, bantime, (strlen(reason) > 1)? reason:"N/A");
	}
}

void LogAdminBan()
{
	
}