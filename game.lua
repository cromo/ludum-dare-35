local dbg = require 'dbg'
local sm = require 'state_machine'
local assets = require 'assets'
local sprites = require 'sprites'

local game = {}

local speed_scaling = 20
local player_horizontal_speed = speed_scaling * 30
local player_max_horizontal_speed = speed_scaling * 30
local player_vertical_speed = speed_scaling * 30

local camera_follow_weight = 0.17

local function wrap_collision_fixture(fixture)
  local userdata = fixture:getUserData()
  if not userdata then
    return {
      fixture = fixture,
      type = 'unknown'
    }
  elseif userdata.properties then
    return {
      fixture = fixture,
      type = userdata.properties.type or 'unknown'
    }
  elseif userdata.type then
    return {
      fixture = fixture,
      type = userdata.type or 'unknown'
    }
  end
  return {
    fixture = fixture,
    type = 'unknown'
  }
end

local function emit_collision_event(emitter)
  return function(a, b, contact)
    local colliders = {
      a = wrap_collision_fixture(a),
      b = wrap_collision_fixture(b),
      contact = contact
    }
    dbg.print('collision event between', colliders.a.type, colliders.b.type, contact:getFriction(), contact:getNormal())
    emitter:emit(colliders)
  end
end

local function is_key(key)
  return function(state, k)
    return key == k
  end
end

local function collided(colliders, type_a, type_b)
  return colliders.a.type == type_a and colliders.b.type == type_b or colliders.a.type == type_b and colliders.b.type == type_a
end

local function clamp(value, min, max)
  return math.min(math.max(value, min), max)
end

local function annotate(s, f, ...)
  return function(...)
    local returned = f and f(...)
    dbg.printf('%s returned %s', s, tostring(returned))
    return returned
  end
end

local quit = love.event.quit
local get_window_width = love.graphics.getWidth
local get_window_height = love.graphics.getHeight
local new_body = love.physics.newBody
local new_rectangle = love.physics.newRectangleShape
local new_fixture = love.physics.newFixture
local set_meter = love.physics.setMeter
local graphics = love.graphics

local Player = {}
function Player.new(sheet, world, start)
  local p = {}
  setmetatable(p, {__index = Player})
  p.type = 'player'
  p.sprite = sprites.new(sheet)
  p.start = start
  local body = new_body(world, start.x + start.width / 2, start.y + start.height / 2, 'dynamic')
  body:setFixedRotation(true)
  local shape = new_rectangle(0, 0, start.width, start.height)
  local fixture = new_fixture(body, shape, 1)
  p.collision = {
    body = body,
    shape = shape,
    fixture = fixture
  }
  p.collision.fixture:setUserData(p)
  game.player_state_machine:initialize_state(p)
  return p
end

function Player:spawn()
  self.collision.body:setPosition(self.start.x + self.start.width / 2, self.start.y + self.start.height / 2)
  self.collision.body:setLinearVelocity(0, 0)
end

function Player:move_sensors()
end

function Player:getX()
  return self.collision.body:getX()
end

function Player:getY()
  return self.collision.body:getY()
end

function Player.move(x, y)
  return function(self)
    self.collision.body:setLinearDamping(0)
    self.collision.body:applyLinearImpulse(x, y)
  end
end

function Player.move_x(x)
  return function(self)
    self.collision.body:setLinearDamping(0)
    self:stop_x()
    self.collision.body:applyLinearImpulse(x, 0)
  end
end

function Player.accelerate(x, y)
  return function(self, dt)
    self.collision.body:applyForce(x, y)
    local x, y = self.collision.body:getLinearVelocity()
    x = clamp(x, -player_max_horizontal_speed, player_max_horizontal_speed)
    self.collision.body:setLinearVelocity(x, y)
  end
end

function Player:slow_down()
  --self.collision.body:setLinearVelocity(0, 0)
  self.collision.body:setLinearDamping(10)
end

function Player.hit(t)
  return function(self, colliders)
    return collided(colliders, 'player', t)
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
  dbg(graphics.polygon, 'line', self.collision.body:getWorldPoints(self.collision.shape:getPoints()))
end

