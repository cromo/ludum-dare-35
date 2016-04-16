local dbg = require 'dbg'
local sm = require 'state_machine'
local assets = require 'assets'
local sprites = require 'sprites'

local game = {}

local function is_key(key)
  return function(state, k)
    return key == k
  end
end

local quit = love.event.quit
local get_window_width = love.graphics.getWidth
local get_window_height = love.graphics.getHeight

local Game = {}
game.Game = Game
function Game.new()
  local g = {}
  setmetatable(g, {__index = Game})
  game.state_machine:initialize_state(g)

  local navigate_sheet = sm.StateMachine.new_from_table{
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
	    dbg.print('moving over')
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
  g.test_state = {
    x = 0,
    y = 0,
    s = sprites.new(assets.subspike)
  }
  navigate_sheet:initialize_state(g.test_state)
  return g
end

function Game:forward_event(p, event)
  sm.process(self.test_state, event)
end

function Game:draw()
  assets.spikey:setDrawRange(0, 0, get_window_width(), get_window_height())
  assets.spikey:draw()

  self.test_state.s:draw(0, 0)
end

game.state_machine = sm.StateMachine.new_from_table{
  {nil, 'main_menu'},
  {
    'main_menu', {
      {'raw_key_pressed', is_key('escape'), quit, 'final'},
      {nil, nil, Game.forward_event, 'main_menu'}
    }
  }
}

game.new = Game.new
return game
