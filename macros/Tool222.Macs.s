* NinjaTrackerPlus Tool
* Ninjaforce, 2018
* Brutal Deluxe, 2018
* FTA, 1991

_NTPBootInit         mac
                     Tool  $01DE
                     <<<

~NTPStartUp          mac
                     PHW   ]1
_NTPStartUp          mac
                     Tool  $02DE
                     <<<

_NTPShutDown         mac
                     Tool  $03DE
                     <<<

~NTPVersion          mac
                     phd               ; WordResult
_NTPVersion          mac
                     Tool  $04DE
                     <<<

_NTPReset            mac
                     Tool  $05DE
                     <<<

~NTPStatus           mac
                     phd               ; WordResult
_NTPStatus           mac
                     Tool  $06DE
                     <<<

~NTPLoadOneMusic     mac
                     PHL   ]1
_NTPLoadOneMusic     mac
                     Tool  $09DE
                     <<<

~NTPPlayMusic        mac
                     PHW   ]1
_NTPPlayMusic        mac
                     Tool  $0ADE
                     <<<

_NTPStopMusic        mac
                     Tool  $0BDE
                     <<<

~NTPGetEOfMusic      mac
                     phd               ; WordResult
_NTPGetEOfMusic      mac
                     Tool  $0CDE
                     <<<

~NTPAddToBatch       mac
                     PHLW  ]1;]2
_NTPAddToBatch       mac
                     Tool  $0DDE
                     <<<

~NTPSelectBatch      mac
                     PHW   ]1
_NTPSelectBatch      mac
                     Tool  $0EDE
                     <<<

~NTPKillBatch        mac
                     PHW   ]1
_NTPKillBatch        mac
                     Tool  $0FDE
                     <<<

~NTPGetPlayingMusic  mac
                     phd               ; WordResult
_NTPGetPlayingMusic  mac
                     Tool  $10DE
                     <<<

~NTPPlayBatch        mac
                     PHL   ]1
_NTPPlayBatch        mac
                     Tool  $11DE
                     <<<

~NTPGetTrackVu       mac
                     phd               ;Long
                     phd               ;    Result
_NTPGetTrackVu       mac
                     Tool  $12DE
                     <<<

_NTPPauseMusic       mac
                     Tool  $13DE
                     <<<

_NTPContinueMusic    mac
                     Tool  $14DE
                     <<<

