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

  dt = sm.Emitter.new('dt')

  test_machine:initialize_state(object)
  dt:emit(2)
  sm.EventQueue.pump{object}
end

function love.draw()
  love.graphics.print("Hello World!", 400, 300)
end
