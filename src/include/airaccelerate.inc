#if defined _airaccelerate_included
	#endinput
#endif

#define _airaccelerate_included

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib airaccelerate
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib airaccelerate
	#endif
#else
	#pragma library airaccelerate
#endif

native set_user_airaccelerate(id, const airaccelerate);
native get_user_airaccelerate(id);
