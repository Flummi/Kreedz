#include <amxmodx>
#include <reapi>

#include <kreedz_api>
#include <kreedz_util>
#include <settings_api>

#define HasBit(%1,%2) ( %1 &   ( 1 << ( %2 & 31 ) ) )
#define SetBit(%1,%2) ( %1 |=  ( 1 << ( %2 & 31 ) ) )
#define DelBit(%1,%2) ( %1 &= ~( 1 << ( %2 & 31 ) ) )

#define MAX_PLAYERS 32

new g_bitCustomAirAccel;
new g_iCustomAirAccel[MAX_PLAYERS + 1];
new Float:g_flCustomAirAccel[MAX_PLAYERS + 1];

new sv_airaccelerate;

new g_iMaxPlayers;

public plugin_init() {
	register_plugin("AirAccelerate", "0.0.1", "Exolent");
	
	RegisterHookChain(RG_PM_AirMove, "PM_AirMove", false);

	sv_airaccelerate = get_cvar_pointer("sv_airaccelerate");
	
	g_iMaxPlayers = get_maxplayers();
}

public client_disconnected(iPlayer) {
	DelBit(g_bitCustomAirAccel, iPlayer);
}

public plugin_natives() {
	register_library("airaccelerate");
	
	register_native("set_user_airaccelerate", "_set_user_airaccelerate");
	register_native("get_user_airaccelerate", "_get_user_airaccelerate");
}

public _set_user_airaccelerate(iPlugin, iParams) {
	if(iParams != 2)
		return 0;
	
	new iPlayer = get_param(1);
	
	if(!( 0 <= iPlayer <= g_iMaxPlayers))
		return 0;
	
	new iNewAirAccel = get_param(2);
	
	if(iPlayer) {
		new iOldAirAccel;
		
		if(HasBit(g_bitCustomAirAccel, iPlayer))
			iOldAirAccel = g_iCustomAirAccel[iPlayer];
		else {
			SetBit(g_bitCustomAirAccel, iPlayer);
			iOldAirAccel = get_pcvar_num(sv_airaccelerate);
		}
		
		g_iCustomAirAccel[iPlayer] = iNewAirAccel;
		g_flCustomAirAccel[iPlayer] = float(iNewAirAccel);
		
		return iOldAirAccel;
	}
	
	for(iPlayer = 1; iPlayer <= g_iMaxPlayers; iPlayer++) {
		SetBit(g_bitCustomAirAccel, iPlayer);
		
		g_iCustomAirAccel[iPlayer] = iNewAirAccel;
		g_flCustomAirAccel[iPlayer] = float(iNewAirAccel);
	}
	
	return 1;
}

public _get_user_airaccelerate(iPlugin, iParams) {
	if(iParams != 1)
		return 0;
	
	new iPlayer = get_param(1);
	
	if(!(1 <= iPlayer <= g_iMaxPlayers))
		return 0;
	
	new iAirAccel;
	
	if(HasBit(g_bitCustomAirAccel, iPlayer))
		iAirAccel = g_iCustomAirAccel[iPlayer];
	else
		iAirAccel = get_pcvar_num(sv_airaccelerate);
	
	return iAirAccel;
}

public PM_AirMove(id) {
	set_movevar(mv_airaccelerate, g_flCustomAirAccel[id]);
}
