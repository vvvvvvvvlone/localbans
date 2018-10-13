#if defined _localbans_included
    #endinput
#endif
#define _localbans_included

enum BanCache
{
	String:Auth[32],
	String:Ip[16],
	Time,
	BanType:Type,
	String:Name[MAX_NAME_LENGTH],
	Timestamp,
	String:Reason[MAX_REASON_LENGTH],
	String:AdminAuth[32],
	String:AdminName[MAX_NAME_LENGTH]
};

/*
* Gets database handle.
*/
native Database LB_GetDatabase();

/*
* Gets bancache handle.
*/
native StringMap LB_GetBanCache();

/*
* Called when bans have been loaded from the database.
*
* @noreturn
*/
forward void LB_OnBansLoaded();

/*
* Called when a ban is created.
*
* @param auth      Client SteamID.
* @param ip        Client ip.
*
* @return          Plugin_Handled - stops the function.
*/
forward Action LB_OnBanCreated_Pre(const char[] auth, const char[] ip);

/*
* Called when the ban was created.
*
* @param auth      Client SteamID.
* @param ip        Client ip.
*
* @noreturn
*/
forward void LB_OnBanCreated_Post(const char[] auth, const char[] ip);

/*
* Called when a ban is removed.
*
* @param auth      Client SteamID or ip.
*
* @return          Plugin_Handled - stops the function.
*/
forward Action LB_OnBanRemoved_Pre(const char[] auth);

/*
* Called when the ban was created.
*
* @param auth      Client SteamID or ip.
*
* @noreturn
*/
forward void LB_OnBanRemoved_Post(const char[] auth);