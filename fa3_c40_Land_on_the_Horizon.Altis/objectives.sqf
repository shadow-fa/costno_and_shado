/*
f_param_debugMode                = 1;
f_param_fakemarkers              = 0;
f_param_number_of_objectives     = 0;
f_param_objectives_configuration = 2;
call compile preprocessFileLineNumbers "objectives.sqf";

x=subgraphs apply {count _x};x sort true;[[x select 0, x select (count x -1)],count x,x]

NOTE: if you want "things" to refresh, call this before executing this script: things = nil;
things = potential objectives

TODO: delete unused caches

*/
//------------------------------------------------------------------------------
//SETTINGS
private _marker_prefix        = "marker_cache";
private _color_objectives     = "ColorEAST";
private _color_debug_nodes    = "ColorBlack"; //ColorWEST
private _debug                = f_param_debugMode;
private _number_of_objectives = f_param_number_of_objectives;
private _fakemarker           = f_param_fakemarkers;
private _configurations       = [
//    /------------------------------ MIN distance between objectives
//    |       /---------------------- MAX distance between objectives
//    |       |        /------------- max dist from centroid
//    |       |        |           /- max sum(dist from centroid)
//    v       v        v           V
	[ 1000,   9000,  9000*2.0,  9000*50.0], //up to   13 objectives (incl fake markers) possible. (pretty much all across the area)
	[  950,   5000,  5000*1.0,  6000*16.0], //up to 9-10 objectives (incl fake markers) possible.
	[    0,    700,   700*1.0,  1000*1.0],  //walking distance. up to 4 objectives (incl fake markers) possible.

	//below are some other configurations for testing purposes
	[ 1000,  10000, 10000*1.0, 10000*10.0], //
	[  100,   3000,  3000*1.0,  3000*4.0],  //
	[0,0,0,0]

	//DO NOT ADD CONFIGURATIONS HERE WITHOUT EXTENSIVELY TESTING THEM (e.g. by PLOTTING ALL SUBGRAPH CONNECTIONS)!
	//because the used algorithm is quite shitty and sometimes you won't get any result when changing some numbers
	//be aware: some parts of the algorithm are randomized.
];
private _config = _configurations select f_param_objectives_configuration;
private _min_distance_between_objectives = _config select 0;
private _max_distance_between_objectives = _config select 1;
private _max_distance_from_centroid      = _config select 2;
private _max_distance_from_centroid_sum  = _config select 3;

//------------------------------------------------------------------------------
//FUNCTIONS
//------------------------------------------------------------------------------
fnc_distances_to_mean = {
	params ["_objects","_indices"];
	private _num = count _indices;
	private _mean = [0,0,0];

	{
		private _pos = getPos (_objects select _x);
		_mean = _mean vectorAdd _pos;
	} forEach _indices;
	_mean = _mean vectorMultiply (1/_num);
	private _distances_to_mean = _indices apply { _mean distance (getPos (_objects select _x)) };

	_distances_to_mean
};
//------------------------------------------------------------------------------
fnc_adjacency_matrix = {
	params ["_objects","_max_dist"];
	private _adjacency_matrix = [];
	{
		private _obj1 = _x;
		private _obj1_array = [];
		{
			private _dist = _obj1 distance _x;
			_obj1_array pushBack ( [0, _dist] select ( _dist < _max_dist ) );
		} forEach _objects;
		_adjacency_matrix pushBack _obj1_array;
	} forEach _objects;

	_adjacency_matrix
};
//------------------------------------------------------------------------------
call compile preprocessFileLineNumbers "common.sqf";
//END of function declarations
//------------------------------------------------------------------------------
//clear all markers
{deleteMarker _x;} forEach ([_marker_prefix] call ws_fnc_collectMarkers);
//------------------------------------------------------------------------------
//find all things/objectives
//things = nil;
//things is global for debugging
if (isNil "things") then {
	//_pos = getArray(configFile >> "CfgWorlds" >> "Altis" >> "centerPosition");
	//_radius = _pos; _radius sort false; _radius = (_radius select 0) * (sqrt 2);
	things = nearestObjects [[25000,22000,0], ["I_supplyCrate_F"], 4500];
	//things = [cache] call ws_fnc_collectObjectsNum; //wont work in editor
};
if ( isNil "things" || (count things) == 0) exitWith {systemChat "No things found"; 0};

