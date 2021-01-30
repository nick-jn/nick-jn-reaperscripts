--[[

MIDI FOCUS AND ZOOM 9000 v0.2

Opens the MIDI editor with consistent, user-defined measure-based horizontal zoom values,
and vertical zoom values. The horizontal zoom values can be changed per track (persistent).

The measures shown are calculated from the right of the current edit cursor location.

Usage: 
       Bind this script to a keyboard key or a mouse action of your choosing
       for opening the MIDI items. The default action is (in Mouse Modifiers settings):
       Media Item -> Double Click -> Default Action. Check the user settings below. Use
       the provided "MFZ9000 - Set zoom settings in MIDI editor.lua" script for user-based
       changes in the MIDI editor (NOT IN THE MAIN WINDOW).

--]]

------------------- USER SETTINGS -------------------

change_measures_externally = true -- use the set zoom settings script to change the shown measures settings,
                                  -- otherwise set to false and manually change the value below
measures_to_show = 8

vertical_zoom_level = 11 -- the script fully zooms out, and then zooms in *this* number of times

open_at_mouse_cursor = false -- will open at mouse cursor instead of at edit cursor if true,
                             -- it will not shift the edit cursor from its original position

-----------------------------------------------------

local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua"

require("_data.constants")
require("_data.helpers")
require("_data.zoom_and_focus")

-- decides how many measures to show based on the settings
local function init_measures_to_show(active_midi_editor) -- RET: void
    local curtrack = __get_track_no_of_item_in_active_midi_editor(active_midi_editor)
    local track_whichzoom = __get_proj_extstate(__KEYSTR_WZOOM, curtrack)

    if change_measures_externally == true then
        if reaper.GetExtState("mfz9000", "def_measures") == "" then
            reaper.SetExtState("mfz9000", "def_measures", measures_to_show, true)
        else
            measures_to_show = tonumber(reaper.GetExtState("mfz9000", "def_measures"))
        end

        -- change the measure zoom to either default or track-based
        if track_whichzoom ~= "" then
            track_whichzoom = tonumber(track_whichzoom)
            if track_whichzoom == 1 then
                measures_to_show = tonumber(__get_proj_extstate(__KEYSTR_TRACKMES, curtrack))
            end
        end
    end
end

------------------------- MAIN ------------------------
reaper.PreventUIRefresh(1)

reaper.Main_OnCommand(40153, 0) -- open midi editor

local active_midi_editor = reaper.MIDIEditor_GetActive()
local saved_cursor_pos = reaper.GetCursorPosition()

init_measures_to_show(active_midi_editor)

if open_at_mouse_cursor == true then
    reaper.Main_OnCommand(40514, 0) -- move edit cursor to mouse cursor (no snapping)
    reaper.Main_OnCommand(41041, 0) -- move edit cursor to start of current measure
end

local saved_ts_lp = set_time_selection_to_n_measures(measures_to_show)
reaper.MIDIEditor_OnCommand(active_midi_editor, 40726) -- zoom to project loop selection
zoom_vertically(active_midi_editor, vertical_zoom_level, measures_to_show, false)
__set_time_and_loop_selection(saved_ts_lp)

if open_at_mouse_cursor == true then
    reaper.SetEditCurPos(saved_cursor_pos, false, false)
end

reaper.PreventUIRefresh(-1)
