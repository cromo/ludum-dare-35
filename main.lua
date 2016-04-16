local sm = require 'state_machine'
local sti = require "sti"
local dbg = require 'dbg'
local assets = require 'assets'

function love.load()
  test_machine = sm.StateMachine.new_from_table{
    {
      function(state, event)
	dbg.print('initial2: ' .. state.kind)
      end,
      'test'
    },
    {
      'test', {
	{
	  'dt',
	  nil,
	  function(state, event)
	    dbg.print('dt2: ' .. state.kind .. ' ' .. event.kind)
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

  windowWidth = love.graphics.getWidth()
  windowHeight = love.graphics.getHeight()

  assets.register('lua', function(path) return sti.new(path) end)
  assets.load 'assets'
end

function love.draw()
  assets.maps.spikey:setDrawRange(0, 0, windowWidth, windowHeight)
  assets.maps.spikey:draw()
end
