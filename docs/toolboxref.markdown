---
layout: page
title: Toolbox Reference
style: toolref
permalink: /tool-ref/
---

<link rel="stylesheet" href="/assets/css/toolref.css">
<div id="content">

 <ul>
  <li><a href="#Init">Intialization Functions</a></li>
  <li><a href="#Sprite">Sprite Functions</a></li>
  <li><a href="#Tile">Tile Functions</a></li>
  <li><a href="#Buffer">Buffer Functions</a></li>
  <li><a href="#IO">I/O Functions</a></li>
 </ul>

 <div class="api_intro">
  <h1>GTE Tool Set</h1>

  <p>
  The <em>Generic Tile Engine (GTE)</em> Tool Set enables tile-based games to be implemented in an efficient manner. The tool set provides support for sprites, animations, large scrolling backgrounds and special effects.
  </p>

  <p>
  To effectively use this tool set, a user should be familiar with the following
   </p><ul>
    <li>The IIgs Hardware Reference</li>
    <li>The QuickDraw II tool set</li>
    <li>IIgs Technical Note #70</li>
   </ul>
  <p></p>

  <h2>A preview of the GTE Tool Set routines</h2>

  <p>
 To introduce you to the capabilities of the GTE Tool Set the routines are grouped by function and briefly described in Table 1. These routines are descibed in detail later where they are separated into housekeeping routines (discussed in routine number order) and the rest of the GTE Tool Set routines (discussed in alphabetical order).
  </p>

 <table class="intro">
  <tbody>
    <tr>
        <th colspan="2">Table 1</th>
    </tr>
    <tr>
        <th colspan="2" style="font-weight: normal;">GTE Tool Set routines and their functions</th>
    </tr>
    <tr class="intro_header">
        <th>Routine</th>
        <th>Description</th>
    </tr>
    <tr>
        <th colspan="2">Housekeeping Routines</th>
    </tr>
  <tr><td>GTEBootInit</td><td>Initializes the GTE Tool Set; called only by the Tool Locator — must not be called by an application</td></tr>
  <tr><td>GTEStartUp</td><td>Starts up the GTE Tool Set for use by an application</td></tr>
  <tr><td>GTEShutDown</td><td>Shuts down the GTE Tool Set when an application quits</td></tr>
  <tr><td>GTEVersion</td><td>Returns the version number of the GTE Tool Set</td></tr>
  <tr><td>GTEReset</td><td>Resets the GTE Tool Set; called only when the system is reset — must not be called by an application</td></tr>
  <tr><td>GTEStatus</td><td>Indicates whether the GTE Tool Set is active</td></tr>
 
  <tr><th colspan="2">Sprite Routines</th><th></th></tr>
  <tr><td>GTECreateSpriteStamp</td><td>	Creates a sprite stamp from the tile set</td></tr>
  <tr><td>GTEAddSprite</td><td>Add a active sprite to the scene</td></tr>
  <tr><td>GTEMoveSprite</td><td>Changes a sprite's location</td></tr>
  <tr><td>GTEUpdateSprite</td><td>Changes a sprite's tile set reference and display flags</td></tr>
  <tr><td>GTERemoveSprite</td><td>	Removes a sprite from the scene</td></tr>

  <tr><th colspan="2">Tile Routines</th></tr>
  <tr><td>GTELoadTileSet</td><td>Copies a tileset into the GTE tileset memory</td></tr>
  <tr><td>GTESetTile</td><td>Assigns a tile to a tile map index</td></tr>

  <tr><th colspan="2">Primary Background Routines</th></tr>
  <tr><td>GTESetBG0Origin</td><td>Sets the upper-left origin point in the primary background</td></tr>
  <tr><td>GTERender</td><td>Draws the current scene to the graphics screen</td></tr>

  <tr><th colspan="2">Functions affecting the global state</th></tr>
  <tr><td>GTESetScreenMode</td><td>Sets the playing field's port rectangle to a pre-defined size, or a specified width and height</td></tr>

  <tr><th colspan="2">Misc. Functions</th></tr>
  <tr><td>GTEReadControl</td><td>Reads the keyboard and returns key events in a gamepad structure</td></tr>
  <tr><td>GTEGetSeconds</td><td>Returns the number of seconds elapsed since the toolset was started</td></tr>
 </tbody></table>

 <h2>Using the GTE Tool Set</h2>
 <p>
 This section discusses how the GTE Tool Set routines fit into the general flow of an application and gives you an idea of which routines you'll need to use under normal circumstances.  Each routine is described in detail later in this chapter.

