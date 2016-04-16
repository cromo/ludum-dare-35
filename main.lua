local sm = require 'state_machine'

function love.load()
  test_machine = sm.StateMachine.new_from_table{
    {
      function(state, event)
	print('initial2: ' .. state.kind)
      end,
      'test'
    },
    {
      'test', {
	{
	  'dt',
	  nil,
	  function(state, event)
	    print('dt2: ' .. state.kind .. ' ' .. event.kind)
	  end,
	  'final'
	}
      }
    }
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
