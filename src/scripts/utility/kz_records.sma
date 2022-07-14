#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta_util>
#include <engine>
#include <fun>
#include <hamsandwich>
#include <easy_http>
#include <AmxxArch>

#include <kreedz_api>
#include <kreedz_records>
#include <kreedz_util>

#define PLUGIN 	"[Kreedz] Records / WRBot"
#define VERSION "1.2"
#define AUTHOR 	"Flummi/MichaelKheel/ggv"

enum _:SourceStruct {
	Title[64],
	Link[128],
	Suffix[16],
	RecordsFile[256],
	SkipString[128],
};

new Array:ga_Sources;
new Array:ga_Records;

new g_DataDir[256];
new g_szWorkDir[256];
new g_szMapName[64];

// <wrbot>
new g_Extension[5];
new g_ArchivName[256];
new g_Filename[256];

new iDemoDir[256];
new iDemoName[256];
new iNavName[256];
new iParsedFile;
new Float:flStartTime;
new iFile;
new iDemo_header_size;
new Trie:g_tButtons[2];
new Array:fPlayerAngle, Array:fPlayerKeys, Array:fPlayerVelo, Array:fPlayerOrigin;
new g_timer;
new Float:timer_time[33], bool:timer_started[33], bool:IsPaused[33], Float:g_pausetime[33], bool:bot_finish_use[33];
new g_bot_start, g_bot_enable, g_bot_frame, wr_bot_id;
new SyncHudBotTimer;
new WR_TIME[130], WR_NAME[130], WR_COUNTRY[130], WR_SRC[5];
new Float:nExttHink = 0.009;
new timer_bot, timer_option;
// </wrbot>

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);

	kz_register_cmd("wr", "cmd_WorldRecord");
	kz_register_cmd("ru", "cmd_WorldRecord");

	register_dictionary("kz_records.txt");
}

public plugin_cfg() {
	get_localinfo("amxx_datadir", g_DataDir, charsmax(g_DataDir));
	format(g_szWorkDir, charsmax(g_szWorkDir), "%s/kz_records", g_DataDir);
	
	if(!dir_exists(g_szWorkDir)) {
		mkdir(g_szWorkDir);
	}

	get_mapname(g_szMapName, charsmax(g_szMapName));
	strtolower(g_szMapName);

	ga_Sources = ArrayCreate(SourceStruct);
	ga_Records = ArrayCreate(RecordsStruct);
	InitSources();
	
	for (new i = 0; i < ArraySize(ga_Sources); ++i) {
		fnParseInfo(i);
	}

	new temp[256];
	format(temp, 255, "%s/last_update.ini", g_szWorkDir);
	
	if (!file_exists(temp)) {
		fnUpdate();
		return PLUGIN_CONTINUE;
	}
	
	new year, month, day;
	date(year, month, day);
	
	new f = fopen(temp, "rt");
	fgets(f, temp, 255);
	fclose(f);
	
	if (str_to_num(temp[0]) > year || str_to_num(temp[5]) > month || str_to_num(temp[8]) > day) {
		fnUpdate();
		return PLUGIN_CONTINUE;
	}

	// wrbot
	timer_bot = register_cvar("timer_bot", "1");
	timer_option = register_cvar("timer_option", "1"); // 1 txt, 2 hud

	new kreedz_cfg[128], ConfigDir[64];
	get_configsdir(ConfigDir, 64);
	formatex(kreedz_cfg, 128, "%s/wrbot.cfg", ConfigDir);

	if(file_exists(kreedz_cfg)) {
		server_cmd("exec %s", kreedz_cfg);
		server_exec();
	}
	else
		server_print("[WR_BOT] Config file is not connected, please check.");

	if(get_pcvar_num(timer_bot) == 1) {
		new iTimerEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString , "info_target"));
		set_pev(iTimerEnt, pev_classname, "kz_time_think");
		set_pev(iTimerEnt, pev_nextthink, get_gametime() + 1.0);
	}

	SyncHudBotTimer = CreateHudSyncObj();

	initBot();
	
	return PLUGIN_CONTINUE;
}

public plugin_natives() {
	register_native("kz_records_get_array", "native_get_array", 1);
}

public client_disconnected(id) {
	if(id == wr_bot_id) {
		timer_time[id] = 0.0;
		IsPaused[wr_bot_id] = false;
		timer_started[wr_bot_id] = false;
		g_bot_enable = 0;
		g_bot_frame = 0;
		wr_bot_id = 0;
	}
}

public Array:native_get_array() {
	return ga_Records;
}