The GTE Tool Set depends on the presence of the tool sets shown in Table 2 and requires at least the indicated version of each tool set be present.

 </p>
<table class="intro">
  <tbody><tr><th colspan="4">Table 2</th></tr>
  <tr><th colspan="4" style="font-weight: normal;">GTE Tool Set — other tool sets required</th></tr>
  <tr class="intro_header"><th colspan="2">Tool set number</th><th>Tool set name</th><th>Minimal version needed</th></tr>
  <tr><td>$01</td><td>#01</td><td>Tool Locator</td><td>3.x</td></tr> 
  <tr><td>$02</td><td>#02</td><td>Memory Manager</td><td>3.x</td></tr> 
  <tr><td>$03</td><td>#03</td><td>Miscellaneous Tool Set</td><td>3.2</td></tr> 
  <tr><td>$06</td><td>#06</td><td>Event Manager</td><td>3.1</td></tr>
 </tbody></table>

 <p>
To use the GTE Tool Set routines, your application must call the GTEStartUp routine before making any other GTE calls.  To save memory, the GTE Tool Set may be started up with some features disabled.  See the section <a href="#GTEStartUp">GTEStartUp</a> in this chapter for further details.
 </p>
 <p>
Your application should also make the GTEShutDown call when the application quits.
 </p>
</div>

<div class="api">
 <h4 class="tn">$01XX</h4>

 <h4>GTEBootInit</h4>
 <p>
  Initializes the GTE Tool Set; called only by the Tool Locator.
 </p>
 <div class="warning">
  <p>
  An application must never make this call
  </p>
 </div>
 
 <div class="section">
  <h5>Parameters</h5> 
  <p>
   The stack is not affected by this call.  There are no input or output parameters.
 </p>
 </div>

 <div class="section">
  <h5>Errors</h5> 
  <p>None</p>
 </div>

 <div class="section">
  <h5>C</h5> 
  <p>Call must not be made by an application.</p>
 </div>
</div>

<div class="api">
 <h4 class="tn">$02XX</h4>
 <h4>GTEStartUp</h4>
 <p>
 Starts up the GTE Tool Set for use by an application.
 </p>

 <div class="important">
  <p>
  Your application must make this call before it makes any other GTE Tool Set calls.
  </p>
 </div>
 
 <p>
 The GTE Tool Set uses two consecutive pages of bank zero for its direct page space starting at <it>dPageAddr</it>.  If the <tt>ENGINE_MODE_DYN_TILES</tt> flag is set in the <it>capFlags</it>, the GTE will attempt to allocate an <em>additional</em> eight pages of bank zero space. If the <tt>ENGINE_MODE_BNK0_BUFF</tt> flag is set, then GTE will attempt to allocate an ~32KB buffer from $2000 to $9CFF in Bank 0.
 </p>

 <div class="section">
  <h5>Parameters</h5>

  <table class="stack">
   <colgroup>
     <col>
     <col style="width: 2em">
   </colgroup>
   <tbody><tr><th>Stack before call</th></tr>
   <tr><td class="top">previous contents</td></tr>
   <tr><td class="bot">dPageAddr</td><td></td><td><em>Word</em></td><td>16-bit address of two pages of page-aligned Bank 0 memory</td></tr>
   <tr><td class="bot">capFlags</td><td></td><td><em>Word</em></td><td>Capability flags to set the engine mode</td></tr>
   <tr><td class="bot">userID</td><td></td><td><em>Word</em></td><td>Application word returned by the Memory Manager. All memory allocated by GTE will use this userId</td></tr>
   <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
  </tbody></table>

  <table class="stack">
   <colgroup>
     <col>
     <col style="width: 2em">
   </colgroup>
   <tbody><tr><th>Stack after call</th></tr>
   <tr><td class="top">previous contents</td></tr>
   <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
  </tbody></table>

  <table role="table">
