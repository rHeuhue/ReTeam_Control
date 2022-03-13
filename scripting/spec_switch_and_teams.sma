#include <amxmodx>
#include <reapi>

new TeamName:g_iPlayerLastTeam[MAX_PLAYERS + 1]
new Float:g_fPlayerLastChooseTime[MAX_PLAYERS + 1]
new bool:g_bSpectator[MAX_PLAYERS + 1], bool:g_bWasPlayerAlive[MAX_PLAYERS + 1]

const Float:COMMAND_TIMEOUT = 2.0
const ADMIN_ACCESS_FLAG = ADMIN_BAN

enum
{
	ANY_TEAM, SPECTATOR, TEAM_SWAP
}

public plugin_init()
{
	register_plugin("Spec Switch & Team Swap", "1.1.0", "Huehue @ AMXX-BG.INFO")

	RegisterHookChain(RG_CBasePlayer_GetIntoGame, "RG__CBasePlayer_GetIntoGame", true)

	register_clcmd("say /spec", "Player_SpecSwitch")
	register_clcmd("say /back", "Player_BackSwitch")
	register_clcmd("say /team", "Player_TeamSwap")
}

public client_putinserver(id)
{
	g_bSpectator[id] = false
	g_bWasPlayerAlive[id] = false
	g_iPlayerLastTeam[id] = TEAM_UNASSIGNED
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

	TransferTo(id, SPECTATOR)

	return PLUGIN_HANDLED
}

public Player_BackSwitch(id)
{
	if (!is_user_connected(id))
			return PLUGIN_HANDLED

	TransferTo(id, ANY_TEAM)

	return PLUGIN_HANDLED
}

public Player_TeamSwap(id)
{
	if (!is_user_connected(id))
			return PLUGIN_HANDLED

	if (~get_user_flags(id) & ADMIN_ACCESS_FLAG)
	{
		client_print_color(id, print_team_red, "^4[AMXX-BG] ^1You ^3don't have access ^1to this ^4command^1.")
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

				g_bWasPlayerAlive[id] = is_user_alive(id) ? true : false

				if (g_bWasPlayerAlive[id])
				{
					user_silentkill(id)
					set_member(id, m_iDeaths, get_member(id, m_iDeaths) - 1)
				}

				rg_set_user_team(id, .team = iTeam)
				g_bSpectator[id] = true

				client_print_color(id, print_team_grey, "^4[AMXX-BG] ^1Switched to ^3Spectator^1.")
			}
			else
			{
				client_print_color(id, print_team_grey, "^4[AMXX-BG] ^1You are already ^3Spectator^1, type in ^4/back ^1to return in ^4team^1.")
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

				if (g_bWasPlayerAlive[id])
				{
					g_bWasPlayerAlive[id] = false
					rg_round_respawn(id)
				}

				g_bSpectator[id] = false
				client_print_color(id, print_team_default, "^4[AMXX-BG] ^1Switched to ^3%s^1.", iTeam == TEAM_CT ? "Counter-Terrorist" : "Terrorist")
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

				client_print_color(id, print_team_default, "^4[AMXX-BG] ^1Switched to ^3%s^1.", iTeam == TEAM_CT ? "Counter-Terrorist" : "Terrorist")
			}
		}
	}
	return PLUGIN_HANDLED
}