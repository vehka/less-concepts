-- chord voice
--
-- plays chords on passersby or an nb voice, as a block chord or an arpeggio.
-- two ways, each can be used without the other:
--
-- follow progression: plays the current chord of the chord progression,
-- handy for trying out progressions. it steps with the beats of the
-- progression, so it stays in time with the chord changes and starts over
-- with the sequence. it plays on while the sequencer is stopped, for trying
-- out a progression on its own: switch it off to silence it.
--
-- one-shot: plays the chord on a chosen degree once, right away: a block
-- chord, or one pass of the arpeggio. it has the shape of the progression's
-- chords (sevenths, stride). map the trigger to a midi controller to play it.
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
local follow = true
local style = UP
local rate = rates[DEFAULT_RATE][2]
local octave = 0
local tuning = 1
local oneshot_degree = 1
local oneshot_clock = nil
local last_step = nil
local chord_key = nil -- the chord that is playing
local chord_start = 0 -- the step it started on

-- redefine in user script: the notes of the current chord, lowest first,
-- or nil when there is no chord
function chord_voice.notes() return nil end

-- redefine in user script: the notes of the chord on a degree of the scale,
-- lowest first, or nil when there is none
function chord_voice.chord_notes(degree) return nil end

-- redefine in user script: the steps in an octave
function chord_voice.period() return 12 end

-- redefine in user script: call f in the tuning that the tuning param picks
function chord_voice.in_tuning(t, f) f() end

-- the chord voice plays the progression
function chord_voice.is_on()
  return output ~= OFF and follow
end

local function show_params(opts)
  local ids = { "chord_voice_follow", "chord_voice_style", "chord_voice_rate",
    "chord_voice_octave", "chord_voice_oneshot_sep", "chord_voice_oneshot_degree",
    "chord_voice_oneshot" }
  if opts.tuning then table.insert(ids, "chord_voice_tuning") end
  for _, id in ipairs(ids) do
    if output == OFF then params:hide(id) else params:show(id) end
  end
  if opts.nb then
    if output == NB then params:show("chord_voice_nb") else params:hide("chord_voice_nb") end
  end
  _menu.rebuild_params()
end

local function play(note, length)
  chord_voice.in_tuning(tuning, function()
    if output == PASSERSBY then
      engine.noteOn(ENGINE_ID, MusicUtil.note_num_to_freq(note), VELOCITY)
    elseif output == NB then
      local player = params:lookup_param("chord_voice_nb"):get_player()
      player:play_note(note, VELOCITY, length)
    end
  end)
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

-- the steps of one pass of an arpeggio
local function arp_length(n, s)
  if s == UP_DOWN and n > 2 then return 2*n - 2 end
  return n
end

--- play the chord on the one-shot degree once. a new one-shot cuts off the
--- arpeggio of the last one
function chord_voice.oneshot()
  if output == OFF then return end
  local notes = chord_voice.chord_notes(oneshot_degree)
  if notes == nil or #notes == 0 then return end
  local shift = octave * chord_voice.period()
  local length = rate * GATE
  if oneshot_clock then clock.cancel(oneshot_clock) end
  oneshot_clock = nil
  if style == BLOCK and output == NB then
    for _, note in ipairs(notes) do play(note + shift, length) end
    return
  end
  local s = style == BLOCK and UP or style
  oneshot_clock = clock.run(function()
    for step = 0, arp_length(#notes, s) - 1 do
      play(arp_note(notes, step, s) + shift, length)
      clock.sleep(rate * clock.get_beat_sec())
    end
    oneshot_clock = nil
  end)
end

--- opts: nb (the nb library, if any), tuning (true if there is a tuning mod),
--- max_degree, degree_name (the name of a degree, for the one-shot)
function chord_voice.add_params(opts)
  local count = 8 + (opts.nb and 2 or 0) + (opts.tuning and 1 or 0)
  params:add_group("chord voice", count)
  local outputs = { "off", "passersby" }
  if opts.nb then table.insert(outputs, "nb") end
  params:add_option("chord_voice", "chord voice", outputs, OFF)
  params:set_action("chord_voice", function(x)
    output = x
    show_params(opts)
  end)
  if opts.nb then opts.nb:add_param("chord_voice_nb", "chord voice -> nb") end
  params:add_option("chord_voice_follow", "follow progression", { "no", "yes" }, 2)
  params:set_action("chord_voice_follow", function(x) follow = (x == 2) end)
  params:add_option("chord_voice_style", "style", styles, UP)
  params:set_action("chord_voice_style", function(x) style = x end)
  local rate_names = {}
  for i, r in ipairs(rates) do rate_names[i] = r[1] end
  params:add_option("chord_voice_rate", "rate", rate_names, DEFAULT_RATE)
  params:set_action("chord_voice_rate", function(x) rate = rates[x][2] end)
  params:add_number("chord_voice_octave", "octave", -2, 2, 0)
  params:set_action("chord_voice_octave", function(x) octave = x end)
  if opts.tuning then
    params:add_option("chord_voice_tuning", "tuning", { "z_tuning", "12-TET" }, 1)
    params:set_action("chord_voice_tuning", function(x) tuning = x end)
  end
  params:add_separator("chord_voice_oneshot_sep", "one-shot")
  params:add_number("chord_voice_oneshot_degree", "chord", 1, opts.max_degree, 1,
    function(p) return opts.degree_name(p:get()) end)
  params:set_action("chord_voice_oneshot_degree", function(x) oneshot_degree = x end)
  params:add_trigger("chord_voice_oneshot", "play one-shot")
  params:set_action("chord_voice_oneshot", function() chord_voice.oneshot() end)
end

--- call on each tick of the clock, with the beats of the progression
function chord_voice.tick(beats)
  if not chord_voice.is_on() then return end
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

--- stop a one-shot arpeggio, at cleanup
function chord_voice.cleanup()
  if oneshot_clock then clock.cancel(oneshot_clock) end
  oneshot_clock = nil
end

return chord_voice
