#include <amxmodx>
#include <reapi>

new const PLUGIN_VERSION[] = "1.1.3"

const MAX_FLAG_LENGTH = 2
const MAX_PREFIX_LENGTH = 32

new TeamName:g_iPlayerLastTeam[MAX_CLIENTS + 1]
new Float:g_fPlayerLastChooseTime[MAX_CLIENTS + 1]
new bool:g_bSpectator[MAX_CLIENTS + 1], bool:g_bWasPlayerAlive[MAX_CLIENTS + 1]
new g_szMenuPrefix[MAX_PREFIX_LENGTH]

const Float:COMMAND_TIMEOUT = 2.0

enum
{
	ANY_TEAM, SPECTATOR, TEAM_SWAP
}

enum eAllCvars
{
	GOSPEC_FLAG[MAX_FLAG_LENGTH],
	CHANGE_TEAM_FLAG[MAX_FLAG_LENGTH],
	ADMIN_TEAM_FLAG_CMD[MAX_FLAG_LENGTH],
	AUTO_RESPAWN,
	CHAT_PREFIX[MAX_PREFIX_LENGTH]
}
enum eFlags
{
	SPEC_FLAG,
	CHANGE_FLAG,
	ADMIN_FLAG_CMD
}

new g_eCvars[eAllCvars], g_eFlags[eFlags]

const PLAYERS_PER_PAGE = 6

new g_iMenuPosition[MAX_CLIENTS + 1], g_iMenuOption[MAX_CLIENTS + 1]
new g_iPlayers[MAX_CLIENTS + 1][MAX_CLIENTS]
new g_iUserID[MAX_CLIENTS + 1][MAX_CLIENTS + 1]
new g_bSilent[MAX_CLIENTS + 1]

new const szTeamNames[3][] = { "TERRORIST", "CT", "SPECTATOR" }

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

	pCvar = create_cvar("re_tc_admin_team_change_flag_access", "m", FCVAR_NONE, "Admin Menu Command Access [amx_teammenu replacement] - access flag^nEmpty cvar = default command flag 'm'")
	bind_pcvar_string(pCvar, g_eCvars[ADMIN_TEAM_FLAG_CMD], charsmax(g_eCvars[ADMIN_TEAM_FLAG_CMD]))

	pCvar = create_cvar("re_tc_auto_respawn", "1", FCVAR_NONE, "After getting back in team will you be respawned or not")
	bind_pcvar_num(pCvar, g_eCvars[AUTO_RESPAWN])

	pCvar = create_cvar("re_tc_chat_messages_prefix", "!g[!tTeam Control!g]!y", FCVAR_NONE, "Chat Prefix^nColors:^n!g - Green^n!t - Team Color^n!n / !y - Default (Normal/Yellow)")
	bind_pcvar_string(pCvar, g_eCvars[CHAT_PREFIX], charsmax(g_eCvars[CHAT_PREFIX]))

	AutoExecConfig(true, "ReTeamControl", "HuehuePlugins_Config")

	register_clcmd("say /spec", "Player_SpecSwitch")
	register_clcmd("say /back", "Player_BackSwitch")
	register_clcmd("say /team", "Player_TeamSwap")
	register_clcmd("say /change", "Player_TeamSwap")

	register_clcmd("amx_teammenu", "Admin_TeamControlMenu", _, "- displays team menu")
	register_menucmd(register_menuid("admin_team_menu"), 1023, "Handle_Team_Menu")
}

