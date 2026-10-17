-- morph
--
-- moves from where the sequencer is to a snapshot over a length of time,
-- instead of jumping there. the bits, low/high and octaves are whole
-- numbers, and step one at a time, spread evenly over the morph. the rule
-- changes a bit at a time, in a random order, so the automaton drifts from
-- one rule to the other. the rest of the snapshot comes at the end: the
-- seed starts over from the snapshot's, and the time division and cycle
-- length change, as when a snapshot is recalled.
--
-- a morph is counted in the ticks of the sequencer, so it stands still
-- while it is stopped.

local morph = {}

local PPQN = 96

-- morph lengths, in beats, or to where the chord progression is going: the
-- end of the chord that plays, or of the progression
local lengths = {
  { "1/4 bar", 1 }, { "1/2 bar", 2 }, { "1 bar", 4 }, { "2 bars", 8 },
  { "4 bars", 16 }, { "8 bars", 32 }, { "16 bars", 64 }, { "32 bars", 128 },
  { "to chord end", "chord" }, { "to prog end", "prog" },
}
local DEFAULT_LENGTHS = { 3, 5 } -- 1 bar, 4 bars

-- the whole number fields of a snapshot that step
local STEPPED = { "v1_bit", "v2_bit", "new_low", "new_high", "v1_octave", "v2_octave" }

local active = false
local slot = nil -- the snapshot it moves to
local target = nil -- a copy of the snapshot, as it was when the morph started
local events = {} -- the changes along the way, in order: { at = fraction, field, value }
local next_event = 1
local ticks, total_ticks = 0, 1

-- redefine in user script: set a field of the snapshot on the sequencer
function morph.apply(field, value) end
-- redefine in user script: the morph has arrived, recall the snapshot
function morph.finish(slot, snapshot) end
-- redefine in user script: the beats to the end of the chord ("chord") or
-- of the chord progression ("prog")
function morph.beats_to(where) return 4 end
-- redefine in user script: a length in beats, moved to end with a chord
-- when one ends near it
function morph.snap(beats) return beats end

-- the steps of a field, from one value to another, evenly spaced: one step
-- lands in the middle, the last just before the end
local function add_steps(field, from, to)
  local n = math.abs(to - from)
  local dir = to > from and 1 or -1
  for k = 1, n do
    table.insert(events, { at = (k - 0.5) / n, field = field, value = from + dir * k })
  end
end

-- the bits that differ between two rules, flipped one at a time in a random
-- order, the same spacing as add_steps
local function add_rule_flips(from, to)
  local bits = {}
  for b = 0, 7 do
    if (from >> b) & 1 ~= (to >> b) & 1 then table.insert(bits, b) end
  end
  for k = #bits, 2, -1 do
    local j = math.random(k)
    bits[k], bits[j] = bits[j], bits[k]
  end
  local rule = from
  for k, b in ipairs(bits) do
    rule = rule ~ (1 << b)
    table.insert(events, { at = (k - 0.5) / #bits, field = "rule", value = rule })
  end
end

--- the length of a morph in beats: of morph 1 or 2 from its param, or "prog"
--- to the end of the chord progression. it is counted when the morph starts,
--- so a progression changed while it runs no longer lines up with it. with
--- snap on, a length in bars ends with a chord when one ends near it
function morph.length(i)
  local length = i == "prog" and "prog" or lengths[params:get("morph_length_" .. i)][2]
  if type(length) ~= "number" then return morph.beats_to(length) end
  if params:string("morph_snap") == "on" then return morph.snap(length) end
  return length
end

--- start a morph to a snapshot, from the values in from. a field missing
--- from either is left as it is. i is the morph, 1 or 2, or "prog", for its
--- length
function morph.start(to_slot, from, to, i)
  events = {}
  for _, field in ipairs(STEPPED) do
    if from[field] and to[field] then add_steps(field, from[field], to[field]) end
  end
  if from.rule and to.rule then add_rule_flips(from.rule, to.rule) end
  table.sort(events, function(a, b) return a.at < b.at end)
  next_event = 1
  ticks = 0
  total_ticks = math.max(1, math.floor(morph.length(i) * PPQN + 0.5))
  slot = to_slot
  target = to
  active = true
end

function morph.cancel()
  active = false
end

function morph.active() return active end
function morph.slot() return active and slot or nil end
function morph.progress() return active and ticks / total_ticks or 0 end

--- call on each tick of the sequencer while it plays. true when something
--- changed
function morph.tick()
  if not active then return false end
  ticks = ticks + 1
  local progress = ticks / total_ticks
  local changed = false
  while events[next_event] and events[next_event].at <= progress do
    local e = events[next_event]
    morph.apply(e.field, e.value)
    next_event = next_event + 1
    changed = true
  end
  if ticks >= total_ticks then
    active = false
    morph.finish(slot, target)
    changed = true
  end
  return changed
end

function morph.add_params()
  local names = {}
  for k, l in ipairs(lengths) do names[k] = l[1] end
  params:add_group("morph", 3)
  for i = 1, 2 do
    params:add_option("morph_length_" .. i, "morph " .. i .. " length", names, DEFAULT_LENGTHS[i])
  end
  params:add_option("morph_snap", "snap to chords", { "off", "on" }, 1)
end

return morph