<thead>
<tr>
<th>capFlags</th>
<th></th>
<th></th>
</tr>
</thead>
<tbody>
<tr>
<td>ENGINE_MODE_TWO_LAYER</td>
<td>$0001</td>
<td>Enables the second background layer.  This will have a moderate impact on rendering performance.</td>
</tr>
<tr>
<td>ENGINE_MODE_DYN_TILES</td>
<td>$0002</td>
<td>Enables the use of dynamic (animated) tiles.  This will have a small impact on performance and requires allocating 8 pages of Bank 0 memory</td>
</tr>
<tr>
<td>ENGINE_MODE_BNK0_BUFF</td>
<td>$0004</td>
<td>Allocates a 32KB buffer in Bank 0 for advanced graphical effects and customizations.</td>
</tr>
</tbody>
</table>
 </div>


 <div class="section">
  <h5>Errors</h5>
  <table>
   <tbody>
   <tr><td colspan="2">Memory Manager Errors</td><td>Returned unchanged</td></tr>
  </tbody></table>
 </div>

 <div class="section">
  <h5>C</h5>
  <table style="font-family: courier, monospace; font-size: smaller;">
   <tbody><tr><td>extern pascal GTEStartUp(dPageAddr, capFlags, userID)</td></tr>
   <tr><td>Word     dPageAddr</td></tr>
   <tr><td>Word     capFlags</td></tr>
   <tr><td>Word     userID</td></tr>
  </tbody></table>
 </div>
</div>

<div class="api">
 <h4 class="tn">$03XX</h4>
 <h4>GTEShutDown</h4>

 <div class="section">
  <h5>Parameters</h5> 
  <p>
   The stack is not affected by this call.  There are no input or output parameters.
 </p>
 </div>

 <div class="section">
  <h5>Errors</h5> 
  <p>None</p>
 </div>

 <div class="section">
  <h5>C</h5> 
  <p><tt>extern pascal void GTEShutDown()</tt></p> 
 </div>
</div>

<div class="api">
 <h4 class="tn">$04XX</h4>
 <h4>GTEVersion</h4>
 <p>
  Returns the version number of the GTE Tool Set.
 </p>

 <div class="section">
  <h5>Parameters</h5>

  <table class="stack">
   <tbody><tr><th>Stack before call</th></tr>
   <tr><td class="top">previous contents</td></tr>
   <tr><td class="bot">wordspace</td><td></td><td><em>Word</em> — Space for result</td></tr>
   <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
  </tbody></table>

  <table class="stack">
   <tbody><tr><th>Stack after call</th></tr>
   <tr><td class="top">previous contents</td></tr>
   <tr><td class="bot">versionInfo</td><td></td><td><em>Word</em> — Version number of the GTE Tool Set.</td></tr>
   <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
  </tbody></table>
 </div>

 <div class="section">
  <h5>Errors</h5>
  <p>None</p>
 </div>

 <div class="section">
  <h5>C</h5>
  <p><tt>extern pascal Word GTEVersion()</tt></p>
 </div>
</div>

<div class="api">
 <h4 class="tn">$05XX</h4>
 <h4>GTEReset</h4>
 <p>
  Resets the GTE Tool Set; called only when the system is reset.
 </p>

 <div class="warning">
  <p>
  An application must never make this call
  </p>
 </div>

 <div class="section">
  <h5>Parameters</h5>
  <p>The stack is not affected by this call.  There are no input or output parameters</p>
 </div>

 <div class="section">
  <h5>Errors</h5>
  <p>None</p>
 </div>

 <div class="section">
  <h5>C</h5>
  <p>Call must not be made by an application.</p>
 </div>
</div>

