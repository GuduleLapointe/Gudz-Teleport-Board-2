# Gudule's Teleport Board 2

Get the latest version on Github:
    https://git.magiiic.com/opensimulator/Gudz-Teleport-Board-2

## Features:

* Single or Multi-columns teleport buttons
* Destinations statuses are checked at start and every hour to avoid TP to inactive regions
* Local destinations can be written as HG links and are automatically converted to local links for teleport, so the same board works inside and outside your grid
* Destination source can be set from a notecard or from a web server
* Immediate TP or map (change USE_MAP in config)
* Different colors for current region (green) or offline regions (red), customizable
* Optional background texture
* Can be formatted with titles (text without url), spacer (|) and column jump (-)
* Configuration in a separate notecard to allow easy upgrades
* Long click by the owner to force a full reload

## Setup

The destination list can be set by 3 ways
 - from an external website: put the URL in prim description
   (only the first 2048 bytes will be loaded)
 - from a specific notecard: put "card://CardName" in the description
 - fallback if none of the two first method: read the first notecard found.

In previous versions, the destination list used 5 values. We accept this old
format for backward compatibility but we recommend the simplified format:
*    Displayed Name|your.grid:port
* or Displayed Name|your.grid:port:Region Name
* or Displayed Name|your.grid:port:Region Name|x,y,z

* Empty lines are ignored
* Lines beginning wish "#" are ignored
* Lines commented with "//" are sent as message to the owner during initializaton
* Lines containing only a string (and no url) are drawn as simple text (section titles)
* Lines containing only a separator ("|") are drawn as an empty line (spacer)

Although commenting lines is useful to disable them temporarily (#) or display
help messages (//), it slows down the initialization, so it is better to avoid
it as much as possible.

## Required OSSL Functions:

* osGetGridGatekeeperURI
* osGetNotecard
* osTeleportAgent
* osSetDynamicTextureDataBlendFace and related
   (osDrawFilledRectangle, osDrawRectangle, osDrawText,
   osGetDrawStringSize, osMovePen, osSetFontName, osSetFontSize,
   osSetPenColor, osSetPenSize)

## Licence
Creative Commons BY-NC-SA