public initBot() {
	new recordsInfo[RecordsStruct];
	new wr[RecordsStruct];

	for (new i = 0; i < ArraySize(ga_Records); ++i) {
		ArrayGetArray(ga_Records, i, recordsInfo);

		if(recordsInfo[RecordsTime] != 0
			&& (recordsInfo[RecordsTime] < wr[RecordsTime] || wr[RecordsTime] == 0)
		) {
			wr = recordsInfo;
		}
	}

	if(wr[RecordsTime] > 0) {
		server_print("wr: title: %s | src: %s | author: %s | time: %f | ext: %s",
						wr[RecordsTitle], wr[RecordsSource], wr[RecordsAuthor], wr[RecordsTime], wr[RecordsExtension]);

		new iLink[512], sWRTime[24];
		fnConvertTime(wr[RecordsTime], sWRTime, charsmax(sWRTime));
		format(g_ArchivName, charsmax(g_ArchivName), "%s_%s_%s", g_szMapName, wr[RecordsAuthor], sWRTime);

		if(equal(wr[RecordsSource], "xj")) {
			format(iLink, charsmax(iLink), "http://files.xtreme-jumps.eu/demos/%s.rar", g_ArchivName);
			g_Extension = "rar";
		}
		else if(equal(wr[RecordsSource], "cc")) {
			format(iLink, charsmax(iLink), "https://cosy-climbing.net/files/demos/%s.rar", g_ArchivName);
			g_Extension = "rar";
		}
		else if(equal(wr[RecordsSource], "ru")) {
			format(iLink, charsmax(iLink), "https://kz-rush.ru/xr_public/demos/maps/cs16/%s.zip", g_ArchivName);
			g_Extension = "zip";
		}

		server_print("dllink: %s", iLink);

		downloadDemo(iLink);
	}
	else {
		server_print("no wr lol");
	}
}

public downloadDemo(iLink[]) {
	new datadir[128];
	get_localinfo("amxx_datadir", datadir, charsmax(datadir));
	
	new demodir[128], demodirfile[128];
	format(demodir, charsmax(demodir), "%s/demos", datadir);
	format(demodirfile, charsmax(demodirfile), "%s/%s", demodir, g_szMapName);

	if(!dir_exists(demodir))
		mkdir(demodir);
	if(!dir_exists(demodirfile))
		mkdir(demodirfile);

	format(g_Filename, charsmax(g_Filename), "%s/%s.%s", datadir, g_ArchivName, g_Extension);

	ezhttp_get(iLink, "@fndownloadDemoFinishCallback");
}

@fndownloadDemoFinishCallback(EzHttpRequest:request_id) {
	if (ezhttp_get_error_code(request_id) != EZH_OK) {
        new error[64];
        ezhttp_get_error_message(request_id, error, charsmax(error));
        server_print("Response error: %s", error);
    }
	else {
		ezhttp_save_data_to_file(request_id, g_Filename);
		
		server_print("archive: %s, extension: %s, filename: %s", g_ArchivName, g_Extension, g_Filename);
		// decompress
		format(iDemoDir, sizeof(iDemoDir), "%s/demos/%s", g_DataDir, g_szMapName);
		AA_Unarchive(g_Filename, iDemoDir, "@fnOnCompleteUnarchive", 0);
	}
}

@fnOnCompleteUnarchive(id, iError) {
	delete_file(g_Filename);

	if(iError == AA_NO_ERROR) {
		format(iNavName, sizeof(iNavName), "%s/%s.nav", iDemoDir, g_ArchivName);
		format(iDemoName, sizeof(iDemoName), "%s/%s.dem", iDemoDir, g_ArchivName);

		server_print("navname: %s, demoname: %s", iNavName, iDemoName);
		if(!file_exists(iNavName)) {
			iFile = fopen(iDemoName, "rb");
			if(iFile) {
				iParsedFile = fopen(iNavName, "w");
				ReadHeaderX();
			}
		}
		else
			LoadParsedInfo(iNavName);

		flStartTime = get_gametime();
	}
	else
		server_print("Failed to unpack. Error code: %d", iError);
}

public cmd_WorldRecord(id) {
	new szText[512], iLen = 0;

	iLen = formatex(szText, charsmax(szText), "%s^n", g_szMapName);

	new recordsInfo[RecordsStruct];
	new szFormattedTime[32];

	for (new i = 0; i < ArraySize(ga_Records); ++i) {
		ArrayGetArray(ga_Records, i, recordsInfo);

		iLen += formatex(szText[iLen], charsmax(szText) - iLen,
			"^n%s", recordsInfo[RecordsTitle]);

		if (!recordsInfo[RecordsTime]) {
			iLen += formatex(szText[iLen], charsmax(szText) - iLen,
				"%L", id, "RECORDS_FMT_NOT_AVAILABLE");
			continue;
		}

		//server_print("%f", recordsInfo[RecordsTime]);

		UTIL_FormatTime(recordsInfo[RecordsTime], szFormattedTime,
			charsmax(szFormattedTime), true);

		if (equal(recordsInfo[RecordsExtension], "")) {
			iLen += formatex(szText[iLen], charsmax(szText) - iLen,
				"%L", id, "RECORDS_FMT",
				recordsInfo[RecordsAuthor], szFormattedTime);
		}
		else {
			iLen += formatex(szText[iLen], charsmax(szText) - iLen,
				"%L", id, "RECORDS_FMT_EXTENSION",
				recordsInfo[RecordsExtension], recordsInfo[RecordsAuthor], szFormattedTime);
		}
	}

	set_hudmessage(255, 0, 255, 0.01, 0.2, _, _, 3.0, _, _, 4);
	show_hudmessage(id, szText);

	return PLUGIN_HANDLED;
}