<div class="api">
 <h4 class="tn">$06XX</h4>
 <h4>GTEStatus</h4>

 <p>
 Indicates whether the GTE Tool Set is active.
 </p>

 <div class="section">
  <h5>Parameters</h5>

  <table class="stack">
   <tbody><tr><th>Stack before call</th></tr>
   <tr><td class="top">previous contents</td></tr>
   <tr><td class="bot">wordspace</td><td></td><td><em>Word</em> — Space for result</td></tr>
   <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
  </tbody></table>

  <table class="stack">
   <tbody><tr><th>Stack after call</th></tr>
   <tr><td class="top">previous contents</td></tr>
   <tr><td class="bot">activeFlag</td><td></td><td><em>Word</em> — BOOLEAN; TRUE if GTE Tool Set active, FALSE if inactive</td></tr>
   <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
  </tbody></table>
 </div>

 <div class="section">
  <h5>Errors</h5>
  <p>None</p>
 </div>

 <div class="section">
  <h5>C</h5>
  <p><tt>extern pascal Boolean GTEStatus()</tt></p>
 </div>
</div>

<div class="transition">
GTE Tool Set routines
</div>

<div class="api">
 <h4 class="tn">$09XX</h4>
 <h4>GTEGetAddress</h4>
  
 <p>
 Returns the address of an internal GTE Tool Set array.  
 </p>

 <div class="section">
  <table class="stack">
   <tbody><tr><th>Stack before call</th></tr>
   <tr><td class="top">previous contents</td></tr>
   <tr><td class="bot">addrId</td><td></td><td><em>WORD</em> — INTEGER id</td></tr>
   <tr><td class="bot">longspace</td><td></td><td><em>Long</em> — Space for result</td></tr>
   <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
  </tbody></table>

  <table class="stack">
   <tbody><tr><th>Stack after call</th></tr>
   <tr><td class="top">previous contents</td>
   </tr><tr><td class="bot">address</td><td></td><td><em>Long</em> — POINTER to data structure</td></tr>
   <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
  </tbody></table>
 </div>

 <div class="section">
  <h5>Errors</h5>
   <table>
    <tbody><tr><td>$XX04</td><td>gteBadAddress</td><td>The id is invalid</td></tr>   
   </tbody></table>
 </div>

 <div class="section">
  <h5>C</h5>
  <pre>extern pascal Pointer GTEGetAddress(id)
Word         id
  </pre>
 </div>
</div>

<div class="api">
 <h4 class="tn">$0CXX</h4>
 <h4>GTENewSprite</h4>

 <p>
  Allocates space for a new sprite and compiles it based on the pixel data in the locInfoPtr arguement.  The sprite flags word is used to enable or disable certain capabilities.  If an application does not need the all the features enabled, features may be disabled to save memory and slightly increase performance.
 </p>

<!--
 <p>
  The general structure of a compiled sprite is shown in Listing ??. There is a small header followed by a up to four jump tables.
 </p>
 <pre>
return  JML rtn_from_sprite
remove  JML remove_sprite
header  TAX
        JMP (disp,x)
guard0  dc  a2'remove'
right0  dc  a2'rline00'
        dc  a2'rline01'
        .
        .
        dc  a2'rline0N'
guard1  dc  a2'remove'
left0   dc  a2'lline00'
        dc  a2'lline01'
        .
        .
        dc  a2'lline0N'
guard2  dc  a2'remove'
right1  dc  a2'rline10'
        dc  a2'rline11'
        .
        .
        dc  a2'rline1N'
guard3  dc  a2'remove'
left1   dc  a2'lline10'
        dc  a2'lline11'
        .
        .
        dc  a2'lline1N'
guard4  dc  a2'remove'

rline00 brl return
rline01 brl return
.
.
rline0N brl return
 </pre>
