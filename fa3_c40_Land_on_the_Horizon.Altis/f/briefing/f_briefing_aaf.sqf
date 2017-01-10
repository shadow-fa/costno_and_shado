// F3 - Briefing
// Credits: Please see the F3 online manual (http://www.ferstaberinde.com/f3/en/)
// ====================================================================================

// FACTION: AAF

// ====================================================================================

// NOTES: CREDITS 
// <marker name = 'marker'>words</marker>
// The code below creates the administration sub-section of notes.

_cre = player createDiaryRecord ["diary", ["Credits","
<br/>
Created by Costno and Shado'
<br/><br/>
Made with F3 (http://www.ferstaberinde.com/f3/en/)
"]];

// ====================================================================================

// NOTES: ADMINISTRATION
// The code below creates the administration sub-section of notes.

_adm = player createDiaryRecord ["diary", ["Administration","
<br/>
Victory by destroying all caches. Leaders, ARs, and AARs carry demo charges.
<br/><br/>
Host/CO will decide whether we take Ghosthawks or Littlebirds.
"]];

// ====================================================================================

// NOTES: EXECUTION
// The code below creates the execution sub-section of notes.

_exe = player createDiaryRecord ["diary", ["Execution","
<br/>
<font size='18'>COMMANDER'S INTENT</font>
<br/>
Insert to multiple suspected cache locations and destroy any resistance. 
<br/><br/>
<font size='18'>MOVEMENT PLAN</font>
<br/>
We start at <marker name = 'mkrBase'>Molos Airfield</marker> and can fly as far south as this <marker name = 'mkrNoFly'>no fly zone.</marker>
<br/><br/>
Enemies may have manpads, but our birds have flares and our pilots tell us they are competent.  Pick ups and drop offs will need to be quick in this terrain, there is a lot of open ground.
<br/><br/>
<font size='18'>FIRE SUPPORT PLAN</font>
<br/>
Our pilots all know how to operate the attack helicopter variants of our littlebirds, CO can allocate pilots to those if no dedicated attack pilots are present (and if host allows!).
<br/><br/>
<font size='18'>FARP PEFKAS</font>
<br/>
<marker name = 'mkrFarp'>FARP Pefkas</marker> has refeul and repair trucks to fix our littlebirds, but if attack helicopters need to rearm they must return to <marker name = 'mkrBase'>Molos Airfield</marker>
<br/><br/>
"]];

// ====================================================================================

// NOTES: MISSION
// The code below creates the mission sub-section of notes.

_mis = player createDiaryRecord ["diary", ["Mission","
<br/>
Scan the area between <marker name = 'mkrBase'>Molos Airfield</marker> and the <marker name = 'mkrLine'>no fly zone</marker> for enemy caches.
"]];

// ====================================================================================

// NOTES: SITUATION
// The code below creates the situation sub-section of notes.

_sit = player createDiaryRecord ["diary", ["Situation","
<br/>
FIA has scattered some caches across the Northwest end of Altis.  We have intel on a few possible locations, and we need them destroyed.  
<br/><br/>
<font size='18'>ENEMY FORCES</font>
<br/>
Mostly lightly armed FIA and a couple technicals.  Reinforcements may come from southwest of the <marker name = 'mkrNoFly'>no fly zone</marker>.  Manpads may also be present north of the no fly zone, but we doubt that FIA will have many if they have any at all.
<br/><br/>
It's rumoured that CSAT forces may be conspiring with different factions of FIA under our noses, so if you see any in the AO you are cleared to fire upon them.
<br/><br/>
<font size='18'>FRIENDLY FORCES</font>
<br/>
A heliborne platoon of Altis' best.  A lot of our gear we got from our friends in NATO.
"]];

// ====================================================================================