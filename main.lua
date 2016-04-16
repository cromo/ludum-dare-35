local sm = require 'state_machine'
local sti = require "sti"
local dbg = require 'dbg'
local assets = require 'assets'
local sprites = require 'sprites'

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
  assets.register('png', sprites.Sheet.load)
  assets.load 'assets'

  s = sprites.new(assets.subspike)
end

function love.draw()
  assets.spikey:setDrawRange(0, 0, windowWidth, windowHeight)
  assets.spikey:draw()
  s:set_cell(0, 1)
  s:draw(10, 20)
end