-->

 <div class="section">
  <h5>Parameters</h5>

  <table class="stack">
   <tbody><tr><th>Stack before call</th></tr>
   <tr><td class="top">previous contents</td></tr>
   <tr><td class="bot">ptrToDataLocInfo</td><td></td><td><em>Long</em> — POINTER to data location information.</td></tr>
   <tr><td class="bot">ptrToDataRect</td><td></td><td><em>Long</em> — POINTER to a Rect that defines the sprite bounds.</td></tr>
   <tr><td class="bot">ptrToMaskLocInfo</td><td></td><td><em>Long</em> — POINTER to mask location information; may be nil.</td></tr>
   <tr><td class="bot">ptrToMaskRect</td><td></td><td><em>Long</em> — POINTER to a Rect that defines the sprite bounds; may be nil.</td></tr>
   <tr><td class="bot">spriteFlags</td><td></td><td><em>Word</em> — INTEGER; sprite flags</td></tr>
   <tr><td class="bot">longspace</td><td></td><td><em>Long</em> — Space for result</td></tr>
   <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
  </tbody></table>

  <table class="stack">
   <tbody><tr><th>Stack after call</th></tr>
   <tr><td class="top">previous contents</td>
   </tr><tr><td class="bot">spriteHandle</td><td></td><td><em>Long</em> — HANDLE to new sprite</td></tr>
   <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
  </tbody></table>
 </div>

 <div class="section">
  <h5>Errors</h5>
  <p>None</p>
 </div>

 <div class="section">
  <h5>C</h5>
  <pre>extern pascal SpriteHandle GTENewSprite(data, mask, spriteFlags)
locInfoPtr   data
locInfoPtr   mask
Word         spriteFlags
  </pre>
 </div>
</div>

<div>
 <h4>Sprite Flags</h4>

 <p>
 </p>
 <p>
 The values available for <em>spriteFlags</em> are shown in Figure ??-??.
 </p>
 <table class="bits">
  <colgroup span="11" style="background-color: #999;">
  </colgroup><colgroup span="4" style="background-color: lightgreen;">
  </colgroup><colgroup style="background-color: #999;">
  </colgroup><colgroup span="1" style="background-color: #999;">
  </colgroup><tbody><tr><td>15</td><td>14</td><td>13</td><td>12</td><td>11</td><td>10</td><td>9</td><td>8</td><td>7</td><td>6</td><td>5</td><td>4</td><td>3</td><td>2</td><td>1</td><td>0</td></tr>
 </tbody></table>

<p></p>

 <table>
  <tbody><tr><th style="width: 6em"></th><th style="width: 6em"></th><th></th></tr>
  <tr><td>Bits 0</td><td><em>spriteType</em></td><td>Reserved; must be zero</td></tr>
  <tr><td>Bit 1</td><td>fNoHFlip</td><td>Do not create a horizontally flipped version of the sprite.  Setting the horizontal flip bit in the Object Attribute Memory will have no effect.</td></tr>
  <tr><td>Bit 2</td><td>fNoVFlip</td><td>Do not create a vertically flipped version of the sprite.  Setting the vertical flip bit in the Object Attribute Memory will have no effect.</td></tr>
  <tr><td>Bit 3</td><td><em>fNoPriority</em></td><td>Do not generate code to honor the field mask.  Seting the priority bit in the Object Attribute Memory will have no effect.</td></tr>
  <tr><td>Bit 4</td><td><em>fNoMask</em></td><td> This sprite will not clip itself to the playing fields.  This is potentially dangerous since, if the sprite move off screen, it may corrupt system memory.  Only use this bit if the sprite will never leave the playing field.</td></tr>
  <tr><td>Bits 5-15</td><td>Reserved</td><td>must be zero.</td></tr>
 </tbody></table>
</div>

<div class="api">
 <h4 class="tn">$0DXX</h4>
 <h4>GTEDisposeSprite</h4>

 <div class="section">
  <h5>Parameters</h5>

  <table class="stack">
   <tbody><tr><th>Stack before call</th></tr>
   <tr><td class="top">previous contents</td></tr>
   <tr><td class="bot">spriteHandle</td><td></td><td><em>Long</em> — Handle to a sprite returned by GTENewSprite.</td></tr>
   <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
  </tbody></table>

  <table class="stack">
   <tbody><tr><th>Stack after call</th></tr>
   <tr><td class="top">previous contents</td></tr>
   <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
  </tbody></table>
 </div>

 <div class="section">
  <h5>Error</h5>
  <p>None</p>
 </div>

 <div class="section">
  <h5>C</h5>
<pre>extern pascal void GTEDisposeSprite(spriteHndl)
Handle       spriteHndl
</pre>
 </div>
</div>

