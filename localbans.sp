#pragma semicolon 1
#pragma newdecls required

#define MAX_REASON_LENGTH  64
#define MAX_STEAMID_LENGTH 32

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

enum BanCache
{
	BanTime,
	String:Name[MAX_NAME_LENGTH],
	Timestamp,
	String:Reason[MAX_REASON_LENGTH],
	String:AdminSteamId[MAX_STEAMID_LENGTH],
	String:AdminName[MAX_NAME_LENGTH]
};

public void OnPluginStart()
{
	g_hBanCache  = new StringMap();
	g_hLocalBans = new KeyValues("localbans");
	
	DB_Connect();

	RegAdminCmd("sm_ban", SM_Ban, ADMFLAG_BAN, "sm_ban <#userid|name> <minutes|0> [reason]");
	RegAdminCmd("sm_addban", SM_AddBan, ADMFLAG_RCON, "");
	RegAdminCmd("sm_unban", SM_UnBan, ADMFLAG_UNBAN, "");
	RegAdminCmd("sm_bans", SM_Bans, ADMFLAG_BAN, "");
	RegAdminCmd("sm_banlist", SM_Bans, ADMFLAG_RCON, "");
}

public void OnConfigsExecuted()
{
	LoadLocalbansConfig();
}

public void OnClientAuthorized(int client, const char[] auth)
{
	any[] pack = new any[BanCache];
	
	if(g_hBanCache.GetArray(auth, pack, view_as<int>(BanCache)))
	{
		int unbantime = pack[Timestamp] + pack[BanTime];
		
		if(pack[BanTime] == 0 || unbantime > GetTime())
		{
			AdvancedKickClient(client, pack[Reason], pack[AdminName], pack[BanTime], unbantime);
		}
	}
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
	
	char sArg[32 + MAX_REASON_LENGTH];
	GetCmdArgString(sArg, sizeof(sArg));
	
	int target, len;
	char sTarget[16];
	len = BreakString(sArg, sTarget, sizeof(sTarget));

	if((target = FindTarget(client, sTarget, true)) == -1)
	{
		ReplyToCommand(client, "Cannot find the target.");
		return Plugin_Handled;
	}
	
	int time, nextlen;
	char sTime[16];
	if((nextlen = BreakString(sArg[len], sTime, sizeof(sTime))) != -1)
	{
		len += nextlen;
	}
	else
	{
		len = 0;
		sArg[0] = '\0';
	}

	if((time = StringToInt(sTime)) < 0)
	{
		ReplyToCommand(client, "Invalid ban time.");
		return Plugin_Handled;
	}
	
	char sName[MAX_NAME_LENGTH], sName2[MAX_NAME_LENGTH], sAuth[MAX_STEAMID_LENGTH];
	
	GetClientName(target, sName, sizeof(sName));
	GetClientName(client, sName2, sizeof(sName2));
	GetClientAuthId(target, AuthId_Steam2, sAuth, sizeof(sAuth));

	int timestamp = GetTime();
	int bantime = time * 60;
	
	if(client == 0)
	{
		DB_CreateBan(sAuth, bantime, sName, timestamp, sArg[len], "Console", sName2);
	}
	else
	{
		char sAuth2[MAX_STEAMID_LENGTH];
		GetClientAuthId(client, AuthId_Steam2, sAuth2, sizeof(sAuth2));
		
		DB_CreateBan(sAuth, bantime, sName, timestamp, sArg[len], sAuth2, sName2);
	}

	AdvancedKickClient(target, sArg[len], sName2, time, timestamp + time);
	BanNotify(sArg[len], sName, time);

	return Plugin_Handled;
}