/**
*	------------------------------------------------------------------
*	Download interfaces
*	------------------------------------------------------------------
*/

public fnDownload(sourceIndex) {
	if (sourceIndex < 0 || sourceIndex >= ArraySize(ga_Sources)) return;

	new source[SourceStruct];
	ArrayGetArray(ga_Sources, sourceIndex, source);

	delete_file(source[RecordsFile]);

	new EzHttpOptions:ezhttpOpt = ezhttp_create_options();

	new szData[1];
	szData[0] = sourceIndex;
	ezhttp_option_set_user_data(ezhttpOpt, szData, sizeof szData);

	ezhttp_get(source[Link], "@fnDownloadOnFinishCallback", ezhttpOpt);
}

@fnDownloadOnFinishCallback(EzHttpRequest:request_id) {
	new szData[1];
	ezhttp_get_user_data(request_id, szData);

	new sourceIndex = szData[0];

	if (ezhttp_get_error_code(request_id) != EZH_OK) {
        new error[64];
        ezhttp_get_error_message(request_id, error, charsmax(error));
        server_print("Response error: %s", error);
    }
	else {
		new source[SourceStruct];
		ArrayGetArray(ga_Sources, sourceIndex, source);

		ezhttp_save_data_to_file(request_id, source[RecordsFile]);
	}

	OnSourceUpdated(sourceIndex);
}

public OnSourceUpdated(sourceIndex) {
	if (sourceIndex < 0 || sourceIndex >= ArraySize(ga_Sources)) return;

	new source[SourceStruct];
	ArrayGetArray(ga_Sources, sourceIndex, source);

	// Parse current
	fnParseInfo(sourceIndex);

	// Update next
	fnDownload(sourceIndex + 1);
}

public fnUpdate() {
	ArrayClear(ga_Records);
	fnDownload(0);
	
	new temp[256];
	get_localinfo("amxx_datadir", temp, 255);
	format(temp, 255, "%s/kz_records/last_update.ini", temp);
	
	new year, month, day;
	date(year, month, day);
	
	if (file_exists(temp)) {
		delete_file(temp);
	}
	
	new f = fopen(temp, "wt");
	format(temp, 255, "%04ix%02ix%02i", year, month, day);
	fputs(f, temp);
	fclose(f);
}

/**
*	------------------------------------------------------------------
*	Sources section
*	------------------------------------------------------------------
*/

public InitSources() {
	ArrayPushArray(ga_Sources, InitXJ());
	ArrayPushArray(ga_Sources, InitCosy());
	ArrayPushArray(ga_Sources, InitKZRush());
}

InitXJ() {
	new data[SourceStruct];

	data[Title] = "XJ";
	data[Link] = "https://xtreme-jumps.eu/demos.txt";
	data[Suffix] = "xj";
	formatex(data[RecordsFile], charsmax(data[RecordsFile]), 
		"%s/demos_xj.txt", g_szWorkDir);
	data[SkipString] = "Xtreme-Jumps.eu";

	return data;
}

InitCosy() {
	new data[SourceStruct];

	data[Title] = "Cosy Climbing";
	data[Link] = "https://cosy-climbing.net/demos.txt";
	data[Suffix] = "cc";
	formatex(data[RecordsFile], charsmax(data[RecordsFile]), 
		"%s/demos_cc.txt", g_szWorkDir);
	data[SkipString] = "www.cosy-climbing.net";

	return data;
}

InitKZRush() {
	new data[SourceStruct];

	data[Title] = "KZ Rush";
	data[Link] = "https://kz-rush.ru/demos.txt";
	data[Suffix] = "ru";
	formatex(data[RecordsFile], charsmax(data[RecordsFile]), 
		"%s/demos_ru.txt", g_szWorkDir);
	data[SkipString] = "kz-rush.ru - International Kreedz Community";

	return data;
}

public fnParseInfo(sourceIndex) {
	if (sourceIndex < 0 || sourceIndex >= ArraySize(ga_Sources)) return;

	new source[SourceStruct];
	ArrayGetArray(ga_Sources, sourceIndex, source);

	if (!file_exists(source[RecordsFile])) return;

	new hFile = fopen(source[RecordsFile], "rt");
	new szData[256];

	new szMap[32], szAuthor[32], szTime[32], szExtension[16];

	new recordsInfo[RecordsStruct];

	formatex(recordsInfo[RecordsTitle], charsmax(recordsInfo[RecordsTitle]), "%s:", source[Title]);

	while (!feof(hFile)) {
		fgets(hFile, szData, charsmax(szData));

		if (equali(szData, source[SkipString])) continue;

		fnParseInterface(szData, source[Suffix], szMap, szAuthor, szTime, szExtension);
		strtolower(szMap);

		if (!equal(szMap, g_szMapName)) continue;

		copy(recordsInfo[RecordsAuthor], charsmax(recordsInfo[RecordsAuthor]), szAuthor);
		recordsInfo[RecordsTime] = str_to_float(szTime);
		copy(recordsInfo[RecordsExtension], charsmax(recordsInfo[RecordsExtension]), szExtension);
		copy(recordsInfo[RecordsSource], charsmax(recordsInfo[RecordsSource]), source[Suffix]);
	}

	ArrayPushArray(ga_Records, recordsInfo);
}

