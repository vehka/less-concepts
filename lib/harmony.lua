-- harmony: each of the two voices can have a shadow, a second note that
-- plays with each of its notes, on its own midi channel or nb voice:
--
-- 3rd / 6th above or below: in the scale, two or five degrees away, so the
-- harmony stays in the key (in a seven note scale, thirds and sixths).
-- chord tone above / below: the next tone of the chord that plays, so the
-- harmony is always consonant with the progression.
-- contrary: when the voice goes up, the harmony goes down by as many
-- degrees, and the other way round. it stays a 3rd to a 10th below the voice
-- and goes back to a 6th below when it wanders out.
--
-- the harmony note has the voice's length, octave and tuning. its velocity
-- is the voice's, moved by a percentage: -100% is silent, 0% the voice's own,
-- +100% the loudest. the param lfos can move the mode and the velocity.

local harmony = {}

local OFF, THIRD_UP, THIRD_DOWN, SIXTH_UP, SIXTH_DOWN, TONE_UP, TONE_DOWN, CONTRARY =
  1, 2, 3, 4, 5, 6, 7, 8
local modes = { "off", "3rd above", "3rd below", "6th above", "6th below",
  "chord tone above", "chord tone below", "contrary" }
local DEGREES = { [THIRD_UP] = 2, [THIRD_DOWN] = -2, [SIXTH_UP] = 5, [SIXTH_DOWN] = -5 }

local mode = { OFF, OFF }
local velocity = { 0, 0 } -- -1 to 1, of the way to silent or the loudest
local shown = { nil, nil } -- the harmony params are shown for voice i
local to_midi = { false, false }
local channel = { 3, 4 }
local has_nb = false
-- contrary: the degrees of the last voice note and its harmony
local last = { {}, {} }

function harmony.active(i) return mode[i] ~= OFF end

-- a voice harmonizes with the tones of the chord
function harmony.needs_chord()
  for i = 1, 2 do
    if mode[i] == TONE_UP or mode[i] == TONE_DOWN then return true end
  end
  return false
end

-- the midi channel of the harmony of voice i, or nil
function harmony.midi_channel(i)
  return to_midi[i] and channel[i] or nil
end

--- the midi velocity of the harmony of a note of voice i, played at
--- velocity v (1 to 127), or nil when it is silent
function harmony.velocity(i, v)
  local x = velocity[i]
  local h = x < 0 and v * (1 + x) or v + x * (127 - v)
  h = util.round(h)
  if h < 1 then return nil end
  return math.min(h, 127)
end

-- a harmony is set to play: an lfo can move the mode through off for a
-- while, but the channel stays the harmony's
local function set_on(i)
  return params:get("harmony_"..i) ~= OFF
end

-- the midi channels the harmonies send to, with the names of their harmonies
function harmony.midi_channels()
  local chs, names = {}, {}
  for i = 1, 2 do
    if set_on(i) and to_midi[i] then
      table.insert(chs, channel[i])
      table.insert(names, "h"..i)
    end
  end
  return chs, names
end

-- redefine in user script: what else sends to a midi channel than the
-- source named own, as a short string, or nil
function harmony.clash(ch, own) return nil end

-- the nb player of the harmony of voice i, or nil without nb
function harmony.nb_player(i)
  if not has_nb then return nil end
  return params:lookup_param("harmony_"..i.."_nb"):get_player()
end

-- the degree of the scale a pitch is on, counted from 0 at pitch 0, and the
-- steps it is above that degree (for a note outside the scale)
local function degree_of(pitch, intervals, period)
  local len = #intervals - 1 -- the last interval is the octave
  local oct = math.floor(pitch / period)
  local pc = pitch - oct * period
  local idx = 1
  for k = 1, len do
    if intervals[k] <= pc then idx = k end
  end
  return oct * len + idx - 1, pc - intervals[idx]
end

