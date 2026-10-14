-- chord voice
--
-- plays the current chord of the chord progression, as a block chord or an
-- arpeggio, on passersby or an nb voice. handy for trying out progressions.
-- it steps with the beats of the progression, so it stays in time with the
-- chord changes and starts over with the sequence. it plays on while the
-- sequencer is stopped, for trying out a progression on its own: switch it
-- off to silence it.
--
-- passersby has one voice, shared with the sequencer voices: a block chord
-- plays there as an arpeggio up.

local chord_voice = {}

local OFF, PASSERSBY, NB = 1, 2, 3
local BLOCK, UP, DOWN, UP_DOWN, RANDOM = 1, 2, 3, 4, 5
local styles = { "block", "up", "down", "up-down", "random" }
local rates = { { "1 bar", 4 }, { "1/2", 2 }, { "1/4", 1 }, { "1/8", 1/2 }, { "1/16", 1/4 } }
local DEFAULT_RATE = 4 -- 1/8
local GATE = 0.9 -- of a step, for the length of the nb notes
local VELOCITY = 0.8
local ENGINE_ID = 3 -- after the two sequencer voices

local output = OFF
local style = UP
local rate = rates[DEFAULT_RATE][2]
local octave = 0
local last_step = nil
local chord_key = nil -- the chord that is playing
local chord_start = 0 -- the step it started on

-- redefine in user script: the notes of the current chord, lowest first,
-- or nil when there is no chord
function chord_voice.notes() return nil end

-- redefine in user script: the steps in an octave
function chord_voice.period() return 12 end

function chord_voice.is_on()
  return output ~= OFF
end

-- the number of params add_params adds, for the group they are in
function chord_voice.param_count(nb)
  return nb and 6 or 4 -- an nb selector is two params
end

local function show_params(nb)
  local ids = { "chord_voice_style", "chord_voice_rate", "chord_voice_octave" }
  for _, id in ipairs(ids) do
    if output == OFF then params:hide(id) else params:show(id) end
  end
  if nb then
    if output == NB then params:show("chord_voice_nb") else params:hide("chord_voice_nb") end
  end
  _menu.rebuild_params()
end

function chord_voice.add_params(nb)
  local outputs = { "off", "passersby" }
  if nb then table.insert(outputs, "nb") end
  params:add_option("chord_voice", "chord voice", outputs, OFF)
  params:set_action("chord_voice", function(x)
    output = x
    show_params(nb)
  end)
  if nb then nb:add_param("chord_voice_nb", "chord voice -> nb") end
  params:add_option("chord_voice_style", "chord voice style", styles, UP)
  params:set_action("chord_voice_style", function(x) style = x end)
  local rate_names = {}
  for i, r in ipairs(rates) do rate_names[i] = r[1] end
  params:add_option("chord_voice_rate", "chord voice rate", rate_names, DEFAULT_RATE)
  params:set_action("chord_voice_rate", function(x) rate = rates[x][2] end)
  params:add_number("chord_voice_octave", "chord voice octave", -2, 2, 0)
  params:set_action("chord_voice_octave", function(x) octave = x end)
end

-- the note of an arpeggio at a step of the chord
local function arp_note(notes, step, s)
  local n = #notes
  if s == RANDOM then return notes[math.random(n)] end
  if s == DOWN then return notes[n - step % n] end
  if s == UP_DOWN and n > 2 then
    local p = step % (2*n - 2)
    return notes[p < n and p + 1 or 2*n - 1 - p]
  end
  return notes[step % n + 1]
end

local function play(note, length)
  if output == PASSERSBY then
    engine.noteOn(ENGINE_ID, MusicUtil.note_num_to_freq(note), VELOCITY)
  elseif output == NB then
    local player = params:lookup_param("chord_voice_nb"):get_player()
    player:play_note(note, VELOCITY, length)
  end
end

--- call on each tick of the clock, with the beats of the progression
function chord_voice.tick(beats)
  if output == OFF then return end
  local step = math.floor(beats / rate + 1e-9)
  if step == last_step then return end
  last_step = step
  local notes = chord_voice.notes()
  if notes == nil or #notes == 0 then return end
  -- an arpeggio starts over on a new chord
  local key = table.concat(notes, ",")
  if key ~= chord_key then
    chord_key = key
    chord_start = step
  end
  local shift = octave * chord_voice.period()
  local length = rate * GATE
  if style == BLOCK and output == NB then
    for _, note in ipairs(notes) do play(note + shift, length) end
  else
    play(arp_note(notes, step - chord_start, style == BLOCK and UP or style) + shift, length)
  end
end

--- the sequence starts over
function chord_voice.reset()
  last_step = nil
  chord_key = nil
end

return chord_voice
