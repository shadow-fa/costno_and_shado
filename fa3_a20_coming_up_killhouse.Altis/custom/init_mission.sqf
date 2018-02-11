
//------------------------------------------------------------------------------
[] call compile preprocessFileLineNumbers "custom\functions.sqf";
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
/*
player allowDamage false;
removeBackpack player;
player addBackpack "B_AssaultPack_blk";

TODO defuse kit?
TODO FUTURE: defusers shouldnt be able to pick up backpack.
TODO rounds. no cas cap, no calling of mp_end, what about damage from bomb? damaged killhouses, etc
TODO scoretable:
	blufor 2 : 1 opfor
	1 - blufor (CT)
	2 - blufor (T)
	3 - opfor (T)

*/
//------------------------------------------------------------------------------
//SETTINGS:
private _spawn_object_types = ["CAManBase"]; //needs to be an array

//private bombsites_at_objective = [bombsite,bombsite_1,...];
bombsites_at_objective = ["bombsite"] call ws_fnc_collectObjectsNum;

private _wall_types = ["Land_Shoot_House_Wall_F"]; //for drawing walls when f_param_show_walls is 1

timeout = 20; //for loading into the mission
safestart_timer = 5;
//------------------------------------------------------------------------------
//server setup
if(isServer)then{
	f_param_show_walls        = 0;
	//this parameter might be overwritten by the objective-marker-text!
	//because it doesn't make sense for construction sites with multiple levels

	//get objective from parameter + config
	private _mission_params = (missionconfigfile >> "params") call bis_Fnc_returnchildren;
	private _param = _mission_params select (_mission_params apply {configname _x == "f_param_objective"} find true);
	private _objectives = (getArray (_param >> "markernames")) select [1,100];
	objective = selectRandom _objectives;
	if(f_param_objective != 0)then{
		objective = _objectives select (f_param_objective-1);
	};
	//Also get the text for the briefing
	objective_text = (getArray (_param >> "texts")) select ((getArray (_param >> "markernames")) find objective);
	//--------------------------------------------------------------------------
	//Filter bombsites based on selected objective
	bombsites_at_objective = bombsites_at_objective select {_x inArea objective};
	//--------------------------------------------------------------------------
	//disable spawn-helper-units
	{
		_x disableAI "MOVE";
		_x disableAI "ALL";
	} forEach allUnits; //(allUnits - playableUnits)
	//--------------------------------------------------------------------------
	//set up player variables
	players = [];
	private _players_blu = playableUnits select {side _x == BLUFOR};
	private _players_red = playableUnits select {side _x == OPFOR };
	players append _players_blu;
	players append _players_red;
	//get objective and objective data
	private _o_pos  = getMarkerPos objective;
	private _o_size = ((getMarkerSize objective)select 0) max ((getMarkerSize objective)select 1);
	//setting up player positions
	private _o_man  = (nearestObjects [_o_pos, _spawn_object_types, _o_size]) - players;
	private _o_men_blu = _o_man select {side _x == BLUFOR};
	private _o_men_red = _o_man select {side _x == OPFOR };
	if((count _players_blu > count _o_men_blu) || (count _players_red > count _o_men_red))exitWith{systemChat "ERROR 4: not enough spawnpoints"; 0};
	o_spawnpoints = [];
	o_spawnpoints append (_o_men_blu select [0, count _players_blu]);
	o_spawnpoints append (_o_men_red select [0, count _players_red]);
	o_spawnpoints = o_spawnpoints apply {[getPosATL _x, getDir _x]};
	{deleteVehicle _x;} forEach _o_man; //deleting helper objects to avoid getting stuck in them.
	if(count players == 0)exitWith{systemChat "ERROR 5. Script needs to run in multiplayer mode.";0};
	if(count o_spawnpoints != count players)exitWith{systemChat "ERROR 1. There have to be the same number of playableUnits as there are spawn positions";0};

	//"remove" objective markers
	{_x setMarkerAlpha 0} forEach _objectives; //(_objectives-[objective])

	//execute marker-text (e.g. so that it can set f_param_show_walls)
	call compile (markerText objective);

	//create spawn marker
	if(f_param_show_spawn == 1)then{
		private _marker_spawn_opfor  = createMarker ["marker_spawn_opfor",  _o_men_red select 0];
		private _marker_spawn_blufor = createMarker ["marker_spawn_blufor", _o_men_blu select 0];
		_marker_spawn_opfor  setMarkerColor "ColorEAST";
		_marker_spawn_blufor setMarkerColor "ColorWEST";
		_marker_spawn_opfor  setMarkerType "mil_start";
		_marker_spawn_blufor setMarkerType "mil_start";
		_marker_spawn_opfor  setMarkerText "OPFOR spawn";
		_marker_spawn_blufor setMarkerText "BLUFOR spawn";
	};

	//create marker for walls:
	if(f_param_show_walls == 1)then{
		private _walls = nearestObjects [_o_pos, _wall_types, _o_size];
		private "_m";
		{
			//deleteMarker (str _x);
			_m = createMarker [str _x, _x];
			_m setMarkerShape "Rectangle";
			_m setMarkerSize [1, 0.1];
			_m setMarkerDir getDir _x;
		}forEach _walls;
	};

	//create marker for bombsites
	[bombsites_at_objective] call fnc_bombSiteMarkers;

	//move all AI that aren't players yet
	[] spawn {
		sleep 2;
		{
			if( !(isPlayer _x) )then{
				[_x] call fnc_setPlayerPos;
			};
		} forEach players;
	};

	//setup done
	server_setup_done = true;
	publicVariable "objective";
	publicVariable "objective_text";
	publicVariable "bombsites_at_objective";
	publicVariable "players";
	publicVariable "o_spawnpoints";
	publicVariable "server_setup_done";


	//mission start timer
	[] spawn {
		//disable simulation
		{
			_x enableSimulationGlobal false;
			_x allowDamage false;
		} forEach players;

		//wait for all players to have teleported
		waitUntil {sleep 0.05; ( time > timeout || {_x getVariable ["playerMoved",  false]} count playableUnits == count playableUnits )};
		waitUntil {sleep 0.05; ( time > timeout || {_x getVariable ["playerLoaded", false]} count playableUnits == {isPlayer _x} count playableUnits )};

		serverStartTime = serverTime + safestart_timer;
		publicVariable "serverStartTime";
		
		//client timer will start now
		
		//wait
		waitUntil{ uiSleep 0.05; serverTime > serverStartTime };
		
		//re-enable simulation
		{
			_x enableSimulationGlobal true;
			_x allowDamage true;
		} forEach players;
	};
};

//------------------------------------------------------------------------------

//client setup: just calling fnc_setPlayerPos basically
if(hasInterface)then{
	[] spawn {
		waitUntil {!(isNull (findDisplay 46))};
		waitUntil {!isNull player && {player == player}};
		waitUntil {sleep 0.05; (time > 0)};
		//startLoadingScreen ["Loading"]; //NOTE: only use uiSleep within the loading screen!

		waitUntil {!isNil "server_setup_done"};
		waitUntil {!(isNull (findDisplay 46))};
		waitUntil {(time > 0.1)};

		handle_setPos = [] spawn fnc_setPlayerPosLoopClient;
		[] spawn fnc_addActions;
		[] spawn fnc_missionStartTimer;
		waitUntil { scriptDone handle_setPos };

		waitUntil {( time > timeout || {! (cursorObject isEqualTo objNull) || {! ((getCursorObjectParams select 0) isEqualTo objNull)}})};

		player setVariable ["playerLoaded", true, true];

		//waitUntil {uiSleep 0.05; ( time > 20 || {_x getVariable ["playerMoved", false]} count playableUnits == count playableUnits )};
		//endLoadingScreen;
	};
};

0
