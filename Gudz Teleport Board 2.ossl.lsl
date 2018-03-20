// Gudule's Teleport Board 2
// Version 2.0.1
// Get the latest version from Github:
//  https://github.com/GuduleLapointe/Gudz-Teleport-Board-2
//
// (c) Gudule Lapointe 2016-2018
// This is a complete rewrite of Gudule's 2016 HGBoard, which was an adaptation
// of Jeff Kelley' 2010 HGBoard script. Very few of the original code was kept
// (except mainly the drawing engine).
//
// This script is licensed under Creative Commons BY-NC-SA
// See <http://creativecommons.org/licenses/by-nc-sa/3.0/>
// You may not use this work for commercial purposes.
// You must attribute the work to the authors, Jeff Kelley and Gudule Lapointe
// You may distribute, alter, transform, or build upon this work
// as long as you do not delete the name of the original authors.

// The destination list can be set by 3 ways
//  - from an external website: put the URL in prim description
//  - from a specific notecard: put "card://CardName" in the description
//  - fallback if none of the two first method: read the first notecard found.
//
// In previous versions, the destination list used 5 values. We accept this old // format for backward compatibility but we recommand the simplified format:
//      Displayed Name|your.grid:port
// or   Displayed Name|your.grid:port:Region Name
// or   Displayed Name|your.grid:port:Region Name|x,y,z
//
// Empty lines are ignored
// Lines commented with "//" are sent as message to the owner and not processed
// Lines containing only a string (and no url) are drawn as simple text
// Lines containing only a separator ("|") are drawn as an empty line (spacer)

//OSSL Functions:
//    osGetGridGatekeeperURI
//    osGetNotecard
//    osTeleportAgent
//    osSetDynamicTextureDataBlendFace and related functions
//        (osDrawFilledRectangle, osDrawRectangle, osDrawText,
//        osGetDrawStringSize, osMovePen, osSetFontName, osSetFontSize,
//        osSetPenColor, osSetPenSize)

// Configurable parameters
// Do not change configuration here, use a notecard named "Configuration"
// instead, to avoir upgrade issues.

integer USE_MAP = FALSE; // if set to TRUE, don't teleport agent, just show map

list ACTIVE_SIDES = [ ALL_SIDES ]; // touch active only on this side.
integer TEXTURE_WIDTH = 512; // a power of 2: 256, 512, 1024...
integer TEXTURE_HEIGHT = 512; // a power of 2: 256, 512, 1024...
key INITIALIZING_TEXTURE = TEXTURE_BLANK;

string FONT_NAME = "Arial"; // A font installed on the simulator computer
string FONT_COLOR = "Black";
integer COLUMNS = 2;
integer ROWS = 12;

float FONT_SIZE = 1.0; // relative to row height
float PADDING_LEFT = 0.5; // relative to font size
float PADDING_TOP = 0.3; // relative to font size

string BACKGROUND_COLOR  = "DarkGreen"; // "Gray";
key BACKGROUND_TEXTURE = NULL_KEY;
    // Use NULL_KEY for no texture. Make sure the background texture
    // is not smaller than TEXTURE_WIDTH x TEXTURE_HEIGHT
string CELL_ACTIVE   = "White";
string CELL_DISABLED   = "IndianRed";
string CELL_THIS_REGION   = "Green";
string CELL_EMPTY   = "transparent";
string CELL_TITLE_FONT = "White";
string CELL_BORDER_COLOR  = "transparent";
integer CELL_BORDER_SIZE  = 5;

integer SHOW_RATING = FALSE; // Wrong results for HG links, good in local grid
integer REFRESH_DELAY = 3600;

integer DEBUG = FALSE;
string CONFIG_FILE = "Configuration";

// End configurable variables
// Do not change values below, they are set in the script

integer activeSide;
string localGatekeeperURI;
string localRegionURI;
string source;
list destinations;
integer DESTCOLS=6;
key httpNotecardId;
key httpDestCheckId;
key httpDestRatingId;
integer firstRun = TRUE;
integer cellsFound;
integer fontSize;
integer paddingTop;
integer paddingLeft;

