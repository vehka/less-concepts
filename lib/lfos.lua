-- lfos
--
-- three LFOs for less concepts: one for the bits, one for low/high and one
-- for the octaves. An LFO moves its values around the ones that are set,
-- by a whole number of steps. It is read when a step plays.
--
-- four more LFOs can each move any parameter, or send a MIDI CC. A parameter
-- keeps its value: the LFO calls its action with values around it.
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

-- the param LFOs move all the time, so they also have shorter cycles
local param_rates = { { "1/16", 1/4 }, { "1/8", 1/2 } }
for _, rate in ipairs(rates) do table.insert(param_rates, rate) end
local DEFAULT_PARAM_RATE = 6 -- 1 bar

local NUMBER_OF_PARAM_LFOS = 4
local PARAM_TICKS = 4 -- ticks between the updates of the param LFOs
local param_lfo = {}
for i = 1, NUMBER_OF_PARAM_LFOS do
  param_lfo[i] = {
    on = false,
    target_id = "", -- "", "cc" or the id of a parameter
    target_index = 1,
    kind = nil, -- "param" or "cc" when there is something to move
    param = nil,
    cc = 1, channel = 1, center = 64,
    shape = 1,
    beats = param_rates[DEFAULT_PARAM_RATE][2],
    depth = 0.5,
    rand = 0, rand_cycle = -1,
    sent = nil, -- the last value that went out
  }
end

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

-- redefine in user script: sends the MIDI CC of a param LFO
function lfos.send_cc(cc, value, channel)
end

local update_param_lfos

--- one tick (1/96 beat) of the running sequencer
function lfos.tick()
  ticks = ticks + 1
  if ticks % PARAM_TICKS == 0 then update_param_lfos() end
end

--- the beats played since the sequencer was started
function lfos.beats()
  return ticks / PPQN
end

function lfos.reset()
  ticks = 0
  for _, l in pairs(lfo) do l.rand_cycle = -1 end
  for _, l in ipairs(param_lfo) do l.rand_cycle = -1 end
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

-- depth 1 reaches half of the range of the target to each side
update_param_lfos = function()
  for _, l in ipairs(param_lfo) do
    if l.on and l.kind then
      local move = l.depth * value(l) / 2
      local p = l.param
      local new
      if l.kind == "cc" then
        new = util.clamp(util.round(l.center + move * 128), 0, 127)
      elseif p.t == params.tNUMBER then
        new = util.clamp(util.round(p:get() + move * (p.max - p.min)), p.min, p.max)
      else
        new = p:map_value(util.clamp(p:get_raw() + move, 0, 1))
      end
      if new ~= l.sent then
        l.sent = new
        if l.kind == "cc" then
          lfos.send_cc(l.cc, new, l.channel)
        else
          p.action(new)
        end
      end
    end
  end
end

-- a parameter that its LFO lets go of goes back to its own value
local function release(l)
  if l.kind == "param" and l.sent ~= nil then l.param:bang() end
  l.sent = nil
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

-- the parameters a param LFO can move: the ones with a range of numbers
local function param_targets()
  local ids, names, count = { "", "cc" }, { "none", "midi cc" }, {}
  local found = {}
  for _, p in ipairs(params.params) do
    if (p.t == params.tNUMBER or p.t == params.tCONTROL or p.t == params.tTAPER)
        and p.id and p.id:sub(1, 4) ~= "lfo_" then
      table.insert(found, p)
      count[p.name] = (count[p.name] or 0) + 1
    end
  end
  for _, p in ipairs(found) do
    table.insert(ids, p.id)
    -- a name that several parameters have does not tell them apart
    table.insert(names, count[p.name] == 1 and p.name or p.id)
  end
  return ids, names
end

local function percent(param)
  return param:get() .. "%"
end

--- add the param LFOs. Call this after all other parameters are added,
-- since those are what the LFOs can pick from
function lfos.add_param_lfos()
  local ids, names = param_targets()
  local rate_names = {}
  for k, rate in ipairs(param_rates) do rate_names[k] = rate[1] end

  params:add_group("param lfos", NUMBER_OF_PARAM_LFOS * 10)
  for i, l in ipairs(param_lfo) do
    local p = "lfo_p" .. i

    local function set_target(id)
      release(l)
      l.target_id = id
      l.param = params.lookup[id] and params.params[params.lookup[id]] or nil
      l.kind = id == "cc" and "cc" or l.param and "param" or nil
      for _, name in ipairs({ "_cc", "_channel", "_center" }) do
        if l.kind == "cc" then params:show(p .. name) else params:hide(p .. name) end
      end
      _menu.rebuild_params()
    end

    params:add_separator(p .. "_separator", "lfo " .. i)
    params:add_option(p, "lfo", { "off", "on" }, 1)
    params:set_action(p, function(value)
      l.on = value == 2
      if not l.on then release(l) end
    end)
    -- the target is saved as the id of its parameter, so that it stays the
    -- same when the list of parameters changes
    params:add_text(p .. "_target_id", "target id", "")
    params:hide(p .. "_target_id")
    params:add_option(p .. "_target", "target", names, 1)
    params:set_save(p .. "_target", false)
    params:add_number(p .. "_cc", "cc", 0, 127, 1)
    params:set_action(p .. "_cc", function(value) l.cc = value l.sent = nil end)
    params:add_number(p .. "_channel", "channel", 1, 16, 1)
    params:set_action(p .. "_channel", function(value) l.channel = value l.sent = nil end)
    params:add_number(p .. "_center", "center", 0, 127, 64)
    params:set_action(p .. "_center", function(value) l.center = value end)
    params:add_option(p .. "_shape", "shape", shapes, 1)
    params:set_action(p .. "_shape", function(value) l.shape = value end)
    params:add_option(p .. "_rate", "cycle", rate_names, DEFAULT_PARAM_RATE)
    params:set_action(p .. "_rate", function(value) l.beats = param_rates[value][2] end)
    params:add_number(p .. "_depth", "depth", 0, 100, 50, percent)
    params:set_action(p .. "_depth", function(value) l.depth = value / 100 end)

    params:set_action(p .. "_target_id", function(id)
      l.target_index = tab.key(ids, id) or 1
      params:set(p .. "_target", l.target_index, true)
      set_target(id)
    end)
    params:set_action(p .. "_target", function(index)
      if index == l.target_index then return end
      l.target_index = index
      params:set(p .. "_target_id", ids[index], true)
      set_target(ids[index])
    end)
  end
end

return lfos
