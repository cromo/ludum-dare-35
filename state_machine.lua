local state_machine = {}
local sm = state_machine

--[[
States
  initial
  final
  regular
  choice
Edges
  trigger event type
  guard
  effect
Emitters
  type
Events
  type
  event data
]]

local Event = {}
sm.Event = Event
function Event.new(kind, payload)
  local event = {}
  setmetatable(event, {__index = sm.Event})
  event.kind = kind
  event.payload = payload
  return event
end

local Emitter = {}
sm.Emitter = Emitter
function Emitter.new(kind)
  local emitter = {}
  setmetatable(emitter, {__index = sm.Emitter})
  emitter.kind = kind
  return emitter
end

-- TODO Emitter.emit

local Edge = {}
sm.Edge = Edge
function Edge.new(trigger, guard, effect, to)
  local edge = {}
  setmetatable(edge, {__index = sm.Edge})
  edge.trigger = trigger
  edge.guard = guard
  edge.effect = effect
  edge.to = to
  return edge
end

function Edge:matches(event)
  return self.trigger == event.kind
end

-- TODO: this needs to get the inner state of the machine somehow
function Edge:passes_guard(object_state, event)
  if self.guard then
    return self.guard(object_state, event)
  end
  return true
end

function Edge:execute(object_state, event)
  if self.effect then
    self.effect(object_state, event)
  end
  return self.to
end

local initial = 'initial'
local final = 'final'
local regular = 'regular'
local choice = 'choice'
local State = {}
sm.State = State
function State.new(name, transitions)
  local state = {}
  setmetatable(state, {__index = sm.State})
  state.kind = regular
  state.name = name
  state.transitions = transitions
  return state
end

function State.new_choice(name, transitions)
  local state = {}
  setmetatable(state, {__index = sm.State})
  state.kind = choice
  state.name = name
  state.transitions = transitions
  return state
end

function State.new_initial(transition)
  local state = {}
  setmetatable(state, {__index = sm.State})
  state.kind = initial
  state.name = initial
  state.transitions = {transition}
  return state
end

function State.new_final()
  local state = {}
  setmetatable(state, {__index = sm.State})
  state.kind = final
  state.name = final
  state.transitions = {}
  return state
end

local StateMachine = {}
sm.StateMachine = StateMachine
function StateMachine.new(states)
  local machine = {}
  setmetatable(machine, {__index = sm.StateMachine})
  -- TODO: add validation
  local state_lookup = {}
  for _, state in ipairs(states) do
    state_lookup[state.name] = state
  end
  machine.states = state_lookup
  return machine
end

function StateMachine:initialize_object(object_state)
  object_state.state = initial
  -- TODO: run transition from initial state here
end

function StateMachine:process_event(object_state, event)
  local current_state_name = object_state.state
  assert(self.states[current_state_name], "Current object state not a state in state machine")
  local transition_was_taken = false
  repeat
    transition_was_taken = false
    local state = self.states[current_state_name]
    for i, transition in ipairs(state.transitions) do
      if transition:matches(event) and transition:passes_guard(object_state, event) then
	current_state_name = transition:execute(object_state, event)
	assert(self.states[current_state_name], "State transitioned to does not exist in the state table: " .. current_state_name)
	transition_was_taken = true
      end
    end
  until self.states[current_state_name].kind == regular or self.states[current_state_name].kind == final or not transition_was_taken
  object_state.state = current_state_name
end

return state_machine
