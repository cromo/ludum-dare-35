local dbg = require 'dbg'
local sm = require 'state_machine'
local assets = require 'assets'
local sprites = require 'sprites'

local game = {}

local speed_scaling = 10
local player_horizontal_speed = speed_scaling * 30
local player_vertical_speed = speed_scaling * 30

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
  p.collision.fixture:setUserData(p)
  game.player_state_machine:initialize_state(p)
  return p
end

function Player.move(x, y)
  return function(self)
    self.collision.body:setLinearDamping(0)
    self.collision.body:applyLinearImpulse(x, y)
  end
end

function Player:slow_down()
  --self.collision.body:setLinearVelocity(0, 0)
  self.collision.body:setLinearDamping(10)
end

function Player.hit(t)
  return function(self, properties)
    -- dbg.print(properties.type, t, properties.type == t)
    return properties.type == t
  end
end

function Player:stop()
  self.collision.body:setLinearVelocity(0, 0)
end

function Player:stop_x()
  local _, y = self.collision.body:getLinearVelocity()
  self.collision.body:setLinearVelocity(0, y)
end

function Player:draw()
  self.sprite:draw(self.collision.body:getX() - self.sprite:getWidth() / 2, self.collision.body:getY() - self.sprite:getHeight() / 2)
  love.graphics.polygon('line', self.collision.body:getWorldPoints(self.collision.shape:getPoints()))
end

game.player_state_machine = sm.StateMachine.new_from_table{
  {nil, 'jumping'},
  {
    'jumping',
    {
      {'contact_begin', Player.hit('floor'), nil, 'standing'},
      {'raw_key_pressed', is_key('left'), Player.move(-player_horizontal_speed, 0), 'jumping_left'},
      {'raw_key_pressed', is_key('right'), Player.move(player_horizontal_speed, 0), 'jumping_right'},
    }
  },
  {
    'standing',
    {
      {'raw_key_pressed', is_key('space'), Player.move(0, -player_vertical_speed), 'jumping'},
      {'raw_key_pressed', is_key('left'), Player.move(-player_horizontal_speed, 0), 'walking_left'},
      {'raw_key_pressed', is_key('right'), Player.move(player_horizontal_speed, 0), 'walking_right'},
    }
  },
  {
    'walking_left',
    {
      {'raw_key_released', is_key('left'), Player.stop, 'standing'},
      {'raw_key_pressed', is_key('space'), Player.move(0, -player_vertical_speed), 'jumping_left'},
    }
  },
  {
    'jumping_left',
    {
      {'raw_key_released', is_key('left'), Player.stop_x, 'jumping'},
      {'contact_begin', Player.hit('floor'), nil, 'walking_left'}
    }
  },
  {
    'walking_right',
    {
      {'raw_key_released', is_key('right'), Player.stop, 'standing'},
      {'raw_key_pressed', is_key('space'), Player.move(0, -player_vertical_speed), 'jumping_left'},
    }
  },
  {
    'jumping_right',
    {
      {'raw_key_released', is_key('right'), Player.stop_x, 'jumping'},
      {'contact_begin', Player.hit('floor'), nil, 'walking_right'}
    }
  },
}


local Game = {}
game.Game = Game
function Game.new()
  local g = {}
  setmetatable(g, {__index = Game})
  game.state_machine:initialize_state(g)

  set_meter(32)

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
  g.world = love.physics.newWorld(0, 64 * 9.81)
  g.contact_begin = sm.Emitter.new('contact_begin')
  g.contact_end = sm.Emitter.new('contact_end')
  local function emit_collision_event(emitter)
    return function(object, level, contact)
      if object:getUserData().properties then
	object, level = level, object
      end
      local properties = level:getUserData().properties
      emitter:emit(properties)
    end
  end
  g.world:setCallbacks(emit_collision_event(g.contact_begin), emit_collision_event(g.contact_end))

  g.map = assets.factory
  g.map:box2d_init(g.world)

  local player_start = g.map:getObject('collision', 'player')
  local body = new_body(g.world, player_start.x + player_start.width / 2, player_start.y + player_start.height / 2, 'dynamic')
  body:setFixedRotation(true)
  local shape = new_rectangle(0, 0, player_start.width, player_start.height)
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
  if event.kind ~= 'dt' then
    dbg.printf('forwarding %s event', event.kind)
  end
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
