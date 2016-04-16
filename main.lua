local sm = require 'state_machine'
local sti = require "sti"
local dbg = require 'dbg'
local assets = require 'assets'
local sprites = require 'sprites'

function love.load()
  navigate_sheet = sm.StateMachine.new_from_table{
    {nil, 'listening'},
    {
      'listening', {
	{
	  'raw_key_pressed',
	  function(state, key)
	    return key == 'left' and state.x == 1
	  end,
	  function(state, key)
	    state.x = state.x - 1
	    state.s:set_cell(state.x, state.y)
	  end,
	  'listening'
	},
	{
	  'raw_key_pressed',
	  function(state, key)
	    return key == 'right' and state.x == 0
	  end,
	  function(state, key)
	    state.x = state.x + 1
	    state.s:set_cell(state.x, state.y)
	  end,
	  'listening'
	},
	{
	  'raw_key_pressed',
	  function(state, key)
	    return key == 'up' and state.y == 1
	  end,
	  function(state, key)
	    state.y = state.y - 1
	    state.s:set_cell(state.x, state.y)
	  end,
	  'listening'
	},
	{
	  'raw_key_pressed',
	  function(state, key)
	    return key == 'down' and state.y == 0
	  end,
	  function(state, key)
	    state.y = state.y + 1
	    state.s:set_cell(state.x, state.y)
	  end,
	  'listening'
	}
      }
    }
  }

  assets.register('lua', function(path) return sti.new(path) end)
  assets.register('png', sprites.Sheet.load)
  assets.load 'assets'

  test_state = {
    x = 0,
    y = 0,
    s = sprites.new(assets.subspike)
  }
  navigate_sheet:initialize_state(test_state)

  delta_time = sm.Emitter.new('dt')
  raw_key_pressed = sm.Emitter.new('raw_key_pressed')
  raw_key_released = sm.Emitter.new('raw_key_reseased')
end

function love.draw()
  local windowWidth = love.graphics.getWidth()
  local windowHeight = love.graphics.getHeight()

  assets.spikey:setDrawRange(0, 0, windowWidth, windowHeight)
  assets.spikey:draw()
  test_state.s:draw(0, 0)
end

function love.update(dt)
  delta_time:emit(dt)
  sm.EventQueue.pump{test_state}
end

function love.keypressed(key, scancode, is_repeat)
  if is_repeat then
    return
  end
  raw_key_pressed:emit(key)
end

function love.keyreleased(key)
  raw_key_released:emit(key)
end