key teleportAgent;
string teleportURI;
vector teleportLanding;

string strReplace(string str, string search, string replace) {
    return llDumpList2String(llParseStringKeepNulls((str),[search],[]),replace);
}

getConfig() {
    if(llGetInventoryType(CONFIG_FILE) != INVENTORY_NOTECARD) return;
    debug("Reading config from " + CONFIG_FILE);

    string data = osGetNotecard(CONFIG_FILE);
    list lines = llParseString2List (data,["\n"],[]);
    integer i; for (i=0;i<llGetListLength (lines);i++)
    {
        string line = llList2String(lines,i);
        list parse  = llParseStringKeepNulls (line, ["="],[]);
        string var = llStringTrim(llList2String(parse, 0), STRING_TRIM);
        string val = llStringTrim(llList2String(parse, 1), STRING_TRIM);
        if (var == "USE_MAP") USE_MAP = (integer)val;
        else if (var == "ACTIVE_SIDES") {
            val=strReplace(val, "[", "");
            val=strReplace(val, "]", "");
            val=strReplace(val, " ", "");
            ACTIVE_SIDES = llParseString2List(val, [","," "], "");
        }
        else if (var == "TEXTURE_WIDTH") TEXTURE_WIDTH = (integer)val;
        else if (var == "TEXTURE_HEIGHT") TEXTURE_HEIGHT = (integer)val;
        else if (var == "INITIALIZING_TEXTURE") INITIALIZING_TEXTURE = (key)val;
        else if (var == "FONT_NAME") FONT_NAME = (string)val;
        else if (var == "FONT_COLOR") FONT_COLOR = (string)val;
        else if (var == "COLUMNS") COLUMNS = (integer)val;
        else if (var == "ROWS") ROWS = (integer)val;
        else if (var == "FONT_SIZE") FONT_SIZE = (float)val;
        else if (var == "PADDING_LEFT") PADDING_LEFT = (float)val;
        else if (var == "PADDING_TOP") PADDING_TOP = (float)val;
        else if (var == "BACKGROUND_COLOR") BACKGROUND_COLOR = (string)val;
        else if (var == "BACKGROUND_TEXTURE") BACKGROUND_TEXTURE = (key)val;
        else if (var == "CELL_ACTIVE") CELL_ACTIVE = (string)val;
        else if (var == "CELL_DISABLED") CELL_DISABLED = (string)val;
        else if (var == "CELL_THIS_REGION") CELL_THIS_REGION = (string)val;
        else if (var == "CELL_EMPTY") CELL_EMPTY = (string)val;
        else if (var == "CELL_TITLE_FONT") CELL_TITLE_FONT = (string)val;
        else if (var == "CELL_BORDER_COLOR") CELL_BORDER_COLOR = (string)val;
        else if (var == "CELL_BORDER_SIZE") CELL_BORDER_SIZE = (integer)val;
        else if (var == "SHOW_RATING") SHOW_RATING = (integer)val;
        else if (var == "REFRESH_DELAY") REFRESH_DELAY = (integer)val;
        else if (var == "CELL_BORDER_SIZE") CELL_BORDER_SIZE = (integer)val;
        else debug("Configuration ignored: " + line);
    }
    //debug("active sides " + llGetListLength(ACTIVE_SIDES) + " " + llDumpList2String(ACTIVE_SIDES, ":"));
}
readDestFromURL(string url) {
    debug("Reading destinations from url " + url);
    httpNotecardId = llHTTPRequest(url,
        [ HTTP_METHOD,  "GET", HTTP_MIMETYPE,"text/plain;charset=utf-8" ], "");
}
readDestFromLSLServer(key uuid, string cardname) {
    // Not implemented
}
readDestFromNotecard(string notecard) {
    debug("Reading destination from notecard " + notecard);
    parseDestinations(osGetNotecard(notecard));
}
parseDestinations(string data) {
    list lines = llParseString2List (data,["\n"],[]);
    integer count = llGetListLength(lines);
    statusUpdate(count + " lines to process");
    //integer length = llGetListLength (lines);
    integer i; for (i=0;i<llGetListLength (lines);i++)
    {
        statusUpdate("Processing line " + (i+1) + " of " + count);
        parseDestination (llList2String(lines,i));
    }
}
parseDestination (string line) {
    if(llGetListLength(destinations) / DESTCOLS >= COLUMNS * ROWS) return;
    if (llStringTrim(line, STRING_TRIM) == "") return; // Ignore empty lines
    if (llGetSubString (line,0,0) == "#") return;  // Comment, ignore
    if (llGetSubString (line,0,1) == "//") {  // Comment, show
        if(firstRun) llOwnerSay ("   " + line);
        return;
    }
    if(line == "-") { // Jump to next column
        if(COLUMNS > 1 ) {
            integer i = (llGetListLength(destinations) / DESTCOLS) % ROWS;
            if(i > 0)
            for (; i<ROWS; i++) destinations += ["", "", "", "", "", ""];
        }
        return;
    }

    string destinationGrid;
    string destinationName;
    string destinationURI;
    string landingPoint;

    list parse  = llParseStringKeepNulls (line, ["|"],[]);
    if (llGetListLength(parse) >= 4) {
        // Allow old 5-values format for backward compatibility
        // Prefer two-values format "Name|URI"
        destinationGrid = llList2String (parse, 0); // Grid name
        destinationName = llList2String (parse, 1); // Region name
        //string gloc = llList2String (parse, 2); // Grid coordinates, deprecated
        destinationURI = llList2String (parse, 3);
        landingPoint = llList2String (parse, 4); // Landing
        if(destinationName == "") {
            destinationName = destinationGrid;
            destinationGrid = "";
        }
    }
    else if (llGetListLength(parse) >= 1) {
        destinationName = llList2String (parse, 0); // Region name
        destinationURI = llList2String (parse, 1); // Region name
        landingPoint = llList2String (parse, 2); // Region name
    } else {
        destinationName = line;
    }
    addDestination(destinationName, destinationURI, landingPoint);
}

