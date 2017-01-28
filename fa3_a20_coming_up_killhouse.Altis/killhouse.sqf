/*
player allowDamage false;
removeBackpack player;
player addBackpack "B_AssaultPack_blk";

TODO f3: briefing, gear
TODO give backpack to 1 side?
TODO eden description, mp description
TODO defuse kit?
TODO FUTURE or just write in briefing: defusers shouldnt be able to pick up backpack.


changes since vt2:
* distance2d to distance in bombs.sqf
* multiple bombsite marker per bombsite (for helipad) (also changed sqm file (multiple helipad bombsite markers +  below ground) )
* loading screen until everyone is loaded

*/
//------------------------------------------------------------------------------
//SETTINGS:
private _spawn_object_types = ["CAManBase"]; //needs to be an array

//private _bombsites = [bombsite,bombsite_1,...];
private _bombsites = ["bombsite"] call ws_fnc_collectObjectsNum;

private _wall_types = ["Land_Shoot_House_Wall_F"]; //for drawing walls when f_param_show_walls is 1
//------------------------------------------------------------------------------
fnc_setPlayerPos = {
	params ["_player"];

	private _player_index = players find _player;
	if( _player_index == -1 )exitWith{systemChat format ["ERROR 2. You (%1) are not a player. Or you're a JIP player?",name _player];0};
	private _spawnpoint = o_spawnpoints select _player_index;

	_player setPos (_spawnpoint select 0);
	_player setDir (_spawnpoint select 1);

	sleep 0.05; //to be on the safe side
	if( (getPos _player) distance2d (_spawnpoint select 0) < 5 )then{
		_player setVariable ["playerMoved", true, true];
	};
};
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
	//--------------------------------------------------------------------------
	//disable spawn-helper-units
	{
		_x disableAI "MOVE";
		_x disableAI "ALL";
	} forEach allUnits; //(allUnits - playableUnits)

	//set up player variables
	players = [];
	private _players_blu = playableUnits select {side _x == BLUFOR};
	private _players_red = playableUnits select {side _x == OPFOR };
	players append _players_blu;
	players append _players_red;
	//get objective and objective data
	private _o_pos  = getMarkerPos objective;
	private _o_size = ((getMarkerSize objective)select 0) max ((getMarkerSize objective)select 0);
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

	//"remove" objective marker
	{_x setMarkerAlpha 0} forEach (_objectives-[objective]);

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


	//setup done
	server_setup_done = true;
	publicVariable "objective";
	publicVariable "players";
	publicVariable "o_spawnpoints";
	publicVariable "server_setup_done";

	//move all AI that aren't players yet
	//maybe we don't want this: e.g. reinforcements?
	[] spawn {
		sleep 2;
		{
			if( !(isPlayer _x) )then{
				[_x] call fnc_setPlayerPos;
			};
		} forEach players;
	};
};

//------------------------------------------------------------------------------
//call before waitUntil/sleep... because we want this code to be executed earlier (on the map screen before loading in)
_bombsites_at_objective = [];
{
	if(_x inArea objective)then{_bombsites_at_objective pushBack _x};
} forEach _bombsites;
[_bombsites_at_objective] call compile preprocessFileLineNumbers "bombs.sqf";
//------------------------------------------------------------------------------

//client setup: just calling fnc_setPlayerPos basically
if(hasInterface)then{
	waitUntil {sleep 0.1; (time > 0)};
	startLoadingScreen ["Loading"];

	waitUntil {/*sleep 0.1;*/ !isNil "server_setup_done"};
	waitUntil {/*sleep 0.1;*/ server_setup_done};
	waitUntil {/*sleep 0.1;*/ (time > 0.2)};

	//not sure this elaborate mechanism is needed.
	//But setPos only works if player actually is loaded in. (maybe time > 0.1 would be enough)
	private _sleep_time = 0.5;
	private _timeout = (2*60)/_sleep_time;
	private _i = 0;
	while {_i < _timeout && !(player getVariable ["playerMoved", false])  } do {
		[player] call fnc_setPlayerPos;
		sleep _sleep_time;
		_i = _i + 1;
		if(_i == 30)exitWith{
			systemChat format ["ERROR 6: Can't setPos for player %1 for some reason.", name player];
			0
		};
	};

	//need to use uIsleep within loadingScreen
	waitUntil {uiSleep 0.05; ( time > 20 || {_x getVariable ["playerMoved", false]} count playableUnits == count playableUnits )};
	endLoadingScreen;
};

0