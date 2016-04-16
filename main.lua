local sm = require 'state_machine'

function love.load()
  test_machine = sm.StateMachine.new{
    sm.State.new_initial(sm.Edge.new(nil, nil, function(state, event) print('initial: ' .. state.kind) end, 'test')),
    sm.State.new('test', {
	sm.Edge.new('dt', nil, function(state, event) print('dt: ' .. state.kind .. ' ' .. event.kind) end, 'final')
    }),
    sm.State.new_final()
  }

  object = {
    kind = 'foo',
  }

  test_machine:initialize_object(object)
  test_machine:process_event(object, sm.Event.new(nil, nil))
  test_machine:process_event(object, sm.Event.new('loopy', {}))
  test_machine:process_event(object, sm.Event.new('dt', {dt = 1}))
  test_machine:process_event(object, sm.Event.new('hoopy', {}))
end

function love.draw()
  love.graphics.print("Hello World!", 400, 300)
end