void OpenPlayersMenu(int client)
{
	Menu menu = new Menu(Menu_Players);
	menu.SetTitle("Ban player\n \n");
	
	char sName[MAX_NAME_LENGTH], sInfo[8];
	for(int target = 1; target <= MaxClients; target++)
	{
		if(IsClientInGame(target) && !IsFakeClient(target))
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
			char sName[MAX_NAME_LENGTH], sName2[MAX_NAME_LENGTH], sAuth[MAX_STEAMID_LENGTH], sAuth2[MAX_STEAMID_LENGTH], sReason[MAX_REASON_LENGTH];
			
			menu.GetItem(param2, sReason, sizeof(sReason));
			GetClientName(target, sName, sizeof(sName));
			GetClientName(client, sName2, sizeof(sName2));
			GetClientAuthId(target, AuthId_Steam2, sAuth, sizeof(sAuth));
			GetClientAuthId(client, AuthId_Steam2, sAuth2, sizeof(sAuth2));
			
			DB_CreateBan(sAuth, g_iBanTime[client] * 60, sName, timestamp, sReason, sAuth2, sName2);
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

public Action SM_AddBan(int client, int args)
{
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
	char sQuery[312];
	FormatEx(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `%s` (`SteamId` VARCHAR(%d) NOT NULL PRIMARY KEY, `BanTime` INTEGER NOT NULL, `Name` VARCHAR(%d) NOT NULL, `Timestamp` INTEGER NOT NULL, `Reason` VARCHAR(%d) NOT NULL, `AdminId` VARCHAR(%d) NOT NULL, `AdminName` VARCHAR(%d) NOT NULL);", 
		DBName,
		MAX_STEAMID_LENGTH,
		MAX_NAME_LENGTH,
		MAX_REASON_LENGTH,
		MAX_STEAMID_LENGTH,
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
	FormatEx(sQuery, sizeof(sQuery), "SELECT `SteamId`, `BanTime`, `Name`, `Timestamp`, `Reason`, `AdminId`, `AdminName` FROM `%s`;", DBName);
	
	g_hDB.Query(DB_LoadBans_Callback, sQuery);
}

public void DB_LoadBans_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results != null)
	{
		g_hBanCache.Clear();
		
		char sSteamId[MAX_STEAMID_LENGTH];
		any[] pack = new any[BanCache];
		
		while(results.FetchRow())
		{
			results.FetchString(0, sSteamId, sizeof(sSteamId));
		
			pack[BanTime] = results.FetchInt(1);
			results.FetchString(2, pack[Name], MAX_NAME_LENGTH);
			pack[Timestamp] = results.FetchInt(3);
			results.FetchString(4, pack[Reason], MAX_REASON_LENGTH);
			results.FetchString(5, pack[AdminSteamId], MAX_STEAMID_LENGTH);
			results.FetchString(6, pack[AdminName], MAX_NAME_LENGTH);
			
			g_hBanCache.SetArray(sSteamId, pack, view_as<int>(BanCache));
		}
	}
	else
	{
		LogError("DB_LoadBans_Callback: %s", error);
	}
}

void DB_CreateBan(char[] steamid, int bantime, char[] name, int timestamp, char[] reason, char[] adminid, char[] adminname)
{
	any[] pack = new any[BanCache];
	
	pack[BanTime] = bantime;
	FormatEx(pack[Name], MAX_NAME_LENGTH, "%s", name);
	pack[Timestamp] = timestamp;
	FormatEx(pack[Reason], MAX_REASON_LENGTH, "%s", reason);
	FormatEx(pack[AdminSteamId], MAX_STEAMID_LENGTH, "%s", adminid);
	FormatEx(pack[AdminName], MAX_NAME_LENGTH, "%s", adminname);
	
	g_hBanCache.SetArray(steamid, pack, view_as<int>(BanCache));
	
	char sQuery[312];
	FormatEx(sQuery, sizeof(sQuery), "INSERT INTO %s (`SteamId`, `BanTime`, `Name`, `Timestamp`, `Reason`, `AdminId`, `AdminName`) VALUES ('%s', '%d', '%s', '%d', '%s', '%s', '%s');", 
		DBName,
		steamid,
		bantime,
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
		if(g_hLocalBans.JumpToKey("bantimes") == false || g_hLocalBans.JumpToKey("banreasons") == false)
		{
			SetFailState("wtf wtf wtf wtf wtf wtf wtf wtf wtf wtf");
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