public fnParseInterface(const szData[256], const suffix[], szMap[32], szAuthor[32], szTime[32], szExtension[16]) {
	new szMapWithExt[64], tmp[16];

	if (equal(suffix, "xj")) {
		// map[ext] time nickname country ???
		parse(szData, szMapWithExt, 63, szTime, 31, szAuthor, 31);
	}
	else if (equal(suffix, "cc")) {
		// map[ext] time ??? ??? ??? country nickname
		parse(szData, szMapWithExt, 63, szTime, 31, 
			tmp, 15, tmp, 15, tmp, 15, tmp, 15, 
			szAuthor, 31);
	}
	else if (equal(suffix, "ru")) {
		// map[ext] time nickname country
		parse(szData, szMapWithExt, 63, szTime, 31, szAuthor, 31);
	}

	if (equal(szMapWithExt, "")) return;

	if (containi(szMapWithExt, "[") && containi(szMapWithExt, "[")) {
		strtok2(szMapWithExt, szMap, 31, tmp, 15, '[');
		replace_all(tmp, 15, "]", "");

		copy(szExtension, 15, tmp);
	}
	else {
		copy(szMap, 31, szMapWithExt);
		szExtension = "";
	}
}

public fnConvertTime(Float:time, convert_time[], len) {
	new sTemp[24];
	new Float:fSeconds = time, iMinutes;

	iMinutes = floatround(fSeconds / 60.0, floatround_floor);
	fSeconds -= iMinutes * 60.0;
	new intpart = floatround(fSeconds, floatround_floor);
	new Float:decpart = (fSeconds - intpart) * 100.0;
	intpart = floatround(decpart);

	formatex(sTemp, charsmax(sTemp), "%02i%02.0f.%02d", iMinutes, fSeconds, intpart);
	formatex(convert_time, len, sTemp);
	return PLUGIN_HANDLED;
}

// wr-funcs
#define NUM_THREADS 256

#pragma dynamic 32767

#define PEV_PDATA_SAFE 2

#define OFFSET_TEAM 114
#define OFFSET_DEFUSE_PLANT 193
#define HAS_DEFUSE_KIT (1<<16)
#define OFFSET_INTERNALMODEL 126

public plugin_precache() {
	new i;
	for(i = 0; i < sizeof(g_tButtons); i++)
		g_tButtons[i] = TrieCreate();

	new szStartTargets[][] = {
		"counter_start", "clockstartbutton", "firsttimerelay", "but_start",
		"counter_start_button", "multi_start", "timer_startbutton", "start_timer_emi", "gogogo"
	};

	for(i = 0; i < sizeof szStartTargets ; i++)
		TrieSetCell(g_tButtons[0], szStartTargets[i], i);

	new szFinishTargets[][] = {
		"counter_off", "clockstopbutton", "clockstop", "but_stop",
		"counter_stop_button", "multi_stop", "stop_counter", "m_counter_end_emi"
	};

	for(i = 0; i < sizeof szFinishTargets; i++)
		TrieSetCell(g_tButtons[1], szFinishTargets[i], i);

	new Ent = engfunc(EngFunc_CreateNamedEntity , engfunc(EngFunc_AllocString, "info_target"));
	set_pev(Ent, pev_classname, "BotThink");
	set_pev(Ent, pev_nextthink, get_gametime() + 0.01);
	register_forward(FM_Think, "fwd_Think", 1);
	fPlayerAngle = ArrayCreate(2);
	fPlayerOrigin = ArrayCreate(3);
	fPlayerVelo	= ArrayCreate(3);
	fPlayerKeys	= ArrayCreate(1);
}

public StartCountDown() {
	if(!wr_bot_id)
		wr_bot_id = Create_Bot();

	g_timer = 0;
	set_task(1.0, "Show");
}

public Show() {
	g_timer--;
	set_hudmessage(255, 255, 255, 0.05, 0.2, 0, 6.0, 1.0);

	if(g_timer && g_timer >= 0)
		set_task(1.0, "Show");
	else {
		g_bot_enable = 1;
		Start_Bot();
	}
}

Start_Bot() {
	g_bot_frame = g_bot_start;
	timer_started[wr_bot_id] = false;
}

enum _:Consts {
	HEADER_SIZE = 544,
	HEADER_SIGNATURE_CHECK_SIZE = 6,
	HEADER_SIGNATURE_SIZE = 8,
	HEADER_MAPNAME_SIZE = 260,
	HEADER_GAMEDIR_SIZE = 260,

	MIN_DIR_ENTRY_COUNT = 1,
	MAX_DIR_ENTRY_COUNT = 1024,
	DIR_ENTRY_SIZE = 92,
	DIR_ENTRY_DESCRIPTION_SIZE = 64,

