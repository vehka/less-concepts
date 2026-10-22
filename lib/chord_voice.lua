-- chord voice
--
-- plays chords on passersby, an nb voice or midi, as a block chord, an
-- arpeggio, or held. two ways, each can be used without the other:
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
-- voicing: the chord is played in parts, the lowest first. there can be
-- fewer parts than tones (the 5th goes first, then the root) or more (the
-- root, then the 5th, doubled). close, drop-2 or open spreads them, voice
-- leading picks the inversion that moves the parts the least from the last
-- chord, and bass puts the root below the others.
--
-- midi: each part has its own channel, for a synth with mono tracks like
-- the analog four. a part plays one note at a time, and a microtuned part
-- bends its own channel.
--
-- passersby has one voice, shared with the sequencer voices: a block or
-- held chord plays there as an arpeggio up.

local chord_voice = {}

local OFF, PASSERSBY = 1, 2
local NB, MIDI = nil, nil -- set with the params: nb is there only with nb
local BLOCK, UP, DOWN, UP_DOWN, RANDOM, HOLD = 1, 2, 3, 4, 5, 6
local styles = { "block", "up", "down", "up-down", "random", "hold" }
local CLOSE, DROP_2, OPEN = 1, 2, 3
local voicings = { "close", "drop-2", "open" }
local rates = { { "1 bar", 4 }, { "1/2", 2 }, { "1/4", 1 }, { "1/8", 1/2 }, { "1/16", 1/4 } }
local DEFAULT_RATE = 4 -- 1/8
local GATE = 0.9 -- of a step, for the length of the nb and midi notes
local VELOCITY = 0.8
local MIDI_VELOCITY = 100
local ENGINE_ID = 3 -- after the two sequencer voices
local MAX_PARTS = 4
-- voice leading: what moving the chord's centre a step away from where the
-- chord voice plays costs, against a step of a part. keeps it from drifting
local DRIFT_COST = 0.25

local output = OFF
local follow = true
local style = UP
local rate = rates[DEFAULT_RATE][2]
local octave = 0
local tuning = 1
local parts = 0 -- 0: as many as the chord has tones
local voicing = CLOSE
local leading = false
local bass = false
local part_ch = { 1, 2, 3, 4 }
local oneshot_degree = 1
local oneshot_clock = nil
local last_step = nil
local chord_key = nil -- the voiced chord that is playing
local chord_start = 0 -- the step it started on
local voiced = nil -- the chord as voiced
local voiced_key = nil -- what it was voiced from
local settings = 0 -- counts changes to the voicing params
local last_upper = nil -- the parts above the bass of the last chord voiced
-- the notes that sound: midi notes and held nb notes, with the part they
-- play and when they end, in clock beats
local sounding = {}

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

-- redefine in user script: the midi port to send to, or nil when it can't
function chord_voice.midi_out() return nil end

-- redefine in user script: the midi note to send for a note, and the
-- pitchbend that tunes it, or nil
function chord_voice.midi_note(note) return note, nil end

-- the chord voice plays the progression
function chord_voice.is_on()
  return output ~= OFF and follow
end

-- redefine in user script: what else sends to a midi channel than the
-- source named own, as a short string, or nil
function chord_voice.clash(ch, own) return nil end

-- the parts that play: as many as set, or as the chord has tones
local function parts_in_use()
  if parts > 0 then return parts end
  local raw = chord_voice.notes()
  return raw and #raw > 0 and math.min(#raw, MAX_PARTS) or MAX_PARTS
end

-- the midi channels the parts send to, with the names of their parts
function chord_voice.midi_channels()
  if output ~= MIDI then return {} end
  local chs, names = {}, {}
  for p = 1, parts_in_use() do
    chs[p] = part_ch[p]
    names[p] = "p"..p
  end
  return chs, names
end

local function end_entry(e)
  if e.port then e.port:note_off(e.note, 0, e.ch) end
  if e.player then e.player:note_off(e.note) end
end

local function end_all()
  for _, e in ipairs(sounding) do end_entry(e) end
  sounding = {}
end

local function end_part(part)
  for k = #sounding, 1, -1 do
    if sounding[k].part == part then
      end_entry(sounding[k])
      table.remove(sounding, k)
    end
  end
end

local function end_due(now)
  for k = #sounding, 1, -1 do
    if now >= sounding[k].off then
      end_entry(sounding[k])
      table.remove(sounding, k)
    end
  end
end

local function part_pitch(part)
  for _, e in ipairs(sounding) do
    if e.part == part then return e.pitch end
  end