local function pitch_of(degree, rest, intervals, period)
  local len = #intervals - 1
  local oct = math.floor(degree / len)
  return oct * period + intervals[degree - oct * len + 1] + rest
end

--- the harmony of a note of voice i, or nil when there is none.
--- ctx: intervals (of the scale, ending with the octave), period, and tones
--- (the pitch classes of the chord that plays, or nil)
function harmony.pitch(i, pitch, ctx)
  local m = mode[i]
  if m == OFF or ctx.intervals == nil then return nil end
  if (m == TONE_UP or m == TONE_DOWN) and ctx.tones then
    local dir = m == TONE_UP and 1 or -1
    for d = 1, ctx.period do
      local p = pitch + dir * d
      if ctx.tones[p % ctx.period] then return p end
    end
    return nil
  end
  local degree, rest = degree_of(pitch, ctx.intervals, ctx.period)
  if m == CONTRARY then
    local len = #ctx.intervals - 1
    local l = last[i]
    local h = l.voice and l.harmony - (degree - l.voice)
    if h == nil or degree - h < 2 or degree - h > len + 2 then h = degree - 5 end
    last[i] = { voice = degree, harmony = h }
    return pitch_of(h, rest, ctx.intervals, ctx.period)
  end
  -- without a chord, a chord tone harmony is a 3rd
  local steps = DEGREES[m] or (m == TONE_UP and 2 or -2)
  return pitch_of(degree + steps, rest, ctx.intervals, ctx.period)
end

--- the sequence starts over: contrary motion starts from a 6th below
function harmony.reset()
  last = { {}, {} }
end

-- the params follow the mode that is set, not where an lfo moves it, and
-- the menu is rebuilt only when they change
local function show_params(i)
  local on = set_on(i)
  local key = tostring(on)..tostring(to_midi[i])
  if key == shown[i] then return end
  shown[i] = key
  local ids = { "harmony_"..i.."_midi", "harmony_"..i.."_ch", "harmony_"..i.."_velocity" }
  if has_nb then table.insert(ids, "harmony_"..i.."_nb") end
  for _, id in ipairs(ids) do
    if on then params:show(id) else params:hide(id) end
  end
  if on and not to_midi[i] then params:hide("harmony_"..i.."_ch") end
  _menu.rebuild_params()
end

local function percent(p)
  local x = p:get()
  return (x > 0 and "+" or "")..x.."%"
end

--- nb: the nb library, if any.
--- a harmony that is switched off ends with the note of its voice
function harmony.add_params(nb)
  has_nb = nb ~= nil
  -- each nb voice selector is two params
  params:add_group("harmony", 2 * (5 + (nb and 2 or 0)))
  for i = 1, 2 do
    params:add_separator("harmony_"..i.."_sep", "vox "..i)
    params:add_option("harmony_"..i, "vox "..i.." harmony", modes, OFF)
    params:set_action("harmony_"..i, function(x)
      if x == CONTRARY and mode[i] ~= CONTRARY then last[i] = {} end
      mode[i] = x
      show_params(i)
    end)
    params:add_number("harmony_"..i.."_velocity", "vox "..i.." harmony vel", -100, 100, 0, percent)
    params:set_action("harmony_"..i.."_velocity", function(x) velocity[i] = x / 100 end)
    params:add_option("harmony_"..i.."_midi", "harmony -> midi", { "no", "yes" }, 1)
    params:set_action("harmony_"..i.."_midi", function(x)
      to_midi[i] = (x == 2)
      show_params(i)
    end)
    params:add_number("harmony_"..i.."_ch", "harmony midi ch", 1, 16, channel[i],
      function(p)
        local ch = p:get()
        local other = set_on(i) and to_midi[i] and harmony.clash(ch, "h"..i)
        return other and ch.." ! "..other or tostring(ch)
      end)
    params:set_action("harmony_"..i.."_ch", function(x) channel[i] = x end)
    if nb then nb:add_param("harmony_"..i.."_nb", "harmony -> nb") end
  end
end

return harmony
