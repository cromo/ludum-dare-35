local dbg = require 'dbg'
local sm = require 'state_machine'
local assets = require 'assets'
local sprites = require 'sprites'

local game = {}

local speed_scaling = 10
local player_horizontal_speed = speed_scaling * 60
local player_max_horizontal_speed = speed_scaling * 45
local player_vertical_speed = speed_scaling * 30
local player_hook_jump_horizontal_speed = speed_scaling * 10

local camera_follow_weight = 0.17

local function opposite_direction(direction)
  local opposites = {
    left = 'right',
    right = 'left',
    up = 'down',
    down = 'up'
  }
  return opposites[direction]
end

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
  p.touching = {
    left = nil,
    right = nil,
    up = nil,
    down = nil
  }
  p.sides = {
    left = 'normal',
    right = 'normal',
    up = 'normal',
    down = 'normal'
  }
  p.movement_direction = 0
  game.player_state_machine:initialize_state(p)
  return p
end

function Player:spawn()
  self.collision.body:setPosition(self.start.x + self.start.width / 2, self.start.y + self.start.height / 2)
  self.collision.body:setLinearVelocity(0, 0)
  self.touching = {
    left = nil,
    right = nil,
    up = nil,
    down = nil
  }
  self.sides = {
    left = 'normal',
    right = 'normal',
    up = 'normal',
    down = 'normal'
  }
end

function Player.add_direction(direction, reason)
  return function(self)
    self.movement_direction = self.movement_direction + direction
    -- dbg.printf('%s: adding %d to direction giving %d', tostring(reason), direction, self.movement_direction)
  end
end

function Player:apply_force()
  self.collision.body:applyForce(self.movement_direction * player_horizontal_speed, 0)
  local x, y = self.collision.body:getLinearVelocity()
  x = clamp(x, -player_max_horizontal_speed, player_max_horizontal_speed)
  self.collision.body:setLinearVelocity(x, y)
end

function Player:changing_direction()
  return self.movement_direction == 0
end

function Player:moving()
  return self.movement_direction ~= 0
end

function Player:stop_movement()
  self.movement_direction = 0
end

function Player:hang()
  self.collision.body:setGravityScale(0)
  self.collision.body:setLinearVelocity(0, 0)
  --self:stop_movement()
end

function Player:getX()
  return self.collision.body:getX()
end

function Player:getY()
  return self.collision.body:getY()
end

function Player.accelerate(x, y)
  return function(self, dt)
    self.collision.body:applyForce(x, y)
    local x, y = self.collision.body:getLinearVelocity()
    x = clamp(x, -player_max_horizontal_speed, player_max_horizontal_speed)
    self.collision.body:setLinearVelocity(x, y)
  end
end

function Player.move(x, y)
  return function(self)
    self.collision.body:setLinearDamping(0)
    self.collision.body:applyLinearImpulse(x, y)
  end
end

function Player.hit(t)
  return function(self, colliders)
    return collided(colliders, 'player', t)
  end
end

function Player:now_touching(collision)
  local static = collision.a
  if collision.a.type == 'player' then
    static = collision.b
  end
  local side = opposite_direction(static.fixture:getUserData().properties.facing)
  self.touching[side] = static.type
  dbg.printf('player %s side now touching %s', side, self.touching[side])
end

function Player:stop_touching(collision)
  local static = collision.a
  if collision.a.type == 'player' then
    static = collision.b
  end
  local side = opposite_direction(static.fixture:getUserData().properties.facing)
  local was_touching = self.touching[side]
  self.touching[side] = nil
  dbg.printf('player %s side no longer touching %s', side, was_touching)
end

function Player:shift()
  for direction, touching in pairs(self.touching) do
    if touching then
      self.sides[direction] = touching
      dbg.print('shifted', direction, touching)
    end
  end
end

function Player:hooked()
  for direction, touching in pairs(self.touching) do
    local result = touching and touching == self.sides[direction] and touching == 'hook'
    -- dbg.print('hooked', touching, opposite_direction(direction), self.sides[opposite_direction(direction)])
    if result then
      return direction
    end
  end
end

function Player:hooked_jump()
  local side = self:hooked()
  local direction = -1
  if side == 'left' then
    direction = 1
  end
  self.collision.body:setGravityScale(1)
  self.move(direction * player_hook_jump_horizontal_speed, -player_vertical_speed)(self)
end

function Player:set_cell()
  if self.sides.left == 'hook' and self.sides.right then
    self.sprite:set_cell(3, 0)
  elseif self.sides.left == 'hook' then
    self.sprite:set_cell(2, 0)
  elseif self.sides.right == 'hook' then
    self.sprite:set_cell(1, 0)
  else
    self.sprite:set_cell(0, 0)
  end
