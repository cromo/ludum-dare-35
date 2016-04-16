local sti = require "sti"

function love.load()
	windowWidth = love.graphics.getWidth()
	windowHeight = love.graphics.getHeight()
	map = sti.new("assets/spikey.lua")
end

function love.draw()
	map:setDrawRange(0, 0, windowWidth, windowHeight)
	map:draw()
end
