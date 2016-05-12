#pragma semicolon 1
#include <colors> 
#include <geoip> 
#include <basecomm>
#include <cstrike>
#include <autoexec>
#pragma newdecls required

#define CVARS FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY
#define DEFAULT_FLAGS FCVAR_PLUGIN|FCVAR_NOTIFY
#define PL_VERSION "0.01"

float g_fLastChatMsg[MAXPLAYERS + 1];

Handle h_cvar_clantag;
Handle h_cvar_chattag;

bool b_cvar_clantag = false;
bool b_cvar_chattag = false;

public Plugin myinfo =
{
	name = "Country Tag",
	author = "Hejter",
	description = "Add in chat and in scoreboard country tag.",
	version = PL_VERSION,
	url = "https://github.com/Heyter/CountryTag",
};

public void OnPluginStart()
{
	AddCommandListener(ChatSay, "say");
	AddCommandListener(ChatSay, "say_team");
	
	HookEvent("player_spawn", PlySpawn, EventHookMode_Post);
	
	LoadTranslations("country_tag.phrases");
	AutoExecConfig_SetFile("country_tag", "sourcemod/country_tag");
	
	AutoExecConfig_CreateConVar("country_tag_version", PL_VERSION, "Version", CVARS);
	h_cvar_clantag = AutoExecConfig_CreateConVar("country_ClanTag", "1", "Enable/Disable clan tag", DEFAULT_FLAGS, true, 0.0, true, 1.0);
	h_cvar_chattag = AutoExecConfig_CreateConVar("country_ChatTag", "1", "Enable/Disable chat tag", DEFAULT_FLAGS, true, 0.0, true, 1.0);
	
	HookEventsCvars();
	AutoExecConfig_ExecuteFile();
}

public Action ChatSay(int client, const char[] command, int args)
{
	if (b_cvar_chattag)
	{
		if (IsValidClient(client))
		{
			if (BaseComm_IsClientGagged(client))
			{
				PrintToChat(client, "%t", "MUTE");
				return Plugin_Handled;
			}
			
			char ip[14];
			char tag[3];
			char text[1024];
			
			text[0] = '\0';
			int team = GetClientTeam(client);
			int alive = IsPlayerAlive(client);
			
			GetClientIP(client, ip, sizeof(ip));
			if (!GeoipCode2(ip, tag))
			{
				tag = "??";
			}
			
			/* Flood Protection */
			if ((GetEngineTime()-g_fLastChatMsg[client]) < 0.75)
			{
				return Plugin_Handled;
			}
			g_fLastChatMsg[client] = GetEngineTime();
			
			if (client == 0 && args < 2)
			{
				return Plugin_Continue;
			}
			
			GetCmdArgString(text, sizeof(text));
			StripQuotes(text);
			TrimString(text);
			
			if (strcmp(text, " ") == 0 || strcmp(text, "") == 0 || strlen(text) == 0)
			{
				return Plugin_Handled;
			}
			
			if (StrContains(text, "@") == 0 || StrContains(text, "/") == 0)
			{
				return Plugin_Continue;
			}
			
			if (strcmp(command, "say") == 0)
			{
				if (team < 2) FormatEx(text, sizeof(text), "%t", "SPECTATOR_SAY_TEAM", tag, client, text);
				else
				{
					if (alive) FormatEx(text, sizeof(text), "%t", "ALIVE_CHAT", tag, client, text);
					else FormatEx(text, sizeof(text),"%t", "DEAD", tag, client, text);
				}
				CPrintToChatAllEx(client, "%s", text);
				return Plugin_Handled;
			}
			
			else if(strcmp(command, "say_team") == 0)
			{
				switch(team)
				{
					case 1:FormatEx(text, sizeof(text),"%t", "SPECTATOR_SAY", tag, client, text);
					case 2:
					{
						if (alive) FormatEx(text, sizeof(text), "%t", "TEAM_T", tag, client, text);
						else FormatEx(text, sizeof(text), "%t", "DEAD_TEAM_T", tag, client, text);
					}
					case 3:
					{
						if (alive) FormatEx(text, sizeof(text), "%t", "TEAM_CT", tag, client, text);
						else FormatEx(text, sizeof(text), "%t", "%t", "DEAD_TEAM_CT", tag, client, text);
					}
				}
				
				for (int x = 1; x <= MaxClients; x++)
				{
					if (IsClientInGame(x) && GetClientTeam(x) == team)
					{
						CPrintToChatEx(x, x, "%s", text);
					}
				}
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}

public void PlySpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (b_cvar_clantag)
	{
		int client = GetClientOfUserId(event.GetInt("userid"));
		{
			if (client)
			{
				PlySettings(client);
			}
		}
	}
}

void PlySettings(int client)
{
	if (!IsValidClient(client))
		return;

	CreateTimer(1.5, SetClanTag, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action SetClanTag(Handle timer, any client)
{
	if (!IsValidClient(client) || IsFakeClient(client))
		return;

	char ip[14]; 
	char tag[3]; 
	char info[40];
	
	GetClientIP(client, ip, sizeof(ip)); 
	GeoipCode2(ip, tag);
	FormatEx(info, sizeof(info), "%t", "CLAN_TAG", tag); // Форматируем строку.
	CS_SetClientClanTag(client, info);
}

public void OnClientPostAdminCheck(int client)
{
	g_fLastChatMsg[client] = 0.0;
}

stock bool IsValidClient(int client)
{
	if (0 < client && client <= MaxClients && IsClientInGame(client))
	{
		return true;
	}
	return false;
}

void UpdateState()
{
	b_cvar_clantag = GetConVarBool(h_cvar_clantag);
	b_cvar_chattag = GetConVarBool(h_cvar_chattag);
}

void HookEventsCvars()
{
	HookConVarChange(h_cvar_clantag, Event_CvarChange);
	HookConVarChange(h_cvar_chattag, Event_CvarChange);
}

public void Event_CvarChange(Handle cvar, const char[] oldValue, const char[] newValue)
{
	UpdateState();
}