<!--
<div class="api">
 <h4 class="tn">$XXXX</h4>
 <h4>GTEClearOAM</h4>

 <div class="section">
  <h5>Parameters</h5>
  <p>
   The stack is not affected by this call.  There are no input or output parameters.
 </p>
 </div>

 <div class="section">
  <h5>Errors</h5>
  <p>None</p>
 </div>

 <div class="section">
  <h5>C</h5>
  <p><tt>extern pascal void GTEClearOAM()</tt></p>
 </div>
</div>

<div class="api">
 <h4 class="tn">$XXXX</h4>
 <h4>GTEDrawSprite</h4>

 <div class="section">
  <h5>Parameters</h5>
  <table class="stack">
   <tr><th>Stack before call</th></tr>
   <tr><td class="top">previous contents</td></tr>
   <tr><td class="bot"></td><td><em>&larr;</em></td><td><em>SP</em></td></tr>
  </table>

  <table class="stack">
   <tr><th>Stack after call</th></tr>
   <tr><td class="top">previous contents</td></tr>
   <tr><td class="bot"></td><td><em>&larr;</em></td><td><em>SP</em></td></tr>
  </table>
 </div>

 <div class="section">
  <h5>Errors</h5>
  <p>None</p>
 </div>

 <div class="section">
  <h5>C</h5>
  <p><tt>extern pascal void </tt></p>
 </div>
</div>
-->

<div class="api">
 <h4 class="tn">$0FXX</h4>
 <h4>GTENewTile</h4>

 <p>
 Allocates space for a new tile and compiles it based on the pixel data referenced by the locInfoPtr arguements.  If the mask infoRecPtr is nil, then the mask is computed using the current backgound color.  The mask is only used when the tile map specifies the tile to be drawn at high priority.
 </p>

 <div class="section">
  <h5>Parameters</h5>
  <table class="stack">
   <tbody><tr><th>Stack before call</th></tr>
   <tr><td class="top">previous contents</td></tr>
   <tr><td class="bot">ptrToDataLocInfo</td><td></td><td><em>Long</em> — POINTER to data location information.</td></tr>
   <tr><td class="bot">ptrToDataOrigin</td><td></td><td><em>Long</em> — POINTER to Point that marks the top-left corner.</td></tr>
   <tr><td class="bot">ptrToMaskLocInfo</td><td></td><td><em>Long</em> — POINTER to mask location information; may be nil.</td></tr>
   <tr><td class="bot">ptrToMaskOrigin</td><td></td><td><em>Long</em> — POINTER to Point that marks the top-left corner; may be nil.</td></tr>
   <tr><td class="bot">longspace</td><td></td><td><em>Long</em> — Space for result</td></tr>
   <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
  </tbody></table>

  <table class="stack">
   <tbody><tr><th>Stack after call</th></tr>
   <tr><td class="top">previous contents</td></tr>
   <tr><td class="bot">tileHandle</td><td></td><td><em>Long</em> — HANDLE to new tile</td></tr>
   <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
  </tbody></table>
 </div>

 <div class="section">
  <h5>Erros</h5>
  <p>None</p>
 </div>

 <div class="section">
  <h5>C</h5>
  <pre>extern pascal TileHandle GTENewTile(ptrToDataLocInfo, ptrToDataOrigin, ptrToMaskLocInfo, ptrToMaskOrigin)
locInfoPtr   ptrToDataLocInfo
Point*       ptrToDataOrigin
locInfoPtr   ptrToMaskLocInfo
Point*       ptrToMaskOrigin
  </pre>
 </div>
</div>

<div class="api">
 <h4 class="tn">$10XX</h4>
 <h4>GTEDisposeTile</h4>

 <div class="section">
  <h5>Parameters</h5>

  <table class="stack">
   <tbody><tr><th>Stack before call</th></tr>
   <tr><td class="top">previous contents</td></tr>
   <tr><td class="bot">tileHandle</td><td></td><td><em>Long</em> — Handle to a tile returned by GTENewTile.</td></tr>
   <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
  </tbody></table>

  <table class="stack">
   <tbody><tr><th>Stack after call</th></tr>
   <tr><td class="top">previous contents</td></tr>
   <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
  </tbody></table>
 </div>

 <div class="section">
  <h5>Error</h5>
  <p>None</p>
 </div>

 <div class="section">
  <h5>C</h5>
  <pre>extern pascal void GTEDisposeTile(tileHandle)
