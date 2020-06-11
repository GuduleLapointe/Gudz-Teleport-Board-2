/*
 * Gudz Teleport Board 2
 *
 * Version:  2.4.6
 * Authors:  Olivier van Helden <olivier@van-helden.net>, Gudule Lapointe
 *           Portions of code (c) The owner of Avatar Jeff Kelley, 2010
 * Source:   https://git.magiiic.com/opensimulator/Gudz-Teleport-Board-2
 * Website:  https://speculoos.world/lab
 * Licence:  2.4.2 or superior: AGPLv3 (Affero GPL)
 *           Prior to v2.4.2:   Creative Commons BY-NC-SA up to version 2.4.1
 *
 * This is a complete rewrite of Gudule's 2016 HGBoard, which was an adaptation
 * of Jeff Kelley' 2010 HGBoard script. Very few of Jeff's original code was
 * kept (mainly the drawing engine).
 *
 * Contributing:
 * If you improve this software, please give back to the community, by
 * submitting your changes on the git repository or sending them to the authors.
 * That's one of the meanings of Affero GPL!
 */

// The destination list can be set by 3 ways
//  - from an external website: put the URL in prim description
//    (only the first 2048 bytes will be loaded)
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

// OSSL Functions:
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
key INITIALIZING_TEXTURE = "e9616da0-d2f9-45fa-ac79-86e50e0e0457";

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
integer REFRESH_DELAY = 43200; // Reload destinations around twice a day
integer HTTP_TIMEOUT = 10;
integer TP_TIMEOUT = 30;
integer DELAYED_CHECK = FALSE; // run status checks after rendering the board.
                               // Slower, but better for long lists
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
integer COL_STATUS = 4;
integer COL_RATING = 5;
key httpNotecardId;
key teleportCheckId;
key httpDestRatingId;
integer firstRun = TRUE;
integer cellsFound;
integer fontSize;
integer paddingTop;
integer paddingLeft;

key teleportAgent;
string teleportURI;
vector teleportLanding;
string currentStatus;
string sourceType;
float touchStarted;

string strReplace(string str, string search, string replace) {
    return llDumpList2String(llParseStringKeepNulls((str),[search],[]),replace);
}

integer boolean(string val)
{
    if(llToUpper(val) == "TRUE" | (integer)val == TRUE) return TRUE;
    else return FALSE;
}

