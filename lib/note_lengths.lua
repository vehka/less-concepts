-- note lengths
--
-- each sequencer voice picks the length of its notes from eight lengths,
-- counted in steps: 1/4, 1/2, 1, 1 1/2, 2, 3, 4 and 8. a length has a
-- weight from 0 to 7, and is picked that much more often.
--
-- the pick comes from the seed or at random. from the seed, the same seed
-- gives the same length, so the lengths follow the pattern. rotate reads
-- the seed's bits from another place, so the two voices can pick
-- differently from the same seed.
--
-- a note that still plays when the voice plays again is cut, or with
-- legato it ends just after the new note starts. the lengths only reach
-- the outputs with a note off: midi and nb.

local note_lengths = {}

local LENGTHS = { 1/4, 1/2, 1, 1.5, 2, 3, 4, 8 }
local NAMES = { "1/4", "1/2", "1", "1 1/2", "2", "3", "4", "8" }
local ONE_STEP = 3
local MAX_WEIGHT = 7
local DEFAULT_WEIGHT = 4
local SEED, RANDOM = 1, 2
local CUT, LEGATO = 1, 2

local voices = {}
for i = 1, 2 do
  voices[i] = { weights = {}, source = SEED, rotate = 0, overlap = CUT }
  for j = 1, #LENGTHS do
    voices[i].weights[j] = j == ONE_STEP and DEFAULT_WEIGHT or 0
  end
end

-- the seven bits after the gate bit, round the ring of eight, as a fraction.
-- the gate bit is left out: it is always 1 when the voice plays
local function seed_fraction(seed, gate_bit, rotate)
  local value = 0
  for k = 1, 7 do
    local pos = (gate_bit - 1 + (k - 1 + rotate) % 7 + 1) % 8 + 1
    value = value * 2 + ((seed >> (pos - 1)) & 1)
  end
  return (value + 0.5) / 128
end

--- the length of a new note of voice i, in steps
function note_lengths.pick(i, seed, gate_bit)
  local v = voices[i]
  local total = 0
  for _, w in ipairs(v.weights) do total = total + w end
  if total == 0 then return LENGTHS[ONE_STEP] end
  local u = v.source == SEED and seed_fraction(seed, gate_bit, v.rotate) or math.random()
  local target = u * total
  local sum = 0
  for j, w in ipairs(v.weights) do
    sum = sum + w
    if target < sum then return LENGTHS[j] end
  end
  return LENGTHS[#LENGTHS]
end

function note_lengths.legato(i)
  return voices[i].overlap == LEGATO
end

function note_lengths.add_params()
  params:add_group("note lengths", 2 * (4 + #LENGTHS))
  for i = 1, 2 do
    local v = voices[i]
    local p = "voice_" .. i .. "_len"
    params:add_separator(p .. "_sep", "voice " .. i)
    params:add_option(p .. "_source", "from", { "seed", "random" }, SEED)
    params:set_action(p .. "_source", function(x) v.source = x end)
    params:add_number(p .. "_rotate", "rotate", 0, 6, 0)
    params:set_action(p .. "_rotate", function(x) v.rotate = x end)
    params:add_option(p .. "_overlap", "overlap", { "cut", "legato" }, CUT)
    params:set_action(p .. "_overlap", function(x) v.overlap = x end)
    for j, name in ipairs(NAMES) do
      params:add_number(p .. "_" .. j, name .. (j <= ONE_STEP and " step" or " steps"),
        0, MAX_WEIGHT, v.weights[j])
      params:set_action(p .. "_" .. j, function(x) v.weights[j] = x end)
    end
  end
end

return note_lengths