addDestination(string name, string uri, string landing) {
    if(uri != "" && llListFindList(destinations, uri) >=0 ) return;
    uri=strReplace(uri, "http://", "");
    // name, uri, landingPoint, gridname, status, rating
    destinations += [name, uri, landing, "", "", ""];
    checkDestination(uri);
}
checkDestination(string uri) {
    if(uri == "") return;
    //debug("checking " + uri);
    integer index = llListFindList(destinations, uri) - 1;
    httpDestCheckId = llRequestSimulatorData(uri, DATA_SIM_STATUS);
    destinations = llListReplaceList(destinations, [ httpDestCheckId ] , index + 4, index + 4);
    if(SHOW_RATING)
    {
        httpDestRatingId = llRequestSimulatorData(uri, DATA_SIM_RATING);
        destinations = llListReplaceList(destinations, [ httpDestRatingId ] , index + 5, index + 5);
    }
}
getSource()
{
    if(source == "") source = llGetObjectDesc();
    if(source=="") {
        if(llGetInventoryName(INVENTORY_NOTECARD, 0) != CONFIG_FILE)
        source="card://" + llGetInventoryName(INVENTORY_NOTECARD, 0);
        else
        source="card://" + llGetInventoryName(INVENTORY_NOTECARD, 1);
    }
    if(source=="card://") {
        llOwnerSay("Datasource " + source + " is not set or not vaild");
        destinations = ["No data source", "#", "", "", "Error", ""];
        drawTable();
        destinations = [];
        return;
    }
    list parse = llParseString2List (source, ["/"],[]);
    string p0 = llList2String (parse, 0); // protocol
    string p1 = llList2String (parse, 1); // cardname (or UUID of LSL server)
    string p2 = llList2String (parse, 2); // carname (from LSL Server)

    if (p0 == "http:" || p0 == "https:") readDestFromURL(source);
    else if (p0 == "card:" && isUUID(p1)) readDestFromLSLServer(p1, p2);
    else if (p0 == "card:") readDestFromNotecard(p1);
}