Handle       tileHandle
</pre>
 </div>
</div>

<div>
 <h4 class="tn">$11XX</h4>
 <h4>GTESetTile</h4>
 <div class="parameters">
  <h5>Parameters</h5>
   <table class="stack">
    <tbody><tr><th>Stack before call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="stack">
    <tbody><tr><th>Stack after call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="errors">
    <tbody><tr><th><h5>Errors</h5></th><td><p>None</p></td></tr>
    <tr><th><h5>C</h5></th><td><tt>extern</tt></td></tr>
  </tbody></table> 
 </div>
</div>

<div>
 <h4 class="tn">$12XX</h4>
 <h4>GTEGetTile</h4>
 <div class="parameters">
  <h5>Parameters</h5>
   <table class="stack">
    <tbody><tr><th>Stack before call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="stack">
    <tbody><tr><th>Stack after call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="errors">
    <tbody><tr><th><h5>Errors</h5></th><td><p>None</p></td></tr>
    <tr><th><h5>C</h5></th><td><tt>extern</tt></td></tr>
  </tbody></table> 
 </div>
</div>

<a name="Buffer"><h3>Buffer Functions</h3></a>

<div>
 <h4>GTESetBG0Fringe</h4>
 <div class="parameters">
  <h5>Parameters</h5>
   <table class="stack">
    <tbody><tr><th>Stack before call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="stack">
    <tbody><tr><th>Stack after call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="errors">
    <tbody><tr><th><h5>Errors</h5></th><td><p>None</p></td></tr>
    <tr><th><h5>C</h5></th><td><tt>extern</tt></td></tr>
  </tbody></table> 
 </div>
</div>

<div>
 <h4>GTESetBG0Mask</h4>
 <div class="parameters">
  <h5>Parameters</h5>
   <table class="stack">
    <tbody><tr><th>Stack before call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="stack">
    <tbody><tr><th>Stack after call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="errors">
    <tbody><tr><th><h5>Errors</h5></th><td><p>None</p></td></tr>
    <tr><th><h5>C</h5></th><td><tt>extern</tt></td></tr>
  </tbody></table> 
 </div>
</div>

<div>
 <h4>GTESetBG0Dynamic</h4>
 <div class="parameters">
  <h5>Parameters</h5>
   <table class="stack">
    <tbody><tr><th>Stack before call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="stack">
    <tbody><tr><th>Stack after call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="errors">
    <tbody><tr><th><h5>Errors</h5></th><td><p>None</p></td></tr>
    <tr><th><h5>C</h5></th><td><tt>extern</tt></td></tr>
  </tbody></table> 
 </div>
</div>

<div>
 <h4>GTESetBG0Palettes</h4>
 <div class="parameters">
  <h5>Parameters</h5>
   <table class="stack">
    <tbody><tr><th>Stack before call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="stack">
    <tbody><tr><th>Stack after call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="errors">
    <tbody><tr><th><h5>Errors</h5></th><td><p>None</p></td></tr>
    <tr><th><h5>C</h5></th><td><tt>extern</tt></td></tr>
  </tbody></table> 
 </div>
</div>

<div>
 <h4>GTESetBG0Origin</h4>
 <div class="parameters">
  <h5>Parameters</h5>
   <table class="stack">
    <tbody><tr><th>Stack before call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="stack">
    <tbody><tr><th>Stack after call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="errors">
    <tbody><tr><th><h5>Errors</h5></th><td><p>None</p></td></tr>
    <tr><th><h5>C</h5></th><td><tt>extern</tt></td></tr>
  </tbody></table> 
 </div>
</div>

<div>
 <h4>GTESetBG1Tiles</h4>
 <div class="parameters">
  <h5>Parameters</h5>
   <table class="stack">
    <tbody><tr><th>Stack before call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="stack">
    <tbody><tr><th>Stack after call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="errors">
    <tbody><tr><th><h5>Errors</h5></th><td><p>None</p></td></tr>
    <tr><th><h5>C</h5></th><td><tt>extern</tt></td></tr>
  </tbody></table> 
 </div>
