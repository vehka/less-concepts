-- lfos
--
-- three LFOs for less concepts: one for the bits, one for low/high and one
-- for the octaves. An LFO moves its values around the ones that are set,
-- by a whole number of steps. It is read when a step plays.
--
-- a cycle is a length in beats, counted in the ticks of the sequencer since
-- it was started, so the LFOs stand still while it is stopped and start
-- over with it.

local lfos = {}

local PPQN = 96

local shapes = { "sine", "triangle", "ramp up", "ramp down", "square", "random" }

-- cycle lengths, in beats
local rates = {
  { "1/4", 1 }, { "1/2", 2 }, { "1/2.", 3 }, { "1 bar", 4 }, { "2 bars", 8 },
  { "3 bars", 12 }, { "4 bars", 16 }, { "6 bars", 24 }, { "8 bars", 32 },
  { "12 bars", 48 }, { "16 bars", 64 }, { "32 bars", 128 },
}
local DEFAULT_RATE = 5 -- 2 bars

-- a target is one of the two values of the LFO, both, or both in opposite
-- directions
local BOTH, CONTRARY = 3, 4
local voices = { "voice 1", "voice 2", "both", "contrary" }

lfos.ids = { "bits", "range", "octs" }
local defs = {
  bits = { name = "bits", targets = voices, max_depth = 8, depth = 2 },
  range = { name = "low/high", targets = { "low", "high", "both", "contrary" },
    max_depth = 16, depth = 4 },
  octs = { name = "octaves", targets = voices, max_depth = 3, depth = 1 },
}

local lfo = {}
for _, id in ipairs(lfos.ids) do
  lfo[id] = {
    on = false,
    shape = 1,
    beats = rates[DEFAULT_RATE][2],
    depth = defs[id].depth,
    target = BOTH,
    rand = 0, rand_cycle = -1,
  }
end

local ticks = 0

-- redefine in user script: called when an LFO is switched on or off
function lfos.changed()
end

--- one tick (1/96 beat) of the running sequencer
function lfos.tick()
  ticks = ticks + 1
end

function lfos.reset()
  ticks = 0
  for _, l in pairs(lfo) do l.rand_cycle = -1 end
end

-- p is the place in the cycle (0-1), the result is -1 to 1
local wave = {
  function(p) return math.sin(2 * math.pi * p) end, -- sine
  function(p) -- triangle
    if p < 0.25 then return 4 * p end
    if p < 0.75 then return 2 - 4 * p end
    return 4 * p - 4
  end,
  function(p) return 2 * p - 1 end, -- ramp up
  function(p) return 1 - 2 * p end, -- ramp down
  function(p) return p < 0.5 and 1 or -1 end, -- square
  function(p, l, cycle) -- random: a new value every cycle
    if cycle ~= l.rand_cycle then
      l.rand_cycle = cycle
      l.rand = math.random() * 2 - 1
    end
    return l.rand
  end,
}

local function value(l)
  local c = ticks / (PPQN * l.beats)
  local cycle = math.floor(c)
  return wave[l.shape](c - cycle, l, cycle)
end

--- how many steps LFO id moves its value k (1 or 2) right now
function lfos.offset(id, k)
  local l = lfo[id]
  if not l.on then return 0 end
  if l.target < BOTH and l.target ~= k then return 0 end
  local offset = util.round(l.depth * value(l))
  if l.target == CONTRARY and k == 2 then return -offset end
  return offset
end

function lfos.is_on(id)
  return lfo[id].on
end

function lfos.toggle(id)
  params:set("lfo_" .. id, lfo[id].on and 1 or 2)
end

--- new shapes, cycles, depths and targets; an LFO stays on or off
function lfos.randomize()
  for _, id in ipairs(lfos.ids) do
    params:set("lfo_" .. id .. "_shape", math.random(#shapes))
    params:set("lfo_" .. id .. "_rate", math.random(#rates))
    params:set("lfo_" .. id .. "_depth", math.random(defs[id].max_depth))
    params:set("lfo_" .. id .. "_target", math.random(#defs[id].targets))
  end
end

function lfos.add_params()
  local names = {}
  for k, rate in ipairs(rates) do names[k] = rate[1] end

  params:add_group("lfos", #lfos.ids * 6 + 1)
  for _, id in ipairs(lfos.ids) do
    local l, def = lfo[id], defs[id]
    local p = "lfo_" .. id
    params:add_separator(p .. "_separator", def.name)
    params:add_option(p, "lfo", { "off", "on" }, 1)
    params:set_action(p, function(value)
      l.on = value == 2
      lfos.changed()
    end)
    params:add_option(p .. "_target", "target", def.targets, BOTH)
    params:set_action(p .. "_target", function(value) l.target = value end)
    params:add_option(p .. "_shape", "shape", shapes, 1)
    params:set_action(p .. "_shape", function(value) l.shape = value end)
    params:add_option(p .. "_rate", "cycle", names, DEFAULT_RATE)
    params:set_action(p .. "_rate", function(value) l.beats = rates[value][2] end)
    params:add_number(p .. "_depth", "depth", 1, def.max_depth, def.depth)
    params:set_action(p .. "_depth", function(value) l.depth = value end)
  end
  params:add_trigger("lfo_randomize", "randomize lfos")
  params:set_action("lfo_randomize", lfos.randomize)
end

return lfos