integer isUUID (string s) {
    list parse = llParseString2List (s, ["-"],[]);
    return ((llStringLength (llList2String (parse, 0)) == 8)
        &&  (llStringLength (llList2String (parse, 1)) == 4)
        &&  (llStringLength (llList2String (parse, 2)) == 4)
        &&  (llStringLength (llList2String (parse, 3)) == 4)
        &&  (llStringLength (llList2String (parse, 4)) == 12));
}

statusUpdate(string status) {
    llSetText(status, <1,1,1>, 1.0);
}

debug(string msg)
{
    if(! DEBUG) return;
    llOwnerSay(msg);
}


string drawList;

drawTable() {
    fontSize =(integer)(TEXTURE_HEIGHT * FONT_SIZE / (ROWS * 2));
    paddingTop = (integer)(fontSize * PADDING_TOP);
    paddingLeft = (integer)(fontSize * PADDING_LEFT);

    displayBegin();
    drawList = osSetPenSize  (drawList, 1);
    drawList = osSetFontSize (drawList, fontSize);
    drawList = osSetFontName (drawList, FONT_NAME);

    if(BACKGROUND_COLOR != "transparent") {
        drawList = osMovePen     (drawList, 0, 0);
        drawList = osSetPenColor (drawList, BACKGROUND_COLOR);
        drawList = osDrawFilledRectangle (drawList, TEXTURE_WIDTH, TEXTURE_HEIGHT);
    }
    integer x; integer y;
    for (x=0; x<COLUMNS; x++)
        for (y=0; y<ROWS; y++)
            drawCell (x, y);

    displayEnd();
}

displayBegin() {
    //if(CELL_ACTIVE == "transparent") {
//        llSetTexture(TEXTURE_TRANSPARENT, ALL_SIDES);
    //} else {
        //llSetTexture(TEXTURE_BLANK, ALL_SIDES);
    //}
    drawList = "";
}

displayEnd() {
    integer alpha = 255;
    if(BACKGROUND_COLOR == "transparent") alpha = 0;
    string dynamicTexture;
    if(BACKGROUND_TEXTURE == NULL_KEY || destinations == [ "Initializing" ]) {
        dynamicTexture = osSetDynamicTextureDataBlendFace ( "", "vector", drawList,
            "width:"+(string)(TEXTURE_WIDTH)
            +",height:"+(string)TEXTURE_HEIGHT
            +",alpha:"+(string)alpha
            +",bgcolor:"+(string)BACKGROUND_COLOR
            , FALSE, 1, 0, 255, activeSide
            );
    } else {
        llSetTexture(BACKGROUND_TEXTURE, activeSide);
        dynamicTexture = osSetDynamicTextureDataBlendFace ( "", "vector", drawList,
            "width:"+(string)(TEXTURE_WIDTH)
            +",height:"+(string)TEXTURE_HEIGHT
            +",alpha:"+(string)alpha
            +",bgcolor:"+(string)BACKGROUND_COLOR
            , TRUE, 1, 0, 255, activeSide
            );
    }

    integer i;
    for (i=1; i<llGetListLength(ACTIVE_SIDES); i++)
    {
        llSetTexture(dynamicTexture, llList2Integer(ACTIVE_SIDES, i));
    }
    //osSetDynamicTextureData    ( "", "vector", drawList,
    //    "width:"+(string)(TEXTURE_WIDTH)
    //    +",height:"+(string)TEXTURE_HEIGHT
    //    +",alpha:"+(string)alpha
    //    +",bgcolor:"+(string)BACKGROUND_COLOR
    //    , 0);
}