	MIN_FRAME_SIZE = 12,
	FRAME_CONSOLE_COMMAND_SIZE = 64,
	FRAME_CLIENT_DATA_SIZE = 32,
	FRAME_EVENT_SIZE = 84,
	FRAME_WEAPON_ANIM_SIZE = 8,
	FRAME_SOUND_SIZE_1 = 8,
	FRAME_SOUND_SIZE_2 = 16,
	FRAME_DEMO_BUFFER_SIZE = 4,
	FRAME_NETMSG_SIZE = 468,
	FRAME_NETMSG_DEMOINFO_SIZE = 436,
	FRAME_NETMSG_MOVEVARS_SIZE = 32,
	FRAME_NETMSG_MIN_MESSAGE_LENGTH = 0,
	FRAME_NETMSG_MAX_MESSAGE_LENGTH = 65536,
};

enum DemoHeader {
	netProtocol,
	demoProtocol,
	mapName[HEADER_MAPNAME_SIZE],
	gameDir[HEADER_GAMEDIR_SIZE],
	mapCRC,
	directoryOffset
};

enum DemoEntry {
	dirEntryCount,
	type,
	description[DIR_ENTRY_DESCRIPTION_SIZE],
	flags,
	CDTrack,
	trackTime,
	frameCount,
	offset,
	fileLength,
	frames,
	ubuttons
};

enum FrameHeader {
	Type,
	Float:Timestamp,
	Number
};

enum NetMsgFrame {
	Float:timestamp,
	Float:view[3],
	viewmodel
};

new iDemoEntry[DemoEntry];
new iDemoHeader[DemoHeader];
new iDemoFrame[FrameHeader];

public bool:IsValidDemoFile(file) {
	fseek(file, 0, SEEK_END);
	iDemo_header_size = ftell(file);

	if(iDemo_header_size < HEADER_SIZE)
		return false;

	fseek(file, 0, SEEK_SET);
	new signature[HEADER_SIGNATURE_CHECK_SIZE];

	fread_blocks(file, signature, sizeof(signature), BLOCK_CHAR);

	if(!contain("HLDEMO", signature))
		return false;

	return true;
}

public ReadParsed(iEnt) {
	if(iFile) {
		new szLineData[512];
		static sExplodedLine[11][150];
		if(!feof(iFile)) {
			fseek(iFile, 0, SEEK_CUR);
			new iSeek = ftell(iFile);
			fseek(iFile, 0, SEEK_END);
			fseek(iFile, iSeek, SEEK_SET);
			fgets(iFile, szLineData, charsmax(szLineData));
			ExplodeString(sExplodedLine, 10, 50, szLineData, '|');
			if(equal(sExplodedLine[1], "ASD")) {
				new Keys = str_to_num(sExplodedLine[2]);
				new Float:Angles[3];
				Angles[0] = str_to_float(sExplodedLine[3]);
				Angles[1] = str_to_float(sExplodedLine[4]);
				Angles[2] = 0.0;
				new Float:Origin[3];
				Origin[0] = str_to_float(sExplodedLine[5]);
				Origin[1] = str_to_float(sExplodedLine[6]);
				Origin[2] = str_to_float(sExplodedLine[7]);
				new Float:velocity[3];
				velocity[0] = str_to_float(sExplodedLine[8]);
				velocity[1] = str_to_float(sExplodedLine[9]);
				velocity[2] = 0.0;

				ArrayPushArray(fPlayerAngle, Angles);
				ArrayPushArray(fPlayerOrigin, Origin);
				ArrayPushArray(fPlayerVelo, velocity);
				ArrayPushCell(fPlayerKeys, Keys);
			}
			set_pev(iEnt, pev_nextthink, get_gametime() + 0.0001);
			return true;
		}
		else {
			server_print("Finished loading demo in %f sec.", get_gametime() - flStartTime);
			return false;
		}
	}
	return false;
}