getConfig() {
    currentStatus = "getConfig";
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
            if(val != "")
            {
                val=strReplace(val, "[", "");
                val=strReplace(val, "]", "");
                val=strReplace(val, " ", "");
                ACTIVE_SIDES = llParseString2List(val, [","," "], "");
            }
        }
        else if (var == "TEXTURE_WIDTH") TEXTURE_WIDTH = (integer)val;
        else if (var == "TEXTURE_HEIGHT") TEXTURE_HEIGHT = (integer)val;
        else if (var == "INITIALIZING_TEXTURE") {
            if(llToUpper(val) == "TEXTURE_BLANK")
            INITIALIZING_TEXTURE = TEXTURE_BLANK;
            else if(llToUpper(val) == "TEXTURE_TRANSPARENT" || llToLower(val) == "transparent")
            INITIALIZING_TEXTURE = TEXTURE_TRANSPARENT;
            else if(llGetInventoryKey(val))
            INITIALIZING_TEXTURE = llGetInventoryKey(val);
            else {
                debug("using key(val) " + (key)val);
            }
            INITIALIZING_TEXTURE = (key)val;
        }
        else if (var == "FONT_NAME") FONT_NAME = (string)val;
        else if (var == "FONT_COLOR") FONT_COLOR = (string)val;
        else if (var == "COLUMNS") COLUMNS = (integer)val;
        else if (var == "ROWS") ROWS = (integer)val;
        else if (var == "FONT_SIZE") FONT_SIZE = (float)val;
        else if (var == "PADDING_LEFT") PADDING_LEFT = (float)val;
        else if (var == "PADDING_TOP") PADDING_TOP = (float)val;
        else if (var == "BACKGROUND_COLOR") BACKGROUND_COLOR = (string)val;
        else if (var == "BACKGROUND_TEXTURE") {
            if(val == "transparent") {
                BACKGROUND_TEXTURE = TEXTURE_TRANSPARENT;
            }
            else
            BACKGROUND_TEXTURE = (key)val;
        }
        else if (var == "CELL_ACTIVE") CELL_ACTIVE = (string)val;
        else if (var == "CELL_DISABLED") CELL_DISABLED = (string)val;
        else if (var == "CELL_THIS_REGION") CELL_THIS_REGION = (string)val;
        else if (var == "CELL_EMPTY") CELL_EMPTY = (string)val;
        else if (var == "CELL_TITLE_FONT") CELL_TITLE_FONT = (string)val;
        else if (var == "CELL_BORDER_COLOR") CELL_BORDER_COLOR = (string)val;
        else if (var == "CELL_BORDER_SIZE") CELL_BORDER_SIZE = (integer)val;
        else if (var == "SHOW_RATING") SHOW_RATING = boolean(val);
        else if (var == "REFRESH_DELAY") REFRESH_DELAY = (integer)val;
        else if (var == "CELL_BORDER_SIZE") CELL_BORDER_SIZE = (integer)val;
        else debug("Configuration ignored: " + line);
    }
    if(BACKGROUND_TEXTURE == "transparent"
    || BACKGROUND_TEXTURE == TEXTURE_TRANSPARENT) {
        BACKGROUND_COLOR = "transparent";
        BACKGROUND_TEXTURE = TEXTURE_TRANSPARENT;
    } else if(BACKGROUND_COLOR == "") {
        BACKGROUND_COLOR = "transparent";
    }

    //debug("active sides " + llGetListLength(ACTIVE_SIDES) + " " + llDumpList2String(ACTIVE_SIDES, ":"));
}
readDestFromURL(string url) {
    currentStatus="readDestFromURL";
    debug(currentStatus);
    sourceType = "url";
    debug("Reading destinations from url " + url);
    httpNotecardId = llHTTPRequest(url,
        [ HTTP_METHOD,  "GET", HTTP_MIMETYPE,"text/plain;charset=utf-8" ], "");
}
readDestFromLSLServer(key uuid, string cardname) {
    currentStatus="readDestFromLSLServer";
    debug(currentStatus);
    sourceType = "lslserver";
    // Not implemented
}
readDestFromNotecard(string notecard) {
    currentStatus="readDestFromNotecard";
    debug(currentStatus);
    sourceType = "notecard";
    debug("Reading destination from notecard " + notecard);
    parseDestinations(osGetNotecard(notecard));
}
parseDestinations(string data) {
    list lines = llParseString2List (data,["\n"],[]);
    integer count = llGetListLength(lines);
    statusUpdate(count + " lines to process");
    integer i; for (i=0;i<llGetListLength (lines);i++)
    {
        statusUpdate("Processing line " + (i+1) + " of " + count);
        parseDestination (llList2String(lines,i));
    }
}
parseDestination(string line) {
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
    debug("adding " + llGetListLength(destinations) + ": " + name);
    destinations += [name, uri, landing, "", "up", ""];
    if(! DELAYED_CHECK) checkDestination(uri);
}
checkDestinationByIndex(integer index)
{
    string uri = llList2String(destinations, index + 1);
    if(index >= llGetListLength(destinations)) return;
    // debug("checking " + index + " " + uri);
    if(uri =="") checkDestinationByIndex(index + DESTCOLS);
    else checkDestination(uri);
}
checkDestination(string uri) {
    if(uri == "") {
        debug("uri " + uri + " empty");
        return;
    }
    integer index = llListFindList(destinations, uri) - 1;
    debug("checking " + index + " " + uri);
    uri  = strReplace(uri, "http://", "");
    uri  = strReplace("http://" + uri, localGatekeeperURI + ":", "");
    uri  = strReplace(uri, "http://", "");
    statusUpdate("Checking " + uri);
    key httpDestCheckId = llRequestSimulatorData(uri, DATA_SIM_STATUS);
    destinations = llListReplaceList(destinations, [ httpDestCheckId ] , index + 4, index + 4);
    if(SHOW_RATING)
    {
        httpDestRatingId = llRequestSimulatorData(uri, DATA_SIM_RATING);
        destinations = llListReplaceList(destinations, [ httpDestRatingId ] , index + 5, index + 5);
    }
    // else debug("SHOW_RATING is set to " + SHOW_RATING);
}

string getStatus(string uri)
{
    integer index = llListFindList(destinations, uri);
    if(index == -1) return "not found";
    return llList2String(destinations, index + COL_STATUS);
}
string getRating(string uri)
{
    integer index = llListFindList(destinations, uri);
    if(index == -1) return "";
    return llList2String(destinations, index + COL_RATING);
}
setStatus(string uri, string status)
{
    if(status == getStatus(uri)) return; // no change
    debug("changing " + uri + " status from " + getStatus(uri) + " to " + status);
    integer index = llListFindList(destinations, uri);
    debug("found index " + index);
    if(index == -1) return;
    debug("replacing");
    destinations = llListReplaceList(destinations, [ status ], index + COL_STATUS, index + COL_STATUS);
    debug("status is now " + getStatus(uri));
    drawTable();
}