drawCell (integer x, integer y) {
    integer cellHeight = (TEXTURE_HEIGHT - CELL_BORDER_SIZE) / ROWS;
    integer cellWidth  = (TEXTURE_WIDTH - CELL_BORDER_SIZE) / COLUMNS;
    integer xOffset = (TEXTURE_WIDTH-CELL_BORDER_SIZE-cellWidth*COLUMNS)/2;
    integer yOffset = (TEXTURE_HEIGHT-CELL_BORDER_SIZE-cellHeight*ROWS)/2;
    integer xTopLeft    = xOffset + x*cellWidth;
    integer yTopLeft    = yOffset + y*cellHeight;

    // Draw grid

    if(CELL_BORDER_COLOR != "transparent")
    {
        drawList = osSetPenColor   (drawList, CELL_BORDER_COLOR);
        drawList = osMovePen       (drawList, xTopLeft, yTopLeft);
        drawList = osDrawRectangle (drawList, cellWidth, cellHeight);
    }
    integer index = (y+x*ROWS) * DESTCOLS;
    list destination = llList2List(destinations, index, index + DESTCOLS - 1);

    // name, uri, landingPoint, gridname, status, rating

    string cellName  = llList2String(destination, 0);
    string cellStatus = llList2String(destination, 4);
    string cellURI = llList2String(destination, 1);

    if(SHOW_RATING && cellURI != "") {
        string cellRating = llList2String(destination, 5);
        if(cellRating == "MATURE") cellName += " [M]";
        else if(cellRating == "ADULT") cellName += " [A]";
    }

    string cellFontColor = FONT_COLOR;
    string cellBackground;
    if (cellName == "" || cellURI == "") {
        cellBackground = CELL_EMPTY;
        cellFontColor = CELL_TITLE_FONT;
    }
    else if (cellStatus == "up" && cellURI == localRegionURI)
    cellBackground = CELL_THIS_REGION;
    else if(cellStatus == "up")
    cellBackground = CELL_ACTIVE;
    else
    cellBackground = CELL_DISABLED;

    // Adjust text to fit cell
    cellName = trimCell(cellName, FONT_NAME, fontSize, cellWidth - 2*CELL_BORDER_SIZE);

    // Fill background
    if(cellBackground != "transparent") {
        drawList = osSetPenColor         (drawList, cellBackground);
        drawList = osMovePen             (drawList, xTopLeft+CELL_BORDER_SIZE, yTopLeft+CELL_BORDER_SIZE);
        drawList = osDrawFilledRectangle (drawList, cellWidth-CELL_BORDER_SIZE, cellHeight-CELL_BORDER_SIZE);
    }
    xTopLeft += paddingLeft ;  // Center text in cell
    yTopLeft += paddingTop ;  // Center text in cell
    drawList = osSetPenColor (drawList, cellFontColor);
    drawList = osMovePen     (drawList, xTopLeft, yTopLeft);
    drawList = osDrawText    (drawList, cellName);
}

string trimCell(string in, string fontname, integer fontsize,integer width)
{
    integer i;
    integer trimmed = FALSE;
    string suffix;
    for(;llStringLength(in)>0;in=llGetSubString(in,0,-2)) {
        vector extents = osGetDrawStringSize("vector",in+suffix,fontname,fontsize);
        if(extents.x<width) return in + suffix;
        suffix="…";
    }
    return "";
}

integer getCellClicked(vector point) {
    integer y = (ROWS-1) - llFloor(point.y*ROWS); // Top to bottom
    integer x = llFloor(point.x*COLUMNS);         // Left to right
    integer index = (y+x*ROWS);
    return index;
}

integer action(integer index, key who) {
    integer listIndex = index * DESTCOLS;
    list destination = llList2List(destinations, listIndex, listIndex + DESTCOLS - 1);
    string destName = llList2String(destination, 0);
    string destURI = llList2String(destination, 1);
    string destLanding = llList2String(destination, 2);
    string destStatus = llList2String(destination, 4);

    destURI  = strReplace(destURI, "http://", "");
    destURI  = strReplace("http://" + destURI, localGatekeeperURI + ":", "");
    destURI  = strReplace(destURI, "http://", "");

    if (destName == "" || destURI == "") return FALSE; // Empty cell
    if (destStatus != "up")
    {
        llInstantMessage(who, "Cannot teleport, " + destName + " status is " + destStatus);
        return FALSE; // Incompatible region
    }
    llWhisper(0, "You have selected "+ destName + " (" + destURI + ") " + destLanding);
    // Préparer les globales avant de sauter
    if (USE_MAP) {
        llMapDestination (destURI, destLanding, ZERO_VECTOR);
        return TRUE;
    }

    teleportAgent = who;
    teleportURI = destURI;
    teleportLanding = destLanding;


    debug("teleporting to " + teleportURI);
    state teleporting;
    return TRUE;
}

