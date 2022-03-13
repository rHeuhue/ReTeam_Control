#include <amxmodx>
#include <reapi>

new const PLUGIN_VERSION[] = "1.1.1"

new TeamName:g_iPlayerLastTeam[MAX_CLIENTS + 1]
new Float:g_fPlayerLastChooseTime[MAX_CLIENTS + 1]
new bool:g_bSpectator[MAX_CLIENTS + 1], bool:g_bWasPlayerAlive[MAX_CLIENTS + 1]

const Float:COMMAND_TIMEOUT = 2.0

enum
{
	ANY_TEAM, SPECTATOR, TEAM_SWAP
}

enum eAllCvars
{
	GOSPEC_FLAG[2],
	CHANGE_TEAM_FLAG[2],
	AUTO_RESPAWN,
	CHAT_PREFIX[32]
}
enum eFlags
{
	SPEC_FLAG,
	CHANGE_FLAG
}

new g_eCvars[eAllCvars], g_eFlags[eFlags]

public plugin_init()
{
	register_plugin("ReTeam Control", PLUGIN_VERSION, "Huehue @ AMXX-BG.INFO")
	register_cvar("ReTeam_Control", PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED|FCVAR_PROTECTED)

	RegisterHookChain(RG_CBasePlayer_GetIntoGame, "RG__CBasePlayer_GetIntoGame", true)

	new pCvar

	pCvar = create_cvar("re_tc_spec_back_flag_access", "b", FCVAR_NONE, "Go to Spec or Back to team access flag^nEmpty cvar = available for everyone")
	bind_pcvar_string(pCvar, g_eCvars[GOSPEC_FLAG], charsmax(g_eCvars[GOSPEC_FLAG]))

	pCvar = create_cvar("re_tc_change_team_flag_access", "b", FCVAR_NONE, "Go to Opposite Team - access flag^nEmpty cvar = available for everyone")
	bind_pcvar_string(pCvar, g_eCvars[CHANGE_TEAM_FLAG], charsmax(g_eCvars[CHANGE_TEAM_FLAG]))

	pCvar = create_cvar("re_tc_auto_respawn", "1", FCVAR_NONE, "After getting back in team will you be respawned or not")
	bind_pcvar_num(pCvar, g_eCvars[AUTO_RESPAWN])

	pCvar = create_cvar("re_tc_chat_messages_prefix", "!g[!tTeam Control!g]!y", FCVAR_NONE, "Chat Prefix^nColors:^n!g - Green^n!t - Team Color^n!n / !y - Default (Normal/Yellow)")
	bind_pcvar_string(pCvar, g_eCvars[CHAT_PREFIX], charsmax(g_eCvars[CHAT_PREFIX]))

	AutoExecConfig(true, "ReTeamControl", "HuehuePlugins_Config")

	register_clcmd("say /spec", "Player_SpecSwitch")
	register_clcmd("say /back", "Player_BackSwitch")
	register_clcmd("say /team", "Player_TeamSwap")
	register_clcmd("say /change", "Player_TeamSwap")
}

public OnConfigsExecuted()
{
	g_eFlags[SPEC_FLAG] = g_eCvars[GOSPEC_FLAG] == EOS ? ADMIN_ALL : read_flags(g_eCvars[GOSPEC_FLAG])
	g_eFlags[CHANGE_FLAG] = g_eCvars[CHANGE_TEAM_FLAG] == EOS ? ADMIN_ALL : read_flags(g_eCvars[CHANGE_TEAM_FLAG])

	replace_all(g_eCvars[CHAT_PREFIX], charsmax(g_eCvars[CHAT_PREFIX]), "!g", "^4")
	replace_all(g_eCvars[CHAT_PREFIX], charsmax(g_eCvars[CHAT_PREFIX]), "!t", "^3")
	replace_all(g_eCvars[CHAT_PREFIX], charsmax(g_eCvars[CHAT_PREFIX]), "!n", "^1")
	replace_all(g_eCvars[CHAT_PREFIX], charsmax(g_eCvars[CHAT_PREFIX]), "!y", "^1")
}


public client_putinserver(id)
{
	g_bSpectator[id] = false
	g_bWasPlayerAlive[id] = false
	g_iPlayerLastTeam[id] = TEAM_UNASSIGNED
	set_task(5.0, "Delayed_Info_Message", id)
}

public Delayed_Info_Message(id)
{
	if (g_iPlayerLastTeam[id] == TEAM_UNASSIGNED && get_member(id, m_iTeam) == TEAM_SPECTATOR)
	{
		client_print_color(id, print_team_grey, "%s ^1You are ^3Spectator^1, type in ^4/team ^1or ^4/change ^1to join any ^4team^1.", g_eCvars[CHAT_PREFIX])
		set_task(20.0, "Delayed_Info_Message", id)
	}
}

public RG__CBasePlayer_GetIntoGame(const id)
{
	if (is_user_connected(id))
		g_iPlayerLastTeam[id] = get_member(id, m_iTeam)
}

public Player_SpecSwitch(id)
{
	if (!is_user_connected(id))
			return PLUGIN_HANDLED

	if (!Check_Access(id, g_eFlags[SPEC_FLAG]))
	{
		client_print_color(id, print_team_red, "%s ^1You ^3don't have access ^1to this ^4command^1.", g_eCvars[CHAT_PREFIX])
		return PLUGIN_HANDLED
	}

	TransferTo(id, SPECTATOR)

	return PLUGIN_HANDLED
}