public ReadFrames(file) {
	fseek(file, 0, SEEK_CUR);
	new iSeek = ftell(file);
	fseek(file, 0, SEEK_END);
	fseek(iFile, iSeek, SEEK_SET);
	static sum;

	if(!feof(file)) {
		new FrameType = ReadFrameHeader(file);
		new breakme;
		switch(FrameType) {
			case 0: { }
			case 1: {
				new Float:Origin[3], Float:ViewAngles[3], Float:velocity[3], iAsd[1024];
				fseek(file, 4, SEEK_CUR);
				for(new i = 0; i < 3; ++i)
					fseek(file, 4, SEEK_CUR);
				for(new i = 0; i < 3; ++i)
					fread(file, _:ViewAngles[i], BLOCK_INT);
				fseek(file, 64, SEEK_CUR);
				for(new i = 0; i < 3; ++i)
					fread(file, _:velocity[i], BLOCK_INT);
				for(new i = 0; i < 3; ++i)
					fread(file, _:Origin[i], BLOCK_INT);
				fseek(file, 124, SEEK_CUR);
				for(new i = 0; i < 3; ++i)
					fseek(file, 4, SEEK_CUR);
				fseek(file, 4, SEEK_CUR);
				fseek(file, 4, SEEK_CUR);
				fseek(file, 4, SEEK_CUR);
				fseek(file, 2, SEEK_CUR);
				fread(file, iDemoEntry[ubuttons], BLOCK_SHORT);
				format(iAsd, charsmax(iAsd), "%d|ASD|%d|%.4f|%.4f|%.3f|%.3f|%f|%.3f|%.3f|%.3f^n",sum, iDemoEntry[ubuttons], ViewAngles[0], ViewAngles[1], Origin[0],Origin[1],Origin[2], velocity[0], velocity[1], velocity[2]);
				fputs(iParsedFile, iAsd);
				fseek(file, 196, SEEK_CUR);
				new length;
				fread(file, length, BLOCK_INT);
				fseek(file, length, SEEK_CUR);
			}
			case 2: { }
			case 3: {
				new ConsoleCmd[FRAME_CONSOLE_COMMAND_SIZE];
				fread_blocks(file, ConsoleCmd, FRAME_CONSOLE_COMMAND_SIZE, BLOCK_CHAR);
			}
			case 4: {
				sum++;
				for(new i = 0; i < 3; ++i)
					fseek(file, 4, SEEK_CUR);
				for(new i = 0; i < 3; ++i)
					fseek(file, 4, SEEK_CUR);
				fseek(file, 4, SEEK_CUR);
				fseek(file, 4, SEEK_CUR);
			}
			case 5: {
				breakme = 2;
			}
			case 6: {
				fseek(file, 4, SEEK_CUR);
				fseek(file, 4, SEEK_CUR);
				fseek(file, 4, SEEK_CUR);
				fseek(file, 4, SEEK_CUR);
				fseek(file, 4, SEEK_CUR);
				for(new i = 0; i < 3; ++i)
					fseek(file, 4, SEEK_CUR);
				for(new i = 0; i < 3; ++i)
					fseek(file, 4, SEEK_CUR);
				for(new i = 0; i < 3; ++i)
					fseek(file, 4, SEEK_CUR);
				fseek(file, 4, SEEK_CUR);
				fseek(file, 4, SEEK_CUR);
				fseek(file, 4, SEEK_CUR);
				fseek(file, 4, SEEK_CUR);
				fseek(file, 4, SEEK_CUR);
				fseek(file, 4, SEEK_CUR);
				fseek(file, 4, SEEK_CUR);
			}
			case 7: {
				fseek(file, 8, SEEK_CUR);
			}
			case 8: {
				fseek(file, 4, SEEK_CUR);
				new length;
				fread(file, length, BLOCK_INT);
				new msg[128];
				fread_blocks(file, msg, length, BLOCK_CHAR);
				fseek(file, 16, SEEK_CUR);
			}
			case 9: {
				new length = 0;
				fread(file, length, BLOCK_INT);
				new buffer[4];
				fread_blocks(file, buffer, length, BLOCK_BYTE);
			}
			default: {
				breakme = 2;
			}
		}
		if(breakme == 2)
			return true;
	}
	return false;
}

public ReadHeader(file) {
	fseek(file, HEADER_SIGNATURE_SIZE, SEEK_SET);
	fread(file, iDemoHeader[demoProtocol], BLOCK_INT);
	fread(file, iDemoHeader[netProtocol], BLOCK_INT);
	fread_blocks(file, iDemoHeader[mapName], HEADER_MAPNAME_SIZE, BLOCK_CHAR);
	fread_blocks(file, iDemoHeader[gameDir], HEADER_GAMEDIR_SIZE, BLOCK_CHAR);
	fread(file, iDemoHeader[mapCRC], BLOCK_INT);
	fread(file, iDemoHeader[directoryOffset], BLOCK_INT);
	fseek(file, iDemoHeader[directoryOffset], SEEK_SET);

	fread(file, iDemoEntry[dirEntryCount], BLOCK_INT);
	for(new i = 0; i < iDemoEntry[dirEntryCount]; i++) {
		fread(file, iDemoEntry[type], BLOCK_INT);
		fread_blocks(file, iDemoEntry[description], DIR_ENTRY_DESCRIPTION_SIZE, BLOCK_CHAR);
		fread(file, iDemoEntry[flags], BLOCK_INT);
		fread(file, iDemoEntry[CDTrack], BLOCK_INT);
		fread(file, iDemoEntry[trackTime], BLOCK_INT);
		fread(file, iDemoEntry[frameCount], BLOCK_INT);
		fread(file, iDemoEntry[offset], BLOCK_INT);
		fread(file, iDemoEntry[fileLength], BLOCK_INT);
	}

	fseek(file, iDemoEntry[offset], SEEK_SET);
}

public LoadParsedInfo(szNavName[]) {
	iFile = fopen(szNavName, "rb");
	new Ent = engfunc(EngFunc_CreateNamedEntity , engfunc(EngFunc_AllocString, "info_target"));
	set_pev(Ent, pev_classname, "NavThink");
	set_pev(Ent, pev_nextthink, get_gametime() + 0.01);
}

public ReadHeaderX() {
	if(IsValidDemoFile(iFile)) {
		ReadHeader(iFile);
		new Ent = engfunc(EngFunc_CreateNamedEntity , engfunc(EngFunc_AllocString, "info_target"));
		set_pev(Ent, pev_classname, "DemThink");
		set_pev(Ent, pev_nextthink, get_gametime() + 0.01);
	}
	else
		server_print("demo is not valid!");
}

