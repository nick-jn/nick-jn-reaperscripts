-- @noindex
-- @provides [nomain] .

-- NUMBERS
------------------------------------------------------------------------------
__MIDI_EDITOR_VZOOM_MIN = 4
__MIDI_EDITOR_VZOOM_MAX = 100

-- EXT STATE KEYS
------------------------------------------------------------------------------
__KEYSTR_TRACKMES = "track-measures_"
__KEYSTR_WZOOM    = "track-whichzoom_"

__KEYSTR_USER_HOR_ZOOM_TO_MOUSE_CURSOR            = "__KEYSTR_USER_HOR_ZOOM_TO_MOUSE_CURSOR"            -- 1
__KEYSTR_USER_HOR_ZOOM_TO_MOUSE_CURSOR_MOVE_EDCUR = "__KEYSTR_USER_HOR_ZOOM_TO_MOUSE_CURSOR_MOVE_EDCUR" -- 2
__KEYSTR_USER_ITEM_CLICKED_AT_END_OFFSET          = "__KEYSTR_USER_ITEM_CLICKED_AT_END_OFFSET"          -- 3
__KEYSTR_USER_ITEM_CLICKED_AT_END_THRESHOLD       = "__KEYSTR_USER_ITEM_CLICKED_AT_END_THRESHOLD"       -- 4
__KEYSTR_USER_SHOW_ONLY_THE_SELECTED_ITEM         = "__KEYSTR_USER_SHOW_ONLY_THE_SELECTED_ITEM"         -- 6
__KEYSTR_USER_CENTER_SMALL_ITEMS                  = "__KEYSTR_USER_CENTER_SMALL_ITEMS"                  -- 5
__KEYSTR_USER_CENTER_SMALL_ITEMS_LENGTH           = "__KEYSTR_USER_CENTER_SMALL_ITEMS_LENGTH"           -- 7
__KEYSTR_USER_PAD_SMALL_ITEMS                     = "__KEYSTR_USER_PAD_SMALL_ITEMS"                     -- 8
__KEYSTR_USER_PAD_SMALL_ITEMS_AMOUNT              = "__KEYSTR_USER_PAD_SMALL_ITEMS_AMOUNT"              -- 9

-- CFGEDITVIEW TYPES
------------------------------------------------------------------------------
__CFGEV_HSTARTPOS = 1
__CFGEV_HZOOM     = 2 -- float (!), zoomed all the way in == 2000, zoomed all the way out == 0, normal zoom ranges are within [0,1] (float)
__CFGEV_VSTARTPOS = 3
__CFGEV_VZOOM     = 4 -- zoomed all the way out == 4, zoomed all the way in == 100, this one is an integer

-- USER SETTINGS
------------------------------------------------------------------------------
__USER_HOR_ZOOM_TO_MOUSE_CURSOR            = nil
__USER_HOR_ZOOM_TO_MOUSE_CURSOR_MOVE_EDCUR = nil
__USER_ITEM_CLICKED_AT_END_OFFSET          = nil
__USER_ITEM_CLICKED_AT_END_THRESHOLD       = nil
__USER_SHOW_ONLY_THE_SELECTED_ITEM         = nil
__USER_CENTER_SMALL_ITEMS                  = nil
__USER_CENTER_SMALL_ITEMS_LENGTH           = nil
__USER_PAD_SMALL_ITEMS                     = nil
__USER_PAD_SMALL_ITEMS_AMOUNT              = nil