public Player_BackSwitch(id)
{
	if (!is_user_connected(id))
			return PLUGIN_HANDLED

	if (!Check_Access(id, g_eFlags[SPEC_FLAG]))
	{
		client_print_color(id, print_team_red, "%s ^1You ^3don't have access ^1to this ^4command^1.", g_eCvars[CHAT_PREFIX])
		return PLUGIN_HANDLED
	}

	TransferTo(id, ANY_TEAM)

	return PLUGIN_HANDLED
}

public Player_TeamSwap(id)
{
	if (!is_user_connected(id))
			return PLUGIN_HANDLED

	if (!Check_Access(id, g_eFlags[CHANGE_FLAG]))
	{
		client_print_color(id, print_team_red, "%s ^1You ^3don't have access ^1to this ^4command^1.", g_eCvars[CHAT_PREFIX])
		return PLUGIN_HANDLED
	}

	TransferTo(id, TEAM_SWAP)

	return PLUGIN_HANDLED
}

public TransferTo(id, AnyTeam)
{
	if ((get_gametime() - g_fPlayerLastChooseTime[id]) < COMMAND_TIMEOUT)
	{
		client_print(id, print_center, "You can't spam the command so quickly, please wait..")
		return PLUGIN_HANDLED
	}

	g_fPlayerLastChooseTime[id] = get_gametime()

	new TeamName:iTeam, bool:b_JoinTeam = false

	switch (AnyTeam)
	{
		case SPECTATOR:
		{
			if (get_member(id, m_iTeam) != TEAM_SPECTATOR)
			{
				switch (g_iPlayerLastTeam[id] = get_member(id, m_iTeam))
				{
					case TEAM_TERRORIST, TEAM_CT:
					{
						iTeam = TEAM_SPECTATOR
					}
				}

				if (g_eCvars[AUTO_RESPAWN])
					g_bWasPlayerAlive[id] = is_user_alive(id) ? true : false

				if (is_user_alive(id))
				{
					user_silentkill(id)
					set_member(id, m_iDeaths, get_member(id, m_iDeaths) - 1)
				}

				rg_set_user_team(id, .team = iTeam)
				g_bSpectator[id] = true

				client_print_color(id, print_team_grey, "%s ^1Switched to ^3Spectator^1.", g_eCvars[CHAT_PREFIX])
			}
			else
			{
				client_print_color(id, print_team_grey, "%s ^1You are already ^3Spectator^1, type in ^4/back ^1to return in ^4team^1.", g_eCvars[CHAT_PREFIX])
			}
		}
		case ANY_TEAM:
		{
			if (g_bSpectator[id] || g_bSpectator[id] == false && get_member(id, m_iTeam) == TEAM_SPECTATOR)
			{
				if (g_iPlayerLastTeam[id] == TEAM_UNASSIGNED && get_member(id, m_iTeam) == TEAM_SPECTATOR)
				{
					iTeam = rg_get_join_team_priority()

					b_JoinTeam = true
				}
				else
				{
					iTeam = g_iPlayerLastTeam[id]
				}

				if (b_JoinTeam)
					rg_join_team(id, iTeam)

				rg_set_user_team(id, .team = iTeam, .model = MODEL_AUTO)

				if (g_bWasPlayerAlive[id] && g_eCvars[AUTO_RESPAWN])
				{
					g_bWasPlayerAlive[id] = false
					rg_round_respawn(id)
				}

				g_bSpectator[id] = false
				client_print_color(id, print_team_default, "%s ^1Switched to ^3%s^1.", g_eCvars[CHAT_PREFIX], iTeam == TEAM_CT ? "Counter-Terrorist" : "Terrorist")
			}
			else
			{
				client_print_color(id, print_team_grey, "%s ^1You are not ^3Spectator^1, type in ^4/spec ^1to become ^3spectator^1.", g_eCvars[CHAT_PREFIX])
			}
		}
		case TEAM_SWAP:
		{
			if (get_member(id, m_iTeam) != TEAM_SPECTATOR || g_iPlayerLastTeam[id] == TEAM_UNASSIGNED && get_member(id, m_iTeam) == TEAM_SPECTATOR)
			{
				switch (g_iPlayerLastTeam[id] = get_member(id, m_iTeam))
				{
					case TEAM_TERRORIST:
					{
						iTeam = TEAM_CT
					}
					case TEAM_CT:
					{
						iTeam = TEAM_TERRORIST
					}
					case TEAM_SPECTATOR:
					{
						iTeam = rg_get_join_team_priority()

						b_JoinTeam = true
					}
				}

				g_iPlayerLastTeam[id] = iTeam

				if (b_JoinTeam)
					rg_join_team(id, iTeam)

				rg_set_user_team(id, .team = iTeam, .model = MODEL_AUTO)

				if (!b_JoinTeam && is_user_alive(id))
					rg_round_respawn(id)

				if (g_eCvars[AUTO_RESPAWN])
					set_task(0.1, "Delayed_Respawn", id)

				client_print_color(id, print_team_default, "%s ^1Switched to ^3%s^1.", g_eCvars[CHAT_PREFIX], iTeam == TEAM_CT ? "Counter-Terrorist" : "Terrorist")
			}
			else
			{
				client_print_color(id, print_team_grey, "%s ^1You are ^3Spectator^1, type in ^4/back ^1to return in ^4team^1.", g_eCvars[CHAT_PREFIX])
			}
		}
	}
	return PLUGIN_HANDLED
}

public Delayed_Respawn(id)
{
	if (!is_user_alive(id))
		rg_round_respawn(id)
}

bool:Check_Access(id, iUserFlag)
{
	if (iUserFlag == ADMIN_ALL || get_user_flags(id) & iUserFlag)
		return true
	else
		return false
}