default
{
    state_entry()
    {
        statusUpdate("Initializing");
        getConfig();
        activeSide = llList2Integer(ACTIVE_SIDES, 0);
        llSetTexture(INITIALIZING_TEXTURE, activeSide);
        destinations = ["Initializing"];
        drawTable();
        destinations = [];
        localGatekeeperURI = strReplace(osGetGridGatekeeperURI(), "http://", "");
        localRegionURI = localGatekeeperURI + ":" + llGetRegionName();
        getSource();

        //llOwnerSay("Requesting " + Region +  " status");
        //key requestId = llRequestSimulatorData(Region, DATA_SIM_STATUS);
        //llSetTimerEvent(2);
    }
    on_rez(integer start_param)
    {
        llResetScript();
    }
    changed(integer change)
    {
        if (change & CHANGED_REGION) llResetScript();
        if (change & CHANGED_INVENTORY) llResetScript();
    }

    http_response(key id,integer status, list meta, string body) {
        if (id == httpNotecardId)
        parseDestinations (body);
        statusUpdate("Data collected, rendering board");
    }

    dataserver(key query_id, string data)
    {
        integer destCheckIndex = llListFindList(destinations, query_id);
        if(destCheckIndex >= 0) {
            integer column = destCheckIndex % DESTCOLS;
            destinations = llListReplaceList(destinations, [ data ], destCheckIndex, destCheckIndex);
            string destinationName = llList2String(destinations, destCheckIndex - column);
            //debug (destinationName + " is " + (string)data);
        } else {
            debug("Lost query (should not happen)" + query_id + " status " + data);
        }
        llSetTimerEvent(10); //
    }

    timer()
    {
        // Should have received all grid infos, move on
        state ready;
    }

    state_exit() {
        drawTable();
    }
}

state ready {
    state_entry()
    {
        firstRun = FALSE;
        debug("Ready");
        statusUpdate("");
        teleportAgent = NULL_KEY;
        teleportURI = "";
        teleportLanding = <0,0,0>;
        llSetTimerEvent(REFRESH_DELAY * (0.9 + llFrand(0.2)));
    }

    touch_start (integer n) {
        key whoClick = llDetectedKey(0);
        vector point = llDetectedTouchST(0);
        integer face = llDetectedTouchFace(0);
        integer link = llDetectedLinkNumber(0);

        if (link != llGetLinkNumber()) return;
        if (point == TOUCH_INVALID_TEXCOORD) return;
        if (activeSide != ALL_SIDES && llListFindList(ACTIVE_SIDES, (string)face) == -1) return;

        integer ok = action (getCellClicked(point), whoClick);
    }

    changed(integer change) {
        if (change & CHANGED_REGION) llResetScript();
        if (change & CHANGED_INVENTORY) llResetScript();
    }
    timer()
    {
        llResetScript();
    }
}

state teleporting {

    state_entry() {
        debug("checking " + teleportURI);
        httpDestCheckId = llRequestSimulatorData(teleportURI, DATA_SIM_STATUS);
        llSetTimerEvent (30);
    }

    dataserver(key query_id, string data)
    {
        if(query_id == httpDestCheckId)
        {
            if (data == "up")
            {
                debug("OK, teleporting " + teleportAgent + " to " + teleportURI);
                llInstantMessage(teleportAgent, "Fasten your seat belt, we move!!!");
                osTeleportAgent(teleportAgent, teleportURI, teleportLanding, ZERO_VECTOR);
                state ready;
            } else {
                llInstantMessage(teleportAgent, "Sorry, flight is canceled, region status is " + data);
                state ready;
            }
        }
    }

    timer() {
        llInstantMessage(teleportAgent, "Destination is offline");
        state ready;
    }

}
