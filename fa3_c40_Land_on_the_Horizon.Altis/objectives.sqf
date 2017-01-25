/*
f_param_debugMode                = 1;
f_param_fakemarkers              = 0;
f_param_number_of_objectives     = 3;
f_param_objectives_configuration = 3;
f_param_clusters                 = 1;
call compile preprocessFileLineNumbers "objectives.sqf";
//------------------------------------------------------------------------------
if you want "things" (things = potential objectives = caches) to refresh,
call this before executing this script: things = nil;


max-distances for each subgraph, sorted:
x=(subgraphs apply {_m = 0; _s=_x;{_y=_x;{_m2 = round((things select _y) distance2d (things select _x));if(_m2>_m)then{_m=_m2};}forEach _s}forEach _s;_m});x sort true; x
//------------------------------------------------------------------------------
TODO: currently we only check _max_distance_between_objectives from the
      starting node. not from each node to every other node.

TODO: proper centroids? (probably not necessary)
	1. convex hull (graham scan?)
	2. https://en.wikipedia.org/wiki/Centroid#Centroid_of_polygon

*/
//------------------------------------------------------------------------------
//SETTINGS
private _marker_prefix        = "marker_cache";
private _color_objectives     = "ColorEAST";
private _color_debug_nodes    = "ColorBlack"; //ColorWEST
private _debug                = f_param_debugMode; //1,2,3,4 2 = mark all subgraphs, 3 = always lines, 4 = no objective markers
private _num_objectives       = f_param_number_of_objectives;
private _fakemarker           = f_param_fakemarkers; //0 or 1
private _clusters             = f_param_clusters max 1; //has to be >= 1
private _cluster_dist         = 1500;
private _configurations       = [
//       /------------------------------------------ MIN distance between objectives
//       |       /---------------------------------- MAX distance between objectives
//       |       |          /------------------------- max dist from centroid
//       |       |          |           /------------- max sum(dist from centroid)
//       |       |          |           |
//       |       |          |           |
//       v       v          v           V
	[ 2000,     -1,        -1,         -1],  //big,    <= 7 obj. No clusters possible
	[ 1150,     -1,        -1,         -1],  //normal, <=14 obj. No clusters possible
	[    0,    700,       700,       1500],  //small,  <= 5 obj. ~1-2km total walking distance (per cluster)
	[    0,    500,       400,         -1]   //tiny,   <= 4 obj. ~1km total walking distance (per cluster) (RECOMMENDED OPTION FOR CLUSTERS)

	//DO NOT ADD/CHANGE ANYTHING HERE WITHOUT EXTENSIVE TESTING (e.g. by plotting all subgraph connections)!
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
fnc_mean = {
	params ["_objects","_indices"];
	private _mean = [0,0,0];
	{
		private _pos = getPos (_objects select _x);
		_mean = _mean vectorAdd _pos;
	} forEach _indices;
	_mean = _mean vectorMultiply (1/(count _indices));

	_mean
};
//------------------------------------------------------------------------------
fnc_mean_distances = {
	params ["_mean", "_objects","_indices"];

	_indices apply { _mean distance (getPos (_objects select _x)) }
};
//------------------------------------------------------------------------------
fnc_adjacency_matrix = {
	//TODO adjacency matrix is symmetrical, we could cut the runtime in half...
	params ["_objects","_max_dist"];
	private _adjacency_matrix = [];
	{
		private _obj1 = _x;
		private _obj1_array = [];
		{
			private _dist = _obj1 distance _x;
			_obj1_array pushBack ( [0, _dist] select ( _dist < _max_dist || _max_dist <= 0) );
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
//things is global for debugging purposes
if (isNil "things") then {
	//_pos = getArray(configFile >> "CfgWorlds" >> "Altis" >> "centerPosition");
	//_radius = _pos; _radius sort false; _radius = (_radius select 0) * (sqrt 2);
	things = nearestObjects [[25000,21500,0], ["I_supplyCrate_F"], 4500];
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
debug_time = [];_t1 = diag_tickTime;
//------------------------------------------------------------------------------
//connections between objectives
private _adjacency_matrix = ([things, _max_distance_between_objectives] call fnc_adjacency_matrix);
//------------------------------------------------------------------------------
//get pairs of nodes that are too close to each other

private _too_close = [];
for "_row" from 0 to ((count _adjacency_matrix) - 1) do {
	for "_col" from (_row + 1) to ((count _adjacency_matrix) - 1) do {
		private _dist = _adjacency_matrix select _row select _col;
		if (_dist < _min_distance_between_objectives) then {
			_too_close pushBack [_row, _col];
		};
	};
};
//------------------------------------------------------------------------------
debug_time pushBack (diag_tickTime - _t1);
_t1 = diag_tickTime;
//------------------------------------------------------------------------------
//get subgraphs
private _subgraphs = [];
{
	private _starting_node = _forEachIndex;
	private _subgraph = [];
	_subgraph pushBack _starting_node;
	//NOTE: we only check _max_distance_between_objectives from the starting node, not from each node to every other node.
	{
		if (_x > 0) then {
			_subgraph pushBack _forEachIndex;
		};
	} forEach (_x);

	//remove nodes that are too far away from the center of the subgraph
	if (_max_distance_from_centroid > 0 || _max_distance_from_centroid_sum > 0) then {
		private _done = false;
		while {! _done} do {
			private _mean              = [things, _subgraph] call fnc_mean;
			private _distances_to_mean = [_mean, things, _subgraph] call fnc_mean_distances;
			private _sum       =  0;
			private _max       = -1;
			private _max_index = -1;
			{
				//dont remove the starting_node!
				if (_x > _max && (_subgraph select _forEachIndex) != _starting_node) then {
					_max = _x;
					_max_index = _forEachIndex;
				};
				_sum = _sum + _x;
			} forEach _distances_to_mean;

			if ((_max >= _max_distance_from_centroid    && _max_distance_from_centroid     > 0) ||
				(_sum > _max_distance_from_centroid_sum && _max_distance_from_centroid_sum > 0)    ) then {
				_subgraph deleteAt _max_index;
			} else {
				_done = true;
			}
		};
	};

	//remove nodes if they're too close to each other. (after removing nodes that are too far off center)
	private _sg_too_close = +_too_close;
	_sg_too_close = _sg_too_close select {(_x select 0) in _subgraph &&
		                                  (_x select 1) in _subgraph};
	//process pairs
	while {count _sg_too_close > 0} do {
		private _pair = _sg_too_close select 0;

		private _start_in_pair = _pair find _starting_node;
		//private _delete = selectRandom _pair;
		private _delete = _pair select 1; //why do i have to delete the 2nd element here?
		//dont remove the starting node:
		if (_start_in_pair != -1) then {
			_delete = _pair select ( 1 - _start_in_pair );
		};

		_subgraph = _subgraph - [_delete];
		_sg_too_close = _sg_too_close select {!(_delete in _x)};
	};

	_subgraphs pushBack _subgraph;
} forEach _adjacency_matrix;

//------------------------------------------------------------------------------
debug_time pushBack (diag_tickTime - _t1);
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
// sort subgraphs for easier postprocessing:
_subgraphs = [_subgraphs, [], {count _x}] call BIS_fnc_sortBy;
private _max_subgraph_size = count (_subgraphs select (count _subgraphs - 1)); //works because sorted

private _tmp = _num_objectives min (_max_subgraph_size - 1); //-1 to get more possibilities
_num_objectives      = _num_objectives min (_max_subgraph_size);
_subgraphs = _subgraphs select {(count _x) >= _tmp};
//remove subgraphs smaller than _num_objectives,
/*
//iff we have at least as many subgraphs as clusters afterwards
//NOTE: this is theoretically wrong, becuse it might still result in less
//      subgraphs than clusters because of min-cluster-distance
private _tmp = _subgraphs select {(count _x) >= _num_objectives};
if (count _tmp >= _clusters) then {
	_subgraphs = _tmp;
};
*/
//------------------------------------------------------------------------------
//prepare variabled for clusters:
_clusters = _clusters min (count _subgraphs);

private _subgraphs_means = [];
if (_clusters > 1) then  {
	_subgraphs_means = _subgraphs apply { [things, _x] call fnc_mean };
};
//------------------------------------------------------------------------------
//mark all possible sets
if (_debug > 1) then {
	private _line_width = [1, 5] select (_max_subgraph_size < 15);
	{
		private _subgraph_index = _forEachIndex;
		private _graph = _subgraphs select _subgraph_index;
		private _color = dbg_colors select (_subgraph_index % (count dbg_colors));
		{
			private _pos = position (things select _x);
			private _dist = 30;//100
			_pos = _pos getPos [_dist, 360/(count _subgraphs)*_subgraph_index];

			[_pos, _marker_prefix, format ["graph_%1", _subgraph_index], "mil_objective", _color, [0.5,0.5]] call fnc_marker;
			if (_debug > 2 || count _subgraphs < 30) then {
				private _x1 = _x;
				{
					if (_x1 != _x) then {
						private _pos2 = (things select _x) getPos [_dist, 360/(count _subgraphs)*_subgraph_index];
						[_marker_prefix, _pos, _pos2, _color, _line_width, false] call fnc_draw_line;
					};
				} forEach _graph;
			};
		} forEach _graph;
		//mark subgraph mean:
		if (_clusters > 1) then  {
			private _mean = _subgraphs_means select _subgraph_index;
			private _max = selectMax ([_mean, things, _graph] call fnc_mean_distances);//TODO
			[_mean, _marker_prefix, format ["cluster_mean1"], "mil_box", _color, 0, 1, 0, str round(_max)] call fnc_marker;
			[_mean, _marker_prefix, format ["cluster_mean2"], "ELLIPSE", _color, _max, 0.3] call fnc_marker;
		};
	} forEach _subgraphs;
};
//------------------------------------------------------------------------------
//clusters:

//subgraph indices, shuffled: (so that we can loop over it and don't worry about endless loops or picking the same thing twice)
private _indices = 0;
_indices = _subgraphs apply { _indices = _indices+1; _indices-1 };
_indices = _indices call BIS_fnc_arrayShuffle;

//select subgraphs/clusters
private _subgraphs_selected_indices = [];
{
	if(count _subgraphs_selected_indices >= _clusters) exitWith {};

	if(_clusters == 1) exitWith {
		_subgraphs_selected_indices pushBack _x;
	};

	private _new_sg_mean = _subgraphs_means select _x;
	private _means_selected = _subgraphs_selected_indices apply {_subgraphs_means select _x};
	//check if it's far enough away from all other clusters
	if({_new_sg_mean distance2d _x < _cluster_dist} count _means_selected == 0) then {
		_subgraphs_selected_indices pushBack _x;
	};
} forEach _indices;
//------------------------------------------------------------------------------
//based on the previously selected clusters (_subgraphs_selected_indices):
//select subgraphs, remove unnecessary nodes, ...
private _nodes_selected = [];
{
	private _nodes = +(_subgraphs select _x); //copying the array, because we might still need the original
	//remove random nodes if subgraph is too big
	_nodes = _nodes call BIS_fnc_arrayShuffle;
	_nodes resize _num_objectives;
	//pushBackUnique because subgraphs can overlap
	{ _nodes_selected pushBackUnique _x; } forEach _nodes;
} forEach _subgraphs_selected_indices;
//------------------------------------------------------------------------------
//fake markers
//need to shuffle again, because we don't want all fake markers to be in one cluster
_nodes_selected = _nodes_selected call BIS_fnc_arrayShuffle;
private _num_fakemaker = _fakemarker * (selectRandom [1, 2]); //1 or 2 fake marker
if (_num_fakemaker / count (_nodes_selected) > 0.33) then { //never more than 1/3 fake marker!
	_num_fakemaker = _num_fakemaker - 1
};
private _nodes_selected_fake    = _nodes_selected select [0, _num_fakemaker];
private _nodes_selected_no_fake = _nodes_selected select [_num_fakemaker, (count _nodes_selected) - _num_fakemaker];
//------------------------------------------------------------------------------
//mark selected nodes
if (!is3DEN || is3DEN && _debug < 4) then {
	{
		private _objective = things select _x;
		//mark node
		private _marker = [_objective, _marker_prefix, "objectives", "mil_objective", _color_objectives] call fnc_marker;
		if ((_debug > 0) && (_x in _nodes_selected_fake)) then {
			_marker setMarkerColor "ColorBlue";
			_marker setMarkerText "fake";
		};

		_objective setVariable ["marker_name", _marker, true]; //to change the marker later
		_objective setVariable ["index", _forEachIndex, true]; //used for damage handler
	} forEach (_nodes_selected_fake + _nodes_selected_no_fake);
};
//------------------------------------------------------------------------------
if (_debug > 0) then {
	subgraphs = _subgraphs;
	nodes_selected = _nodes_selected;
	subgraphs_selected_indices = _subgraphs_selected_indices;
	adjacency_matrix = _adjacency_matrix;
} else {
	_subgraphs = nil;
	_adjacency_matrix = nil;
	_too_close = nil;
	_subgraphs_means = nil;
	_nodes_selected = nil;
};
//------------------------------------------------------------------------------
_objectives     = _nodes_selected_no_fake apply {things select _x};
_fake_positions = _nodes_selected_fake    apply {position (things select _x)};

//remove unused caches
if(!is3DEN) then {
	_things_to_delete = +things;
	_things_to_delete = _things_to_delete - _objectives;
	{deleteVehicle _x;} forEach _things_to_delete;
};
//RETURN objectives and positions of fake-markers
[_objectives, _fake_positions]
//------------------------------------------------------------------------------