public Ham_ButtonUse(id) {
	new Float:origin[3];
	pev(id, pev_origin, origin);
	new ent = -1;
	while((ent = find_ent_in_sphere(ent, origin, 100.0)) != 0) {
		new classname[32];
		pev(ent, pev_classname, classname, charsmax(classname));

		new Float:eorigin[3];
		get_brush_entity_origin(ent, eorigin);
		static Float:Distance[2];
		new szTarget[32];
		pev(ent, pev_target, szTarget, 31);

		if(TrieKeyExists(g_tButtons[0], szTarget)) {
			if(g_bot_start < 0)
				g_bot_start = 0;

			if(vector_distance(origin, eorigin) >= Distance[0]) {
				timer_time[id] = get_gametime();
				IsPaused[id] = false;
				timer_started[id] = true;
				bot_finish_use[id] = false;
			}
			Distance[0] = vector_distance(origin, eorigin);
		}
		if(TrieKeyExists(g_tButtons[1], szTarget)) {
			if(vector_distance(origin, eorigin) >= Distance[1]) {
				if(!bot_finish_use[id]) {
					if(timer_started[id])
						Start_Bot();
					timer_started[id] = false;
					bot_finish_use[id] = true;
				}
			}
			Distance[1] = vector_distance(origin, eorigin);
		}
	}
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ TIMER ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
public timer_task(iTimer) {
	new Dead[32], deadPlayers;
	get_players(Dead, deadPlayers, "bh");
	for(new i = 0; i < deadPlayers; i++) {
		new specmode = pev(Dead[i], pev_iuser1);
		if(specmode == 2 || specmode == 4) {
			new target = pev(Dead[i], pev_iuser2);
			if(is_user_alive(target)) {
				if(timer_started[target] && target == wr_bot_id) {
					new Float:kreedztime = get_gametime() - (IsPaused[target] ? get_gametime() - g_pausetime[target] : timer_time[target]);
					new imin = floatround(kreedztime / 60.0, floatround_floor);
					new isec = floatround(kreedztime - imin * 60, floatround_floor);
					new mili = floatround((kreedztime - (imin * 60 + isec)) * 100, floatround_floor);
					if(get_pcvar_num(timer_option) == 1) {
						client_print(Dead[i], print_center, "[ %02i:%02i.%02i | HP: Godmode | 10aa ]", imin, isec, mili, IsPaused[target] ? "| *Paused*" : "");
					}
					else if(get_pcvar_num(timer_option) == 2) {
						set_hudmessage(255, 255, 255, -1.0, 0.35, 0, 0.0, 1.0, 0.0, 0.0);
						ShowSyncHudMsg(Dead[i], SyncHudBotTimer, "[ %02i:%02i.%02i | HP: Godmode | 10aa ]", imin, isec, mili, IsPaused[target] ? "| *Paused*" : "");
					}
				}
				else if(!timer_started[target] && target == wr_bot_id) {
					client_print(Dead[i], print_center, "");
				}
			}
		}
	}

	entity_set_float(iTimer, EV_FL_nextthink, get_gametime() + 0.07)
}

public Pause() {
	if(!IsPaused[wr_bot_id]) {
		g_pausetime[wr_bot_id] = get_gametime() - timer_time[wr_bot_id];
		timer_time[wr_bot_id] = 0.0;
		IsPaused[wr_bot_id] = true;
		g_bot_enable = 2;
	}
	else {
		if(timer_started[wr_bot_id]) {
			timer_time[wr_bot_id] = get_gametime() - g_pausetime[wr_bot_id];
		}
		IsPaused[wr_bot_id] = false;
		g_bot_enable = 1;
	}
}

public fwd_Think(iEnt) {
	if(!pev_valid(iEnt))
		return(FMRES_IGNORED);

	static className[32];
	pev(iEnt, pev_classname, className, 31);

	if(equal(className, "DemThink")) {
		static bool:Finished;
		for(new i = 0; i < NUM_THREADS; i++) {
			if(ReadFrames(iFile)) {
				Finished = true;
				break;
			}
		}

		if(Finished) {
			set_pev(iEnt, pev_flags, pev(iEnt, pev_flags) | FL_KILLME);
			fclose(iFile);

			LoadParsedInfo(iNavName);
		}
		else
			set_pev(iEnt, pev_nextthink, get_gametime() + 0.001);
	}
	if(equal(className, "NavThink")) {
		static bool:Finished;
		for(new i = 0; i < NUM_THREADS; i++) {
			if(!ReadParsed(iEnt)) {
				Finished = true;
				break;
			}
		}

		if(Finished) {
			set_pev(iEnt, pev_flags, pev(iEnt, pev_flags) | FL_KILLME);
			delete_file(iNavName);
			set_task(2.0, "StartCountDown");
		}
	}

	if(equal(className, "kz_time_think")) {
		timer_task(1);
		set_pev(iEnt, pev_nextthink, get_gametime() + 0.08);
	}

	if(equal(className, "BotThink")) {
		BotThink(wr_bot_id);
		set_pev(iEnt, pev_nextthink, get_gametime() + nExttHink);
	}

	return(FMRES_IGNORED);
}

public BotThink(id) {
	static Float:ViewOrigin[3], Float:ViewAngle[3], Float:ViewVelocity[3], ViewKeys;
	static Float:last_check, Float:game_time, nFrame;
	game_time = get_gametime();

	if(game_time - last_check > 1.0) {
		if(nFrame < 100)
			nExttHink = nExttHink - 0.0001;
		else if(nFrame > 100)
			nExttHink = nExttHink + 0.0001;

		nFrame = 0;
		last_check = game_time;
	}

	if(g_bot_enable == 1 && wr_bot_id) {
		g_bot_frame++;
		if(g_bot_frame < ArraySize(fPlayerAngle)) {
			ArrayGetArray(fPlayerOrigin, g_bot_frame, ViewOrigin);
			ArrayGetArray(fPlayerAngle, g_bot_frame, ViewAngle);
			ArrayGetArray(fPlayerVelo, g_bot_frame, ViewVelocity);
			ViewKeys = ArrayGetCell(fPlayerKeys, g_bot_frame);

			if(ViewKeys&IN_ALT1) ViewKeys|=IN_JUMP;
			if(ViewKeys&IN_RUN)	ViewKeys|=IN_DUCK;

			if(ViewKeys&IN_RIGHT) {
				engclient_cmd(id, "weapon_usp");
				ViewKeys&=~IN_RIGHT;
			}
			if(ViewKeys&IN_LEFT) {
				engclient_cmd(id, "weapon_knife");
				ViewKeys&=~IN_LEFT;
			}
			if(ViewKeys & IN_USE) {
				Ham_ButtonUse(id);
				ViewKeys &= ~IN_USE;
			}

			engfunc(EngFunc_RunPlayerMove, id, ViewAngle, ViewVelocity[0], ViewVelocity[1], 0.0, ViewKeys, 0, 10);
			set_pev(id, pev_v_angle, ViewAngle);
			ViewAngle[0] /= -3.0;
			set_pev(id, pev_velocity, ViewVelocity);
			set_pev(id, pev_angles, ViewAngle);
			set_pev(id, pev_origin, ViewOrigin);
			set_pev(id, pev_button, ViewKeys );

			if(pev(id, pev_gaitsequence) == 4 && ~pev(id, pev_flags) & FL_ONGROUND)
				set_pev(id, pev_gaitsequence, 6);

			if(nFrame == ArraySize(fPlayerAngle) - 1)
				Start_Bot();
		}
		else
			g_bot_frame = 0;
	}
	nFrame++;
}

Create_Bot() {
	new txt[64]
	formatex(txt, charsmax(txt), "[%s] %s %s (%s)", WR_SRC, WR_NAME, WR_TIME, WR_COUNTRY);
	new id = engfunc(EngFunc_CreateFakeClient, txt);
	if(pev_valid(id)) {
		set_user_info(id, "model", "gordon");
		set_user_info(id, "rate", "3500");
		set_user_info(id, "cl_updaterate", "30");
		set_user_info(id, "cl_cmdrate", "60");
		set_user_info(id, "cl_lw", "0");
		set_user_info(id, "cl_lc", "0");
		set_user_info(id, "cl_dlmax", "128");
		set_user_info(id, "cl_righthand", "0");
		set_user_info(id, "ah", "1");
		set_user_info(id, "dm", "0");
		set_user_info(id, "tracker", "0");
		set_user_info(id, "friends", "0");
		set_user_info(id, "*bot", "1");
		set_user_info(id, "_cl_autowepswitch", "1");
		set_user_info(id, "_vgui_menu", "0");
		set_user_info(id, "_vgui_menus", "0");

		static szRejectReason[128];
		dllfunc(DLLFunc_ClientConnect, id, "WR BOT", "127.0.0.1" , szRejectReason);
		if(!is_user_connected(id)) {
			server_print("Connection rejected: %s", szRejectReason);
			return 0;
		}

		dllfunc(DLLFunc_ClientPutInServer, id);
		set_pev(id, pev_spawnflags, pev(id, pev_spawnflags) | FL_FAKECLIENT);
		set_pev(id, pev_flags, pev(id, pev_flags) | FL_FAKECLIENT);

		cs_set_user_team(id, CS_TEAM_CT);
		cs_set_user_model(id, "sas");
		cs_set_user_bpammo(id, CSW_USP, 250);

		cs_user_spawn(id);
		give_item(id, "weapon_knife");
		give_item(id, "weapon_usp");
		set_user_godmode(id, 1);

		return id;
	}
	return 0;
}

public ReadFrameHeader(file) {
	fread(file, iDemoFrame[Type], BLOCK_BYTE);
	fread(file, _:iDemoFrame[Timestamp], BLOCK_INT);
	fread(file, iDemoFrame[Number], BLOCK_INT);

	return(iDemoFrame[Type]);
}

public ExplodeString(p_szOutput[][], p_nMax, p_nSize, p_szInput[], p_szDelimiter) {
	new nIdx = 0, l = strlen(p_szInput);
	new nLen = (1 + copyc(p_szOutput[nIdx], p_nSize, p_szInput, p_szDelimiter));
	while((nLen < l) && (++nIdx < p_nMax))
		nLen += (1 + copyc(p_szOutput[nIdx], p_nSize, p_szInput[nLen], p_szDelimiter));
	return(nIdx);
}