</div>

<div>
 <h4>GTESetBG1Origin</h4>
 <div class="parameters">
  <h5>Parameters</h5>
   <table class="stack">
    <tbody><tr><th>Stack before call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="stack">
    <tbody><tr><th>Stack after call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="errors">
    <tbody><tr><th><h5>Errors</h5></th><td><p>None</p></td></tr>
    <tr><th><h5>C</h5></th><td><tt>extern</tt></td></tr>
  </tbody></table> 
 </div>
</div>

<div>
 <h4>GTERefreshAll</h4>
 <div class="parameters">
  <h5>Parameters</h5>
   <table class="stack">
    <tbody><tr><th>Stack before call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="stack">
    <tbody><tr><th>Stack after call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="errors">
    <tbody><tr><th><h5>Errors</h5></th><td><p>None</p></td></tr>
    <tr><th><h5>C</h5></th><td><tt>extern</tt></td></tr>
  </tbody></table> 
 </div>
</div>

<div>
 <h4>GTERefreshBG0</h4>
 <div class="parameters">
  <h5>Parameters</h5>
   <table class="stack">
    <tbody><tr><th>Stack before call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="stack">
    <tbody><tr><th>Stack after call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="errors">
    <tbody><tr><th><h5>Errors</h5></th><td><p>None</p></td></tr>
    <tr><th><h5>C</h5></th><td><tt>extern</tt></td></tr>
  </tbody></table> 
 </div>
</div>

<div>
 <h4>GTERefreshBG1</h4>
 <div class="parameters">
  <h5>Parameters</h5>
   <table class="stack">
    <tbody><tr><th>Stack before call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="stack">
    <tbody><tr><th>Stack after call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="errors">
    <tbody><tr><th><h5>Errors</h5></th><td><p>None</p></td></tr>
    <tr><th><h5>C</h5></th><td><tt>extern</tt></td></tr>
  </tbody></table> 
 </div>
</div>

<a name="IO"><h3>I/O Functions</h3></a>

<div>
 <h4>GTELoadAPF</h4>
 <div class="parameters">
  <h5>Parameters</h5>
   <table class="stack">
    <tbody><tr><th>Stack before call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="stack">
    <tbody><tr><th>Stack after call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="errors">
    <tbody><tr><th><h5>Errors</h5></th><td><p>None</p></td></tr>
    <tr><th><h5>C</h5></th><td><tt>extern</tt></td></tr>
  </tbody></table> 
 </div>
</div>

<div>
 <h4>GTELoadBMP</h4>
 <div class="parameters">
  <h5>Parameters</h5>
   <table class="stack">
    <tbody><tr><th>Stack before call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="stack">
    <tbody><tr><th>Stack after call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="errors">
    <tbody><tr><th><h5>Errors</h5></th><td><p>None</p></td></tr>
    <tr><th><h5>C</h5></th><td><tt>extern</tt></td></tr>
  </tbody></table> 
 </div>
</div>

<div>
 <h4>GTELoadSHR</h4>
 <div class="parameters">
  <h5>Parameters</h5>
   <table class="stack">
    <tbody><tr><th>Stack before call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="stack">
    <tbody><tr><th>Stack after call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="errors">
    <tbody><tr><th><h5>Errors</h5></th><td><p>None</p></td></tr>
    <tr><th><h5>C</h5></th><td><tt>extern</tt></td></tr>
  </tbody></table> 
 </div>
</div>

<div>
 <h4>GTELoadFile</h4>
 <div class="parameters">
  <h5>Parameters</h5>
   <table class="stack">
    <tbody><tr><th>Stack before call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="stack">
    <tbody><tr><th>Stack after call</th></tr>
    <tr><td class="top">previous contents</td></tr>
    <tr><td class="bot"></td><td><em>←</em></td><td><em>SP</em></td></tr>
   </tbody></table>

   <table class="errors">
    <tbody><tr><th><h5>Errors</h5></th><td><p>None</p></td></tr>
    <tr><th><h5>C</h5></th><td><tt>extern</tt></td></tr>
  </tbody></table> 
 </div>
</div>
</div>
