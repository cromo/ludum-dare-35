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
local new_body = love.physics.newBody
local new_rectangle = love.physics.newRectangleShape
local new_fixture = love.physics.newFixture
local set_meter = love.physics.setMeter

local Player = {}
function Player.new(sheet, collision)
  local p = {}
  setmetatable(p, {__index = Player})
  p.sprite = sprites.new(sheet)
  p.collision = collision
  game.player_state_machine:initialize_state(p)
  return p
end

function Player:move_right(dt)
  self.collision.body:setLinearVelocity(100, 0)
end

function Player:stop_moving_right()
  self.collision.body:setLinearVelocity(0, 0)
end

function Player:draw()
  self.sprite:draw(self.collision.body:getX() - 64, self.collision.body:getY() - 64)
  love.graphics.polygon('line', self.collision.body:getWorldPoints(self.collision.shape:getPoints()))
end

game.player_state_machine = sm.StateMachine.new_from_table{
  {nil, 'idle'},
  {
    'idle',
    {
      {'raw_key_pressed', is_key('right'), nil, 'moving_right'}
    }
  },
  {
    'moving_right',
    {
      {'dt', nil, Player.move_right, 'moving_right'},
      {'raw_key_released', is_key('right'), Player.stop_moving_right, 'idle'}
    }
  }
}


local Game = {}
game.Game = Game
function Game.new()
  local g = {}
  setmetatable(g, {__index = Game})
  game.state_machine:initialize_state(g)

  set_meter(64)

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
  g.map = assets.spikey
  g.world = love.physics.newWorld(0, 0)
  g.map:box2d_init(g.world)
  local player_start = g.map.objects[11]
  local body = new_body(g.world, player_start.x + 64, player_start.y + 64, 'dynamic')
  local shape = new_rectangle(0, 0, 128, 128)
  local fixture = new_fixture(body, shape, 1)
  g.player = Player.new(assets.player, {
    body = body,
    shape = shape,
    fixture = fixture
  })

  navigate_sheet:initialize_state(g.test_state)
  return g
end

function Game:forward_event(p, event)
  -- dbg.printf('forwarding %s event', event.kind)
  sm.process(self.test_state, event)
  sm.process(self.player, event)
end

function Game:update(dt, event)
  self.world:update(dt)
  self:forward_event(dt, event)
end

function Game:draw()
  self.map:setDrawRange(0, 0, get_window_width(), get_window_height())
  self.map:draw()

  self.test_state.s:draw(0, 0)

  self.player:draw()
end

game.state_machine = sm.StateMachine.new_from_table{
  {nil, 'main_menu'},
  {
    'main_menu', {
      {'raw_key_pressed', is_key('escape'), quit, 'final'},
      {'dt', nil, Game.update, 'main_menu'},
      {nil, nil, Game.forward_event, 'main_menu'}
    }
  }
}

game.new = Game.new
return game
