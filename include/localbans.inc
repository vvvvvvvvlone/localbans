#if defined _localbans_included
    #endinput
#endif
#define _localbans_included

#define MAX_REASON_LENGTH 128

enum BanType
{
	BAN_DEFAULT,   // Default ban (verifies the client's SteamID and IP(functionally, if enabled)).
	BAN_STEAMID,   // SteamID ban (verifies only the client's SteamID).
	BAN_IP,        // IP ban (verifies only the client's IP).
	BAN_NONE       // Used for unban.
};

enum BanCache
{
	String:Auth[32],                    // Client SteamID.
	String:Ip[16],                      // Client ip.
	Time,                               // Ban time.
	BanType:Type,                       // Ban type.
	String:Name[MAX_NAME_LENGTH],       // Client name.
	Timestamp,                          // Timestamp.
	String:Reason[MAX_REASON_LENGTH],   // Ban reason.
	String:AdminAuth[32],               // Admin SteamID.
	String:AdminName[MAX_NAME_LENGTH]   // Admin name.
};

/*
* Formats:
* 
* IP-adress         IPv4.
* SteamID           STEAM_X:Y:Z.
*/

/*
* Gets database handle.
*/
native Database LB_GetDatabase();

/*
* Gets bancache handle (use enum BanCache to get array).
*/
native StringMap LB_GetBanCache();

/*
* Creates a ban.
*
* @param auth        Client SteamID.
* @param ip          Client IP.
* @param time        Ban time.
* @param type        Ban type (enum BanType).
* @param name        Client name.
* @param timestamp   Timestamp, SourceMod function - GetTime() (https://sm.alliedmods.net/new-api/sourcemod/GetTime).
* @param reason      Ban reason.
* @param adminAuth   SteamID of the admin who issued the ban.
* @param adminName   Name of the admin who issued the ban.
*
* @noreturn
*/
native void LB_CreateBan(const char[] auth = "N/A", const char[] ip = "N/A", int time, BanType type, const char[] name = "N/A", int timestamp, const char[] reason = "N/A", const char[] adminAuth, const char[] adminName);

/*
* Removes a ban.
*
* @param auth        Client SteamID or IP.
*
* @noreturn
*/
native void LB_RemoveBan(const char[] auth);

/*
* Called when bans have been loaded from the database.
*
* @noreturn
*/
forward void LB_OnBansLoaded();

/*
* Called when a ban is created.
*
* @param auth        Client SteamID.
* @param ip          Client IP.
*
* @return            Plugin_Handled - stops the function.
*/
forward Action LB_OnBanCreated_Pre(const char[] auth, const char[] ip);

/*
* Called when the ban was created.
*
* @param auth        Client SteamID.
* @param ip          Client IP.
*
* @noreturn
*/
forward void LB_OnBanCreated_Post(const char[] auth, const char[] ip);

/*
* Called when a ban is removed.
*
* @param auth        Client SteamID or IP.
*
* @return            Plugin_Handled - stops the function.
*/
forward Action LB_OnBanRemoved_Pre(const char[] auth);

/*
* Called when the ban was created.
*
* @param auth        Client SteamID or IP.
*
* @noreturn
*/
forward void LB_OnBanRemoved_Post(const char[] auth);