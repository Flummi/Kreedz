#include <amxmodx>

#include <kreedz_api>
#include <kreedz_util>

#define PLUGIN 	 	"[Kreedz] Server utils"
#define VERSION 	__DATE__
#define AUTHOR	 	"ggv"

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_clcmd("amx_restart", "cmd_ServerRestart");
	kz_register_cmd("uptime", "cmd_Uptime");
}

public cmd_ServerRestart(id) {
	if (!(get_user_flags(id) & ADMIN_IMMUNITY))
		return PLUGIN_CONTINUE;

	server_cmd("restart");

	return PLUGIN_HANDLED;
}

public cmd_Uptime(id) {
	new timeunit_seconds = floatround(get_gametime(), floatround_floor);
	new timeunit_minutes;
	new timeunit_hours;
	new timeunit_days;

	if((timeunit_seconds / 60.0) >= 1) {
		timeunit_days = floatround(timeunit_seconds / 86400.0, floatround_floor);
		timeunit_seconds -= timeunit_days * 86400;

		timeunit_hours = floatround(timeunit_seconds / 3600.0, floatround_floor);
		timeunit_seconds -= timeunit_hours * 3600;

		timeunit_minutes = floatround(timeunit_seconds / 60.0, floatround_floor);
		timeunit_seconds -= timeunit_minutes * 60;
	}

	if(timeunit_days > 0)
		client_print_color(id, print_chat, "^x01[KZ]^x03 Server up since %d day%s and %s%d:%s%d:%s%d second%s", timeunit_days, timeunit_days > 1 ? "s" : "", timeunit_hours < 10 ? "0" : "", timeunit_hours, timeunit_minutes < 10 ? "0" : "", timeunit_minutes, timeunit_seconds < 10 ? "0" : "", timeunit_seconds, timeunit_seconds > 1 ? "s" : "");
	else if(timeunit_hours > 0)
		client_print_color(id, print_chat, "^x01[KZ]^x03 Server up since %s%d:%s%d:%s%d second%s", timeunit_hours < 10 ? "0" : "", timeunit_hours, timeunit_minutes < 10 ? "0" : "", timeunit_minutes, timeunit_seconds < 10 ? "0" : "", timeunit_seconds, timeunit_seconds > 1 ? "s" : "");
	else if(timeunit_minutes > 0)
		client_print_color(id, print_chat, "^x01[KZ]^x03 Server up since %s%d:%s%d second%s", timeunit_minutes < 10 ? "0" : "", timeunit_minutes, timeunit_seconds < 10 ? "0" : "", timeunit_seconds, timeunit_seconds > 1 ? "s" : "");
	else
		client_print_color(id, print_chat, "^x01[KZ]^x03 Server up since %d second%s", timeunit_seconds, timeunit_seconds > 1 ? "s" : "");

	return PLUGIN_HANDLED;
}