getSource()
{
    currentStatus = "getSource";
    debug(currentStatus);
    source = llGetObjectDesc();
    if(source=="") {
        if(llGetInventoryName(INVENTORY_NOTECARD, 0) != CONFIG_FILE)
        source="card://" + llGetInventoryName(INVENTORY_NOTECARD, 0);
        else
        source="card://" + llGetInventoryName(INVENTORY_NOTECARD, 1);
    }
    if(source=="card://") {
        llOwnerSay("Datasource " + source + " is not set or not vaild");
        statusUpdate("No data source");
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
    // if(DEBUG) debug(status);
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

    if(BACKGROUND_TEXTURE != "transparent") {
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
    string renderTexture = BACKGROUND_TEXTURE;
    string renderColor = BACKGROUND_COLOR;
    string dynamicTexture;

    // if(BACKGROUND_TEXTURE == NULL_KEY)
    if(BACKGROUND_TEXTURE == NULL_KEY || destinations == [ "Initializing" ])
    renderTexture = TEXTURE_BLANK;
    llSetTexture(renderTexture, activeSide);

    if(BACKGROUND_COLOR == "transparent" || renderTexture == TEXTURE_TRANSPARENT) {
        alpha = 0;
        renderColor = "transparent";
    }

    string drawParameters = "width:"+(string)(TEXTURE_WIDTH)
    +",height:"+(string)TEXTURE_HEIGHT
    +",alpha:"+(string)alpha
    +",bgcolor:"+(string)renderColor;

    if(BACKGROUND_TEXTURE == TEXTURE_TRANSPARENT)
    dynamicTexture = osSetDynamicTextureDataFace ( "", "vector", drawList, drawParameters, 0, activeSide);
    else
    dynamicTexture = osSetDynamicTextureDataBlendFace ( "", "vector", drawList, drawParameters, TRUE, 1, 0, 255, activeSide);

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
    cellName = trimCell(cellName, FONT_NAME, fontSize, cellWidth - 2*paddingLeft);

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
        llInstantMessage(who, "Last time I checked, " + destName + " was " + destStatus + " but I will try");
    }
    llInstantMessage(who, "You have selected "+ destName + " (" + destURI + ") " + destLanding);
    // Préparer les globales avant de sauter
    if (USE_MAP) {
        llMapDestination (destURI, destLanding, ZERO_VECTOR);
        return TRUE;
    }

    teleportAgent = who;
    teleportURI = destURI;
    if(destLanding == "" || destLanding == "0,0,0")
    teleportLanding = "128,128,25";
    else teleportLanding = destLanding;


    debug("teleporting to " + teleportURI);
    state teleporting;
    return TRUE;
}
setNextReload(string status) {
    currentStatus=status;
    float refresh = (float)REFRESH_DELAY * (0.9 + llFrand(0.2));
    debug("setting status " + status + ", next reload in " + (string)refresh);
    llSetTimerEvent(refresh);
    // llSetTimerEvent(REFRESH_DELAY);
}

default
{
    state_entry()
    {
        debug("Initializing (entering state default)");
        statusUpdate("Initializing");

        getConfig();
        activeSide = llList2Integer(ACTIVE_SIDES, 0);

        debug("active side: " + activeSide + " active sides: " + (string)ACTIVE_SIDES);
        integer i;
        for (i=0; i<llGetListLength(ACTIVE_SIDES); i++)
        {
            debug("set init " + INITIALIZING_TEXTURE + " texture to side " + llList2Integer(ACTIVE_SIDES, i));
            llSetTexture(INITIALIZING_TEXTURE, llList2Integer(ACTIVE_SIDES, i));
        }

        // llSetTexture(BACKGROUND_TEXTURE, activeSide);
        // llSetTexture(INITIALIZING_TEXTURE, activeSide);
        // destinations = ["Initializing"];
        // drawTable();
        destinations = [];
        localGatekeeperURI = strReplace(osGetGridGatekeeperURI(), "http://", "");
        localRegionURI = localGatekeeperURI + ":" + llGetRegionName();
        getSource();
        if(sourceType == "notecard")
        state ready;

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
        if(DELAYED_CHECK) state ready;
    }

    dataserver(key query_id, string data)
    {
        integer destCheckIndex = llListFindList(destinations, query_id);
        if(destCheckIndex >= 0) {
            integer column = destCheckIndex % DESTCOLS;
            destinations = llListReplaceList(destinations, [ data ], destCheckIndex, destCheckIndex);
            // if(data == "unknown")
            debug((destCheckIndex-4) + ": " + llList2String(destinations, destCheckIndex -3) + " status " + llToUpper(data));
            //string destinationName = llList2String(destinations, destCheckIndex - column);
            //debug (destinationName + " is " + (string)data);
        } else {
            debug("Lost query (should not happen)" + query_id + " status " + data);
        }
        llSetTimerEvent(HTTP_TIMEOUT); //
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
        debug("Entering state ready");
        firstRun = FALSE;
        statusUpdate("");
        teleportAgent = NULL_KEY;
        teleportURI = "";
        teleportLanding = <0,0,0>;
        if(DELAYED_CHECK)
        {
            debug("checking destinations statuses, http timeout set to " + (string)HTTP_TIMEOUT);
            currentStatus="checking status";
            checkDestinationByIndex(0);
            llSetTimerEvent(HTTP_TIMEOUT); //
        } else {
            setNextReload("ready");
        }
    }

    touch_start(integer num_detected)
    {
        touchStarted=llGetTime();
    }

    touch_end(integer num){
        key whoClick = llDetectedKey(0);
        vector point = llDetectedTouchST(0);
        integer face = llDetectedTouchFace(0);
        integer link = llDetectedLinkNumber(0);

        if (link != llGetLinkNumber()) return;
        if (point == TOUCH_INVALID_TEXCOORD) return;
        if (activeSide != ALL_SIDES && llListFindList(ACTIVE_SIDES, (string)face) == -1) return;

        if (whoClick == llGetOwner())
        {
            float touchElapsed = llGetTime() - touchStarted;
            if(touchElapsed > 2 && sourceType=="url") {
                llOwnerSay("/me reload forced by long click");
                state default;
            }
        }

        integer ok = action (getCellClicked(point), whoClick);
    }

    dataserver(key query_id, string data)
    {
        integer destCheckIndex = llListFindList(destinations, query_id);
        if(destCheckIndex >= 0) {
            destinations = llListReplaceList(destinations, [ data ], destCheckIndex, destCheckIndex);
            //string destinationName = llList2String(destinations, destCheckIndex - column);
            //debug (destinationName + " is " + (string)data);
        } else {
            debug("Lost query (should not happen)" + query_id + " status " + data);
        }
        integer column = destCheckIndex % DESTCOLS;
        integer nextIndex = (destCheckIndex - column) + DESTCOLS;
        if(nextIndex >= llGetListLength(destinations)) {
            statusUpdate("");
            drawTable();
        }
        else
        {
            checkDestinationByIndex(nextIndex);
            llSetTimerEvent(HTTP_TIMEOUT); //
        }
    }

    changed(integer change) {
        if (change & CHANGED_INVENTORY) llResetScript();
        if (change & CHANGED_REGION) llResetScript();
    }
    timer()
    {
        if(currentStatus=="checking status") {
            debug("http timed out, release and render");
            statusUpdate("");
            drawTable();
            setNextReload("ready");
        } else if(currentStatus=="ready" && sourceType == "url")
        {
            debug("refresh delay ended, reloading URLs");
            // getSource();
            llResetScript();
        } else {
            debug("refresh delay ended, status=" + currentStatus + ", sourceType=" + sourceType);
            llSetTimerEvent(REFRESH_DELAY);
        }
        //llResetScript();
    }
    on_rez(integer start_param)
    {
        llResetScript();
    }
}

state teleporting {

    state_entry() {
        debug("entering state teleporting");
        debug("checking " + teleportURI);
        teleportCheckId = llRequestSimulatorData(teleportURI, DATA_SIM_STATUS);
        llSetTimerEvent (TP_TIMEOUT);
    }

    dataserver(key query_id, string data)
    {
        if(query_id == teleportCheckId)
        {
            if (data == "up")
            {
                debug("OK, teleporting " + teleportAgent + " to " + teleportURI);
                llInstantMessage(teleportAgent, "Fasten your seat belt, we move!!!");
                osTeleportAgent(teleportAgent, teleportURI, teleportLanding, ZERO_VECTOR);
            } else {
                llInstantMessage(teleportAgent, "Sorry, flight is canceled, region status is " + data);
            }
            debug("saving status " + data + " for " + teleportURI);
            setStatus(teleportURI, data);
            state ready;
        }
    }

    timer() {
        llInstantMessage(teleportAgent, "Destination is offline");
        setStatus(teleportURI, "timeout");
        state ready;
    }
    on_rez(integer start_param)
    {
        debug("reset from state teleporting");
        llResetScript();
    }
}