end

local function show_params(opts)
  local ids = { "chord_voice_follow", "chord_voice_style", "chord_voice_rate",
    "chord_voice_octave", "chord_voice_voicing_sep", "chord_voice_parts",
    "chord_voice_voicing", "chord_voice_leading", "chord_voice_bass",
    "chord_voice_oneshot_sep", "chord_voice_oneshot_degree", "chord_voice_oneshot" }
  if opts.tuning then table.insert(ids, "chord_voice_tuning") end
  for _, id in ipairs(ids) do
    if output == OFF then params:hide(id) else params:show(id) end
  end
  if opts.nb then
    if output == NB then params:show("chord_voice_nb") else params:hide("chord_voice_nb") end
  end
  -- the channels of the parts that can play: all four with as many parts
  -- as the chord has tones, as that changes with sevenths
  local shown = parts > 0 and parts or MAX_PARTS
  for p = 1, MAX_PARTS do
    if output == MIDI and p <= shown then
      params:show("chord_voice_ch_"..p)
    else
      params:hide("chord_voice_ch_"..p)
    end
  end
  _menu.rebuild_params()
end

-- play a note of a part. without a length it is held until the part plays
-- again or the chord voice lets go
local function play(note, length, part)
  chord_voice.in_tuning(tuning, function()
    if output == PASSERSBY then
      engine.noteOn(ENGINE_ID, MusicUtil.note_num_to_freq(note), VELOCITY)
    elseif output == NB then
      local player = params:lookup_param("chord_voice_nb"):get_player()
      if length then
        player:play_note(note, VELOCITY, length)
      else
        end_part(part)
        player:note_on(note, VELOCITY)
        table.insert(sounding, { part = part, pitch = note, note = note,
          player = player, off = math.huge })
      end
    elseif output == MIDI then
      local port = chord_voice.midi_out()
      if port == nil then return end
      local ch = part_ch[part]
      local midi_note, bend = chord_voice.midi_note(note)
      end_part(part)
      if bend then port:pitchbend(bend, ch) end
      port:note_on(midi_note, MIDI_VELOCITY, ch)
      table.insert(sounding, { part = part, pitch = note, note = midi_note,
        port = port, ch = ch,
        off = length and clock.get_beats() + length or math.huge })
    end
  end)
end

