#include <amxmodx>
#include <reapi>

#include <kreedz_api>
#include <kreedz_util>
#include <settings_api>

#define PLUGIN 	 	"[Kreedz] AirAccelerate"
#define VERSION 	__DATE__
#define AUTHOR	 	"Flummi/WaLkMaN"

enum OptionsEnum {
	optIntAirAccelerate,
};

new g_Options[OptionsEnum];

enum _:UserDataStruct {
	ud_AirAccelerate,
};

new g_UserData[MAX_PLAYERS + 1][UserDataStruct];

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);

	RegisterHookChain(RG_PM_AirMove, "PM_AirMove", 0);

	kz_register_cmd("aa", "cmdAA");

	bindOptions();
}

public bindOptions() {
	g_Options[optIntAirAccelerate] = find_option_by_name("airaccelerate");
}

public OnCellValueChanged(id, optionId, newValue) {
	if (optionId == g_Options[optIntAirAccelerate]) {
		g_UserData[id][ud_AirAccelerate] = newValue;
	}
}

public PM_AirMove(id) {
	set_movevar(mv_airaccelerate, float(g_UserData[id][ud_AirAccelerate]));
}

public cmdAA(id) {
	if(!is_user_alive(id))
		return PLUGIN_HANDLED;
		
	new iOldAA = g_UserData[id][ud_AirAccelerate];
	g_UserData[id][ud_AirAccelerate] = iOldAA == 10 ? 100 : 10;

	client_print_color(id, false, "^4AirAccelerate changed from ^3%i^4 to ^3%i.", iOldAA, g_UserData[id][ud_AirAccelerate]);

	if ((kz_get_timer_state(id) != TIMER_DISABLED) && iOldAA != g_UserData[id][ud_AirAccelerate]) {
		kz_stop_timer(id);
		client_print_color(id, print_team_default, "^4[KZ] ^1Timer resetted.");
	}

	set_option_cell(id, g_Options[optIntAirAccelerate], g_UserData[id][ud_AirAccelerate]);

	return PLUGIN_HANDLED;
}