//------------------------------------------------------------------------------
//marker for all things
if (_debug > 0) then {
	{
		[_x, _marker_prefix, "thing", "mil_box", _color_debug_nodes, [1,1], 1.0, 0, format [" %1", _forEachIndex]] call fnc_marker;
	} forEach things;
};
//------------------------------------------------------------------------------
//connections between objectives
private _adjacency_matrix = ([things, _max_distance_between_objectives] call fnc_adjacency_matrix);
//------------------------------------------------------------------------------
//get subgraphs
private _t1 = diag_tickTime;
private _subgraphs = [];
{
	private _starting_node = _forEachIndex;
	private _subgraph = [];
	_subgraph pushBack _starting_node;
	{
		if (_x > 0) then {
			_subgraph pushBack _forEachIndex;
		};
	} forEach (_x);

	//remove nodes that are too far away from the center of the subgraph
	private _done = false;
	while {! _done} do {
		private _distances_to_mean = [things, _subgraph] call fnc_distances_to_mean;
		private _sum       =  0;
		private _max       = -1;
		private _max_index = -1;
		{
			//dont remove the starting_node!
			if (_x > _max && _subgraph select _forEachIndex != _starting_node) then {
				_max = _x;
				_max_index = _forEachIndex;
			};
			_sum = _sum + _x;
		} forEach _distances_to_mean;

		if (_max >= _max_distance_from_centroid || _sum > _max_distance_from_centroid_sum) then {
			_subgraph deleteAt _max_index;
		} else {
			_done = true;
		}
	};

	//remove nodes if they're too close to each other. (after removing nodes that are too far off center)
	_done = false;
	while {! _done} do {
		//_distances_to_mean = [things, _subgraph] call fnc_distances_to_mean;
		_done = true;
		private _to_be_removed = nil;
		{
			private _node1 = _x;
			//_node1_index = _forEachIndex; //does only work if we don't remove things within this loop
			{
				private _node2 = _x;
				//_node2_index = _forEachIndex;
				if (_node1 != _node2 && ((_adjacency_matrix select _node1) select _node2) < _min_distance_between_objectives) then {
					//if (_distances_to_mean select _node1_index > _distances_to_mean select _node2_index) then {
					//	_to_be_removed = _node1;
					//	_done = false;
					//} else {
					//	_to_be_removed = _node2;
					//	_done = false;
					//};
					_to_be_removed = selectRandom [_node1, _node2];
					_done = false;
				};
				if (!_done) exitWith {};
			} forEach _subgraph;
			if (!_done) exitWith {};
		} forEach _subgraph;

		if (!isNil "_to_be_removed") then {
			_subgraph = _subgraph - [ _to_be_removed ];
		};
	};

	_subgraphs pushBack _subgraph;
} forEach _adjacency_matrix; // time: O(n^3)
if (_debug > 0) then {
	debug_time = diag_tickTime - _t1;
};
//------------------------------------------------------------------------------
//remove duplicate subgraphs
{_x sort true} forEach _subgraphs;
{_subgraphs = _subgraphs - [_x]; _subgraphs pushBack _x} forEach _subgraphs;

//remove duplicate subsets e.g. [1,3] will be removed if there is also [1,2,3]
//NOTE this relies on the fact, that the array doesnt contain any exact duplicates.
{
	private _a = _x;
	//private _is_subgraph = false;
	{
		private _b = _x;
		if ( (!(_a isEqualTo _b)) && (({_x in _b} count _a) == count _a) ) exitWith {
			//_is_subgraph = true;
			_subgraphs = _subgraphs - [_a];
		};
	} forEach _subgraphs;
	//if (_is_subgraph) then {
	//	_subgraphs = _subgraphs - [_a];
	//};
} forEach _subgraphs;
//------------------------------------------------------------------------------
private _num_obj_incl_fake = _number_of_objectives + _fakemarker; //_fakemarker should be "1"
//remove subgraphs that don't have enough nodes
private _max_subgraph_size = -1;
{
	_max_subgraph_size = (count _x) max _max_subgraph_size
} forEach _subgraphs;