end

function Player:draw()
  self:set_cell()
  self.sprite:draw(self.collision.body:getX() - self.sprite:getWidth() / 2, self.collision.body:getY() - self.sprite:getHeight() / 2)
  dbg(graphics.polygon, 'line', self.collision.body:getWorldPoints(self.collision.shape:getPoints()))
  dbg(graphics.print, string.format('%s\n%d', self.state.name, self.movement_direction), self.collision.body:getX(), self.collision.body:getY())
end

local jumping = 'jumping'
local standing = 'standing'
local walking = 'walking'
local shifted = 'shifted'
local shifted_jump = 'shifted_jump'
local shifted_walking = 'shifted_walking'
local hooked = 'hooked'

local started_touching = 'contact_begin'
local stopped_touching = 'contact_end'
local pressed = 'raw_key_pressed'
local released = 'raw_key_released'
local update = 'dt'

local left = is_key 'left'
local right = is_key 'right'
local jump = is_key 'space'
local shift = is_key 'lshift'

local floor = 'floor'
local death = 'killbox'
local hook = 'hook'
local goal = 'goal'

game.player_state_machine = sm.StateMachine.new_from_table{
  {nil, jumping},
  {
    standing,
    {
      {pressed, jump, Player.move(0, -player_vertical_speed), jumping},
      {pressed, left, Player.add_direction(-1, 'standing hit left'), walking},
      {released, left, Player.add_direction(1, 'standing released left'), walking},
      {pressed, right, Player.add_direction(1, 'standing hit right'), walking},
      {released, right, Player.add_direction(-1, 'standing released right'), walking},
      {started_touching, Player.hit(death), Player.spawn, jumping},
      {pressed, shift, Player.shift, shifted},
      {started_touching, Player.hit(goal), annotate('winner is you')},
    }
  },
  {
    walking,
    {
      {update, nil, Player.apply_force},
      {pressed, left, Player.add_direction(-1, 'walking hit left')},
      {released, {left, Player.changing_direction}, Player.add_direction(1, 'walking released left changing direction')},
      {released, left, Player.add_direction(1, 'walking released left'), standing},
      {pressed, right, Player.add_direction(1, 'walking hit right')},
      {released, {right, Player.changing_direction}, Player.add_direction(-1, 'walking released right changing direction')},
      {released, right, Player.add_direction(-1, 'walking released right'), standing},
      {pressed, jump, Player.move(0, -player_vertical_speed), jumping},
      {started_touching, Player.hit(death), Player.spawn, jumping},
      {started_touching, Player.hit(hook), Player.now_touching, shifted_walking},
      {stopped_touching, Player.hit(hook), Player.stop_touching},
      {stopped_touching, Player.hit(floor), nil, jumping},
      {pressed, shift, Player.shift, shifted_walking},
      {started_touching, Player.hit(goal), annotate('winner is you')},
    }
  },
  {
    jumping,
    {
      {update, nil, Player.apply_force},
      {started_touching, {Player.hit(floor), Player.moving}, nil, walking},
      {started_touching, Player.hit(floor), nil, standing},
      {pressed, left, Player.add_direction(-1, 'jumping hit left')},
      {released, left, Player.add_direction(1, 'jumping released left')},
      {pressed, right, Player.add_direction(1, 'jumping hit right')},
      {released, right, Player.add_direction(-1, 'jumping released right')},
      {started_touching, Player.hit(death), Player.spawn, jumping},
      {started_touching, Player.hit(hook), Player.now_touching, shifted_jump},
      {stopped_touching, Player.hit(hook), Player.stop_touching},
      {pressed, shift, Player.shift, shifted_jump},
      {started_touching, Player.hit(goal), annotate('winner is you')},
    }
  },
  {
    hooked,
    {
      {pressed, jump, Player.hooked_jump, jumping},
      {pressed, left, Player.add_direction(-1)},
      {released, left, Player.add_direction(1)},
      {pressed, right, Player.add_direction(1)},
      {released, right, Player.add_direction(-1)},
    }
  },
  {
    kind = 'choice',
    shifted,
    {
      {nil, Player.hooked, Player.hang, hooked},
      {nil, nil, nil, standing},
    }
  },
  {
    kind = 'choice',
    shifted_walking,
    {
      {nil, Player.hooked, Player.hang, hooked},
      {nil, nil, nil, walking},
    }
  },
  {
    kind = 'choice',
    shifted_jump,
    {
      {nil, Player.hooked, Player.hang, hooked},
      {nil, nil, nil, jumping},
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
