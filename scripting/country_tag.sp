#pragma semicolon 1
#include <colors> 
#include <geoip> 
#include <basecomm>
#include <cstrike>
#include <autoexecconfig>
#pragma newdecls required
#define PL_VERSION "1.10"

float g_fLastChatMsg[MAXPLAYERS + 1];

Handle g_hClanTag = null,
	   g_hChatTag = null;

public Plugin myinfo =
{
	name = "Country Tag",
	author = "Hejter & Danyas",
	description = "Add in chat and in scoreboard country tag.",
	version = PL_VERSION,
	url = "https://github.com/Heyter/CountryTag",
};

public void OnPluginStart()
{
	CreateConVar("country_tag_version", PL_VERSION, "Country tag", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	AutoExecConfig_SetFile("plugin.country_tag");
	AutoExecConfig_SetCreateFile(true);
	
	g_hClanTag = AutoExecConfig_CreateConVar("ClanTag", "1", "Clan tag enable = 1; disable = 0", _, true, 0.0, true, 1.0);
	g_hChatTag = AutoExecConfig_CreateConVar("ChatTag", "1", "Chat tag enable = 1; disable = 0", _, true, 0.0, true, 1.0);
	
	AutoExecConfig_CleanFile();
	AutoExecConfig_ExecuteFile();
	
	AddCommandListener(ChatSay, "say");
	AddCommandListener(ChatSay, "say_team");
	
	HookEvent("player_spawn", PlySpawn, EventHookMode_Post);
	
	LoadTranslations("country_tag.phrases");
}

public Action ChatSay(int client, const char[] command, int args)
{
	if(GetConVarInt(g_hChatTag))
	{
		if (IsValidClient(client))
		{
			if (BaseComm_IsClientGagged(client))
			{
				PrintToChat(client, "%t", "MUTE");
				return Plugin_Handled;
			}
			
			char ip[14], tag[3], text[1024];
			
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
				if (team < 2) Format(text, sizeof(text), "%t", "SPECTATOR_SAY_TEAM", tag, client, text);
				else
				{
					if (alive) Format(text, sizeof(text), "%t", "ALIVE_CHAT", tag, client, text);
					else Format(text, sizeof(text),"%t", "DEAD", tag, client, text);
				}
				CPrintToChatAllEx(client, "%s", text);
				return Plugin_Handled;
			}
			
			else if(strcmp(command, "say_team") == 0)
			{
				switch(team)
				{
					case 1:Format(text, sizeof(text),"%t", "SPECTATOR_SAY", tag, client, text);
					case 2:
					{
						if (alive) Format(text, sizeof(text), "%t", "TEAM_T", tag, client, text);
						else Format(text, sizeof(text), "%t", "DEAD_TEAM_T", tag, client, text);
					}
					case 3:
					{
						if (alive) Format(text, sizeof(text), "%t", "TEAM_CT", tag, client, text);
						else Format(text, sizeof(text), "%t", "%t", "DEAD_TEAM_CT", tag, client, text);
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
	if(GetConVarInt(g_hClanTag))
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

	char ip[14], tag[3], info[40];
	
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