_num_obj_incl_fake = _num_obj_incl_fake min _max_subgraph_size;
//remove all smaller subgraphs
_subgraphs = _subgraphs select {count _x >= _num_obj_incl_fake};
//------------------------------------------------------------------------------
//mark all possible sets
if (_debug > 0) then {
	{
		private _subgraph_index = _forEachIndex;
		private _graph = _subgraphs select _subgraph_index;
		{
			private _pos = position (things select _x);
			private _dist = 30;//100
			_pos = _pos getPos [_dist, 360/(count _subgraphs)*_subgraph_index];
			private _color = dbg_colors select (_subgraph_index % (count dbg_colors));

			[_pos, _marker_prefix, format ["graph_%1", _subgraph_index], "mil_dot", _color] call fnc_marker;

			private _x1 = _x;
			{
				if (_x1 != _x) then {
					private _pos2 = (things select _x) getPos [_dist, 360/(count _subgraphs)*_subgraph_index];
					[_marker_prefix, _pos, _pos2, _color,5,false] call fnc_draw_line;
				};
			} forEach _graph;
		} forEach _graph;
	} forEach _subgraphs;
};
//------------------------------------------------------------------------------
//select random subgraph
//NOTE: from here on we ignore _subgraphs and only use _nodes_selected
//_nodes_selected will also contain the fake markers

//NOTE: "+"" to make sure we don't change the original array in case we still need it
private _nodes_selected = +(selectRandom _subgraphs);

if (_fakemarker > 0) then {
	//_num_obj_incl_fake = _number_of_objectives + (selectRandom [1,2]);
	_num_obj_incl_fake = (_number_of_objectives + 2) min (count _nodes_selected);
};
//remove nodes until _number_of_objectives (or _num_obj_incl_fake)

//shuffle, so that we don't always remove the same nodes
_nodes_selected = _nodes_selected call BIS_fnc_arrayShuffle;
_nodes_selected resize _num_obj_incl_fake;

//nodes without fake
private _nodes_selected_no_fake = +_nodes_selected; //"+" because we still need the original array intact
_nodes_selected_no_fake resize _number_of_objectives;
//nodes: only fake
private _nodes_selected_fake = _nodes_selected select [_number_of_objectives, count _nodes_selected - _number_of_objectives];
//------------------------------------------------------------------------------
//mark selected nodes
{
	private _objective = things select _x;
	systemChat str [_objective, _x, _nodes_selected];
	//mark node
	private _marker = [_objective, _marker_prefix, "objectives", "mil_objective", _color_objectives] call fnc_marker;
	if ((_debug > 0) && (_x in _nodes_selected_fake)) then {
		_marker setMarkerColor "ColorCIV";
		_marker setMarkerText "fake";
	};

	_objective setVariable ["marker_name", _marker, true]; //to change the marker later
	_objective setVariable ["index", _forEachIndex, true]; //used for damage handler
} forEach _nodes_selected;
//------------------------------------------------------------------------------
if (_debug > 0) then {
	subgraphs = _subgraphs;
} else {
	_subgraphs = nil;
	_adjacency_matrix = nil;
};
//------------------------------------------------------------------------------
//select things with indices in _nodes_selected
_objectives = _nodes_selected_no_fake apply {things select _x};

//remove unused caches
if(!is3DEN) then {
	_things_to_delete = +things;
	_things_to_delete = _things_to_delete - _objectives;
	{deleteVehicle _x;} forEach _things_to_delete;
};
//RETURN objectives (without fake markers)
_objectives
//------------------------------------------------------------------------------
