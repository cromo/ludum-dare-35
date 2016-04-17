local sm = require 'state_machine'
local sti = require "sti"
local dbg = require 'dbg'
local assets = require 'assets'
local sprites = require 'sprites'
local game_engine = require 'game'

local game
function love.load()
  assets.register('lua', function(path) return sti.new(path, {'box2d'}) end)
  assets.register('png', sprites.Sheet.load)
  assets.load 'assets'

  game = game_engine.new()

  delta_time = sm.Emitter.new('dt')
  raw_key_pressed = sm.Emitter.new('raw_key_pressed')
  raw_key_released = sm.Emitter.new('raw_key_released')
end

function love.draw()
  game:draw()
end

function love.update(dt)
  delta_time:emit(dt)
  sm.EventQueue.pump{game}
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