public OnConfigsExecuted()
{
	g_eFlags[SPEC_FLAG] = g_eCvars[GOSPEC_FLAG] == EOS ? ADMIN_ALL : read_flags(g_eCvars[GOSPEC_FLAG])
	g_eFlags[CHANGE_FLAG] = g_eCvars[CHANGE_TEAM_FLAG] == EOS ? ADMIN_ALL : read_flags(g_eCvars[CHANGE_TEAM_FLAG])
	g_eFlags[ADMIN_FLAG_CMD] = g_eCvars[ADMIN_TEAM_FLAG_CMD] == EOS ? ADMIN_LEVEL_A : read_flags(g_eCvars[ADMIN_TEAM_FLAG_CMD])

	copy(g_szMenuPrefix, charsmax(g_szMenuPrefix), g_eCvars[CHAT_PREFIX])

	replace_all(g_eCvars[CHAT_PREFIX], charsmax(g_eCvars[CHAT_PREFIX]), "!g", "^4")
	replace_all(g_eCvars[CHAT_PREFIX], charsmax(g_eCvars[CHAT_PREFIX]), "!t", "^3")
	replace_all(g_eCvars[CHAT_PREFIX], charsmax(g_eCvars[CHAT_PREFIX]), "!n", "^1")
	replace_all(g_eCvars[CHAT_PREFIX], charsmax(g_eCvars[CHAT_PREFIX]), "!y", "^1")

	replace_all(g_szMenuPrefix, charsmax(g_szMenuPrefix), "!g", "\y")
	replace_all(g_szMenuPrefix, charsmax(g_szMenuPrefix), "!t", "\r")
	replace_all(g_szMenuPrefix, charsmax(g_szMenuPrefix), "!n", "\w")
	replace_all(g_szMenuPrefix, charsmax(g_szMenuPrefix), "!y", "\w")
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
	if (Is_Player_Unassign(id))
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
				if (Is_Player_Unassign(id))
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
			if (get_member(id, m_iTeam) != TEAM_SPECTATOR || Is_Player_Unassign(id))
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

// [amx_teammenu] Replacement! No more bugs and shitty problems with changing teams
public Admin_TeamControlMenu(id)
{
	if (!Check_Access(id, g_eFlags[ADMIN_FLAG_CMD]))
	{
		client_print_color(id, print_team_red, "%s ^1You ^3don't have access ^1to this ^4command^1.", g_eCvars[CHAT_PREFIX])
		return PLUGIN_HANDLED
	}

	Toggle_Team_Menu(id, g_iMenuPosition[id] = 0)

	return PLUGIN_HANDLED
}

Toggle_Team_Menu(const id, iPos)
{
	if (iPos < 0)
		return PLUGIN_CONTINUE

	new iPlayersNum, iStart, iEnd, iPagesNum, iLen, szMenu[MAX_MENU_LENGTH], i, b, iKeys = MENU_KEY_0|MENU_KEY_7|MENU_KEY_8
	new szTeam[5]

	get_players(g_iPlayers[id], iPlayersNum)

	if ((iStart = iPos * PLAYERS_PER_PAGE) >= iPlayersNum)
		iStart = iPos = g_iMenuPosition[id] = 0

	if((iEnd = iStart + PLAYERS_PER_PAGE) > iPlayersNum)
		iEnd = iPlayersNum

	if ((iPagesNum = iPlayersNum / PLAYERS_PER_PAGE + (iPlayersNum % PLAYERS_PER_PAGE ? 1 : 0)) == 1)
		iLen = copy(szMenu, charsmax(szMenu), fmt("%s^n\yChose player..^n^n", g_szMenuPrefix))
	else
		iLen = formatex(szMenu, charsmax(szMenu), "%s^n\yChose player.. \R\d(%d/%d)^n^n", g_szMenuPrefix, iPos + 1, iPagesNum)

	while (iStart < iEnd)
	{
		i = g_iPlayers[id][iStart++]
		g_iUserID[id][i] = get_user_userid(i)

		switch (get_member(i, m_iTeam))
		{
			case TEAM_TERRORIST: { copy(szTeam, charsmax(szTeam), "TE"); }
			case TEAM_CT: { copy(szTeam, charsmax(szTeam), "CT"); }
			case TEAM_SPECTATOR, TEAM_UNASSIGNED: { copy(szTeam, charsmax(szTeam), "SPEC"); }
		}

		if (Check_Access(id, ADMIN_RCON))
		{
			iKeys |= (1 << b)
			if (i != id)
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y%i. \w%n%s\R\d%s^n", ++b, i, (Check_Access(i, ADMIN_IMMUNITY)) || (Check_Access(i, g_eFlags[ADMIN_FLAG_CMD])) ? " \y*" : "", szTeam)
			else
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y%i. \w%n \r*\R\d%s^n", ++b, i, szTeam)	
		}
		else if (Check_Access(id, g_eFlags[ADMIN_FLAG_CMD]))
		{
			if (i == id || Check_Access(i, g_eFlags[ADMIN_FLAG_CMD]) || Check_Access(i, ADMIN_RCON))
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\d%i. %n%s\R\d%s^n", ++b, i, i == id ? " \r*" : " \y*", szTeam)
			else
			{
				iKeys |= (1 << b)
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y%i. \w%n%s\R\d%s^n", ++b, i, (Check_Access(i, ADMIN_IMMUNITY)) ? " \y*" : "", szTeam)
			}
		}
	}

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n^n^t^t\y7. \wTransfer Silent: %s", g_bSilent[id] ? "\yYes" : "\rNo")
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n^t^t\y8. \wTransfer to: \r%s", szTeamNames[g_iMenuOption[id] % 3])

	if (iEnd < iPlayersNum)
	{
		iKeys |= MENU_KEY_9
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n^n\y9. \wNext^n\y0. \w%s", iPos ? "Back" : "Exit")
	}
	else
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n^n\y0. \w%s", iPos ? "Back" : "Exit")
   
	return show_menu(id, iKeys, szMenu, -1, "admin_team_menu")
}

public Handle_Team_Menu(const id, const iKey)
{
	switch (iKey)
	{
		case 6:
		{
			g_bSilent[id] = !g_bSilent[id]
			Toggle_Team_Menu(id, g_iMenuPosition[id])
		}
		case 7:
		{
			g_iMenuOption[id] = (g_iMenuOption[id] + 1) % 3
			Toggle_Team_Menu(id, g_iMenuPosition[id])
		}
		case 8: Toggle_Team_Menu(id, ++g_iMenuPosition[id])
		case 9: Toggle_Team_Menu(id, --g_iMenuPosition[id])
		default:
		{
			new iTarget = g_iPlayers[id][g_iMenuPosition[id] * PLAYERS_PER_PAGE + iKey]

			if (!is_user_connected(iTarget)) // dunno why this check hasn't be implemented in the past
			{
				Toggle_Team_Menu(id, g_iMenuPosition[id])
				return PLUGIN_HANDLED
			}

			if (Check_Access(iTarget, ADMIN_RCON) && iTarget != id)
			{
				client_print_color(id, print_team_grey, "%s ^3You have no access to move this player (^4%n^3)", g_eCvars[CHAT_PREFIX], iTarget)
				Toggle_Team_Menu(id, g_iMenuPosition[id])
				return PLUGIN_HANDLED
			}

			new iDestination_TeamJoin = (g_iMenuOption[id] % 3)

			new const PrintTypeColor[] =
			{
				print_team_red, print_team_blue, print_team_grey
			}

			if (get_user_userid(iTarget) == g_iUserID[id][iTarget])
			{
				if (get_member(iTarget, m_iTeam) == iDestination_TeamJoin + 1)
				{
					client_print_color(id, PrintTypeColor[iDestination_TeamJoin], "%s Player^1(^3%n^1) is already in this team (^3%s^1)", g_eCvars[CHAT_PREFIX], iTarget, szTeamNames[iDestination_TeamJoin])
					Toggle_Team_Menu(id, g_iMenuPosition[id])
					return PLUGIN_HANDLED
				}
				
				if (g_bSilent[id])
				{
					if (is_user_alive(iTarget))
					{
						if (iDestination_TeamJoin == 2)
							user_kill(iTarget)

						if (Is_Player_Unassign(iTarget))
							rg_join_team(iTarget, iDestination_TeamJoin == 0 ? TEAM_TERRORIST : TEAM_CT)

						rg_set_user_team(iTarget, iDestination_TeamJoin + 1)
					}
				}
				else
				{
					if (is_user_alive(iTarget))
						user_kill(iTarget)

					if (Is_Player_Unassign(iTarget))
						rg_join_team(iTarget, iDestination_TeamJoin == 0 ? TEAM_TERRORIST : TEAM_CT)

					rg_set_user_team(iTarget, iDestination_TeamJoin + 1)
				}

				client_print_color(0, PrintTypeColor[iDestination_TeamJoin], "^1ADMIN ^4%n^1: transfer ^4%n ^1to ^3%s", id, iTarget, szTeamNames[iDestination_TeamJoin])
			}
			Toggle_Team_Menu(id, g_iMenuPosition[id])
		}
	}
	return PLUGIN_HANDLED
}

bool:Is_Player_Unassign(id)
{
	if (g_iPlayerLastTeam[id] == TEAM_UNASSIGNED && get_member(id, m_iTeam) == TEAM_SPECTATOR)
		return true
	else
		return false
}

bool:Check_Access(id, iUserFlag)
{
	if (iUserFlag == ADMIN_ALL || get_user_flags(id) & iUserFlag)
		return true
	else
		return false
}