game.player_state_machine = sm.StateMachine.new_from_table{
  {nil, 'jumping'},
  {
    'jumping',
    {
      {'dt', nil, Player.move_sensors, 'jumping'},
      {'contact_begin', Player.hit('floor'), nil, 'standing'},
      {'raw_key_pressed', is_key('left'), nil, 'jumping_left'},
      {'raw_key_pressed', is_key('right'), nil, 'jumping_right'},
      {'contact_begin', Player.hit('killbox'), Player.spawn, 'jumping'},
    }
  },
  {
    'jumping_left',
    {
      {'dt', nil, Player.accelerate(-player_horizontal_speed, 0), 'jumping_left'},
      {'raw_key_released', is_key('left'), Player.stop_x, 'jumping'},
      {'raw_key_pressed', is_key('right'), nil, 'jumping_left_holding_right'},
      {'contact_begin', Player.hit('floor'), nil, 'walking_left'},
      {'contact_begin', Player.hit('killbox'), Player.spawn, 'jumping'},
    }
  },
  {
    'jumping_left_holding_right',
    {
      {'dt', nil, Player.accelerate(-player_horizontal_speed, 0), 'jumping_left_holding_right'},
      {'raw_key_released', is_key('left'), nil, 'jumping_right'},
      {'raw_key_released', is_key('right'), nil, 'jumping_left'},
      {'contact_begin', Player.hit('floor'), nil, 'walking_left_holding_right'},
      {'contact_begin', Player.hit('killbox'), Player.spawn, 'jumping'},
    }
  },
  {
    'jumping_right',
    {
      {'dt', nil, Player.accelerate(player_horizontal_speed, 0), 'jumping_right'},
      {'raw_key_released', is_key('right'), Player.stop_x, 'jumping'},
      {'raw_key_pressed', is_key('left'), nil, 'jumping_right_holding_left'},
      {'contact_begin', Player.hit('floor'), nil, 'walking_right'},
      {'contact_begin', Player.hit('killbox'), Player.spawn, 'jumping'},
    }
  },
  {
    'jumping_right_holding_left',
    {
      {'dt', nil, Player.accelerate(player_horizontal_speed, 0), 'jumping_right_holding_left'},
      {'raw_key_released', is_key('left'), nil, 'jumping_right'},
      {'raw_key_released', is_key('right'), nil, 'jumping_left'},
      {'contact_begin', Player.hit('floor'), nil, 'walking_right_holding_left'},
      {'contact_begin', Player.hit('killbox'), Player.spawn, 'jumping'},
    }
  },
  {
    'standing',
    {
      {'raw_key_pressed', is_key('space'), Player.move(0, -player_vertical_speed), 'jumping'},
      {'raw_key_pressed', is_key('left'), nil, 'walking_left'},
      {'raw_key_pressed', is_key('right'), nil, 'walking_right'},
    }
  },
  {
    'walking_left',
    {
      {'dt', nil, Player.accelerate(-player_horizontal_speed, 0), 'walking_left'},
      {'raw_key_released', is_key('left'), Player.stop, 'standing'},
      {'raw_key_pressed', is_key('space'), Player.move(0, -player_vertical_speed), 'jumping_left'},
      {'raw_key_pressed', is_key('right'), nil, 'walking_left_holding_right'},
      {'contact_end', Player.hit('floor'), nil, 'jumping_left'},
    }
  },
  {
    'walking_left_holding_right',
    {
      {'dt', nil, Player.accelerate(-player_horizontal_speed, 0), 'walking_left_holding_right'},
      {'raw_key_released', is_key('left'), Player.move_x(player_horizontal_speed), 'walking_right'},
      {'raw_key_released', is_key('right'), nil, 'walking_left'},
      {'raw_key_pressed', is_key('space'), Player.move(0, -player_vertical_speed), 'jumping_left_holding_right'},
      {'contact_end', Player.hit('floor'), nil, 'jumping_left_holding_right'},
    }
  },
  {
    'walking_right',
    {
      {'dt', nil, Player.accelerate(player_horizontal_speed, 0), 'walking_right'},
      {'raw_key_released', is_key('right'), Player.stop, 'standing'},
      {'raw_key_pressed', is_key('space'), Player.move(0, -player_vertical_speed), 'jumping_right'},
      {'raw_key_pressed', is_key('left'), nil, 'walking_right_holding_left'},
      {'contact_end', Player.hit('floor'), nil, 'jumping_right'},
    }
  },
  {
    'walking_right_holding_left',
    {
      {'dt', nil, Player.accelerate(player_horizontal_speed, 0), 'walking_right_holding_left'},
      {'raw_key_released', is_key('left'), nil, 'walking_right'},
      {'raw_key_released', is_key('right'), Player.move_x(-player_horizontal_speed), 'walking_left'},
      {'raw_key_pressed', is_key('space'), Player.move(0, -player_vertical_speed), 'jumping_right_holding_left'},
      {'contact_end', Player.hit('floor'), nil, 'jumping_right_holding_left'},
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

  g.world = love.physics.newWorld(0, 64 * 9.81)
  g.contact_begin = sm.Emitter.new('contact_begin')
  g.contact_end = sm.Emitter.new('contact_end')
  local presolve = sm.Emitter.new('presolve')
  g.world:setCallbacks(
    emit_collision_event(g.contact_begin),
    emit_collision_event(g.contact_end)
  )

  g.map = assets.factory
  g.map:box2d_init(g.world)

  g.map.layers.collision.visible = false
  dbg(function() g.map.layers.collision.visible = true end)
  local player_start = g.map:getObject('collision', 'player')
  g.player = Player.new(assets.player, g.world, player_start)

  g.last = {}

  return g
end

function Game:forward_event(p, event)
  if event.kind ~= 'dt' then
    -- dbg.printf('forwarding %s event', event.kind)
  end
  sm.process(self.player, event)
end

function Game:update(dt, event)
  self.world:update(dt)
  self:forward_event(dt, event)
end

function Game:draw()
  local p = self.player
  local map = self.map
  local bg = map.layers['background']
  local tile = bg.data[1][1]

  local bg_width = bg.width * tile.width
  local bg_height = bg.height * tile.height

  local half_width = graphics.getWidth() / 2
  local half_height = graphics.getHeight() / 2

  local tx = clamp(math.floor(p:getX()), half_width, bg_width - half_width) - half_width
  local ty = clamp(math.floor(p:getY()), half_height, bg_height - half_height) - half_height
  if self.last.tx then
    tx = math.floor(tx * camera_follow_weight + self.last.tx * (1 - camera_follow_weight))
    ty = math.floor(ty * camera_follow_weight + self.last.ty * (1 - camera_follow_weight))
  end
  self.last.tx = tx
  self.last.ty = ty

  graphics.push()
  graphics.translate(-tx, -ty)
  self.map:setDrawRange(tx, ty, graphics.getWidth(), graphics.getHeight())
  self.map:draw()

  self.player:draw()
  graphics.pop()
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