-- the tones the parts above the bass play, as indexes into the chord, by
-- how much they matter: in a seventh chord the 3rd and 7th, then the root
-- and the 5th. with the root in the bass it goes last. more parts than
-- tones double the root, then the 5th
local function pick_tones(m, n)
  local order
  if m == 4 then order = { 2, 4, 1, 3 }
  elseif m == 3 then order = { 1, 2, 3 }
  else
    order = {}
    for k = 1, m do order[k] = k end
  end
  if bass then
    for k = #order, 1, -1 do
      if order[k] == 1 then table.remove(order, k) end
    end
    table.insert(order, 1)
  end
  local picked = {}
  for k = 1, math.min(n, m) do picked[k] = order[k] end
  local doubling = { 1, 3, 2, 4 }
  local d = 0
  while #picked < n do
    local t = doubling[d % #doubling + 1]
    if t <= m then table.insert(picked, t) end
    d = d + 1
  end
  return picked
end

-- close, drop-2 or open, from a close voicing
local function shape(close, P)
  local s = { table.unpack(close) }
  local k = #s
  if voicing == DROP_2 and k >= 3 then
    s[k - 1] = s[k - 1] - P
  elseif voicing == OPEN and k >= 2 then
    s[2] = s[2] + P
  end
  table.sort(s)
  return s
end

local function mean(v)
  local sum = 0
  for _, x in ipairs(v) do sum = sum + x end
  return sum / #v
end

-- voice a chord (its notes from the root up) in the parts, lowest first.
-- with voice leading this is the voicing that moves least from the last one
local function voice_chord(stack)
  local m = #stack
  local n = parts == 0 and m or parts
  if voicing == CLOSE and not leading and not bass and n == m then
    last_upper = nil
    return stack
  end
  local P = chord_voice.period()
  local root = stack[1]
  local upper_n = bass and n - 1 or n

  -- the tones in close position above the root, a doubled one an octave up
  local close = {}
  for k, t in ipairs(pick_tones(m, upper_n)) do close[k] = (stack[t] - root) % P end
  table.sort(close)
  for k = 2, #close do
    while close[k] <= close[k - 1] do close[k] = close[k] + P end
  end

  local home = mean(shape(close, P)) + root
  local best, best_cost = nil, math.huge
  local lead = leading and last_upper and #last_upper == upper_n
  for inversion = 0, upper_n - 1 do
    local inv = { table.unpack(close) }
    for k = 1, inversion do inv[k] = inv[k] + P end
    table.sort(inv)
    local shaped = shape(inv, P)
    for oct = -2, 2 do
      local cand = {}
      for k, x in ipairs(shaped) do cand[k] = x + root + oct * P end
      do
        local cost = math.abs(mean(cand) - home) * (lead and DRIFT_COST * upper_n or 1)
        if lead then
          for k = 1, upper_n do cost = cost + math.abs(cand[k] - last_upper[k]) end
        elseif not leading and (inversion ~= 0 or oct ~= 0) then
          cost = math.huge -- root position where the chord voice plays
        end
        if cost < best_cost then best, best_cost = cand, cost end
      end
    end
  end
  last_upper = best
  local notes = { table.unpack(best) }
  -- the bass is the root below the other parts
  if bass then
    local bass_note = root + P * math.floor((best[1] - root) / P)
    if bass_note >= best[1] then bass_note = bass_note - P end
    table.insert(notes, 1, bass_note)
  end
  return notes
end

-- the current chord as voiced, voiced again only when it or the voicing
-- params change, so voice leading leads from one chord to the next
local function current_voicing()
  local raw = chord_voice.notes()
  if raw == nil or #raw == 0 then return nil end
  local key = table.concat(raw, ",").."/"..settings
  if key ~= voiced_key then
    voiced_key = key
    voiced = voice_chord(raw)
  end
  return voiced, key
end

-- the part of an arpeggio at a step of the chord
local function arp_part(n, step, s)
  if s == RANDOM then return math.random(n) end
  if s == DOWN then return n - step % n end
  if s == UP_DOWN and n > 2 then
    local p = step % (2*n - 2)
    return p < n and p + 1 or 2*n - 1 - p
  end
  return step % n + 1
end

-- the steps of one pass of an arpeggio
local function arp_length(n, s)
  if s == UP_DOWN and n > 2 then return 2*n - 2 end
  return n
end

-- passersby has one voice: it plays block and held chords as an arpeggio
local function plays_chords()
  return output ~= PASSERSBY
end

-- hold a chord: a part that plays on with the same note is tied over
local function hold(notes, shift)
  for part, note in ipairs(notes) do
    if part_pitch(part) ~= note + shift then play(note + shift, nil, part) end
  end
  for part = #notes + 1, MAX_PARTS do end_part(part) end
end

local function changed()
  settings = settings + 1
end

--- play the chord on the one-shot degree once. a new one-shot cuts off the
--- arpeggio of the last one. held, it plays until the next one
function chord_voice.oneshot()
  if output == OFF then return end
  local raw = chord_voice.chord_notes(oneshot_degree)
  if raw == nil or #raw == 0 then return end
  local notes = voice_chord(raw)
  local shift = octave * chord_voice.period()
  local length = rate * GATE
  if oneshot_clock then clock.cancel(oneshot_clock) end
  oneshot_clock = nil
  if style == HOLD and plays_chords() then
    hold(notes, shift)
    return
  end
  if style == BLOCK and plays_chords() then
    for part, note in ipairs(notes) do play(note + shift, length, part) end
    return
  end
  local s = (style == BLOCK or style == HOLD) and UP or style
  oneshot_clock = clock.run(function()
    for step = 0, arp_length(#notes, s) - 1 do
      local part = arp_part(#notes, step, s)
      play(notes[part] + shift, length, part)
      clock.sleep(rate * clock.get_beat_sec())
    end
    oneshot_clock = nil
  end)
end

--- opts: nb (the nb library, if any), tuning (true if there is a tuning mod),
--- max_degree, degree_name (the name of a degree, for the one-shot)
function chord_voice.add_params(opts)
  local count = 13 + MAX_PARTS + (opts.nb and 2 or 0) + (opts.tuning and 1 or 0)
  params:add_group("chord voice", count)
  local outputs = { "off", "passersby" }
  if opts.nb then
    table.insert(outputs, "nb")
    NB = #outputs
  end
  table.insert(outputs, "midi")
  MIDI = #outputs
  params:add_option("chord_voice", "chord voice", outputs, OFF)
  params:set_action("chord_voice", function(x)
    end_all()
    output = x
    last_upper = nil
    show_params(opts)
  end)
  if opts.nb then opts.nb:add_param("chord_voice_nb", "chord voice -> nb") end
  for p = 1, MAX_PARTS do
    params:add_number("chord_voice_ch_"..p, "part "..p.." midi ch", 1, 16, p,
      function(param)
        local ch = param:get()
        local other = output == MIDI and p <= parts_in_use() and chord_voice.clash(ch, "p"..p)
        return other and ch.." ! "..other or tostring(ch)
      end)
    params:set_action("chord_voice_ch_"..p, function(x)
      end_part(p)
      part_ch[p] = x
    end)
  end
  params:add_option("chord_voice_follow", "follow progression", { "no", "yes" }, 2)
  params:set_action("chord_voice_follow", function(x)
    follow = (x == 2)
    if not follow then end_all() end
  end)
  params:add_option("chord_voice_style", "style", styles, UP)
  params:set_action("chord_voice_style", function(x)
    if style == HOLD then end_all() end
    style = x
    chord_key = nil
  end)
  local rate_names = {}
  for i, r in ipairs(rates) do rate_names[i] = r[1] end
  params:add_option("chord_voice_rate", "rate", rate_names, DEFAULT_RATE)
  params:set_action("chord_voice_rate", function(x) rate = rates[x][2] end)
  params:add_number("chord_voice_octave", "octave", -2, 2, 0)
  params:set_action("chord_voice_octave", function(x)
    octave = x
    changed()
  end)
  if opts.tuning then
    params:add_option("chord_voice_tuning", "tuning", { "z_tuning", "12-TET" }, 1)
    params:set_action("chord_voice_tuning", function(x) tuning = x end)
  end
  params:add_separator("chord_voice_voicing_sep", "voicing")
  params:add_option("chord_voice_parts", "parts", { "chord tones", "2", "3", "4" }, 1)
  params:set_action("chord_voice_parts", function(x)
    parts = x == 1 and 0 or x
    for p = parts + 1, MAX_PARTS do
      if parts > 0 then end_part(p) end
    end
    changed()
    show_params(opts)
  end)
  params:add_option("chord_voice_voicing", "voicing", voicings, CLOSE)
  params:set_action("chord_voice_voicing", function(x)
    voicing = x
    changed()
  end)
  params:add_option("chord_voice_leading", "voice leading", { "off", "on" }, 1)
  params:set_action("chord_voice_leading", function(x)
    leading = (x == 2)
    changed()
  end)
  params:add_option("chord_voice_bass", "bass", { "in chord", "root below" }, 1)
  params:set_action("chord_voice_bass", function(x)
    bass = (x == 2)
    last_upper = nil
    changed()
  end)
  params:add_separator("chord_voice_oneshot_sep", "one-shot")
  params:add_number("chord_voice_oneshot_degree", "chord", 1, opts.max_degree, 1,
    function(p) return opts.degree_name(p:get()) end)
  params:set_action("chord_voice_oneshot_degree", function(x) oneshot_degree = x end)
  params:add_trigger("chord_voice_oneshot", "play one-shot")
  params:set_action("chord_voice_oneshot", function() chord_voice.oneshot() end)
end

--- call on each tick of the clock, with the beats of the progression
function chord_voice.tick(beats)
  end_due(clock.get_beats())
  if not chord_voice.is_on() then return end
  local shift = octave * chord_voice.period()
  -- a held chord changes with the chord, not on the steps of the rate
  if style == HOLD and plays_chords() then
    local notes, key = current_voicing()
    if notes == nil then
      end_all()
      chord_key = nil
    elseif key ~= chord_key then
      chord_key = key
      hold(notes, shift)
    end
    return
  end
  local step = math.floor(beats / rate + 1e-9)
  if step == last_step then return end
  last_step = step
  local notes, key = current_voicing()
  if notes == nil then return end
  -- an arpeggio starts over on a new chord
  if key ~= chord_key then
    chord_key = key
    chord_start = step
  end
  local length = rate * GATE
  if style == BLOCK and plays_chords() then
    for part, note in ipairs(notes) do play(note + shift, length, part) end
  else
    local s = (style == BLOCK or style == HOLD) and UP or style
    local part = arp_part(#notes, step - chord_start, s)
    play(notes[part] + shift, length, part)
  end
end

--- the sequence starts over: so does the voice leading
function chord_voice.reset()
  last_step = nil
  chord_key = nil
  voiced_key = nil
  last_upper = nil
end

--- stop a one-shot arpeggio and the notes that sound, at cleanup
function chord_voice.cleanup()
  if oneshot_clock then clock.cancel(oneshot_clock) end
  oneshot_clock = nil
  end_all()
end

return chord_voice
