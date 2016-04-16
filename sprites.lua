local dbg = require 'dbg'
local sprites = {}

local new_image = love.graphics.newImage
local new_quad = love.graphics.newQuad
local draw = love.graphics.draw

local Sheet = {}
sprites.Sheet = Sheet
function Sheet.new(image, cell_width, cell_height)
  local sheet = {}
  setmetatable(sheet, {__index = Sheet})
  sheet.image = image
  sheet.cell_width = cell_width
  sheet.cell_height = cell_height
  return sheet
end

function Sheet.load(filename)
  local basename = filename:gsub('.+/(.+)', '%1')
  local image = new_image(filename)
  local width, height = image:getDimensions()
  if basename:find('.+%..+%..+') then
    width = tonumber(basename:gsub('.+%.(.+)x(.+)%..+', '%1'), 10)
    height = tonumber(basename:gsub('.+%.(.+)x(.+)%..+', '%2'), 10)
  end
  return Sheet.new(image, width, height)
end

local Sprite = {}
sprites.Sprite = Sprite
function Sprite.new(sheet)
  local sprite = {}
  setmetatable(sprite, {__index = Sprite})
  sprite.image = sheet.image
  sprite.cell_width = sheet.cell_width
  sprite.cell_height = sheet.cell_height
  sprite.quad = new_quad(0, 0, sprite.cell_width, sprite.cell_height, sprite.image:getDimensions())
  return sprite
end

function Sprite:set_cell(x, y)
  x = math.floor(x)
  y = math.floor(y)
  self.quad:setViewport(x * self.cell_width, y * self.cell_height, self:getDimensions())
end

function Sprite:getDimensions()
  return self.cell_width, self.cell_height
end

function Sprite:getWidth()
  return self.cell_width
end

function Sprite:getHeight()
  return self.cell_height
end

function Sprite:draw(...)
  draw(self.image, self.quad, ...)
end

sprites.new = Sprite.new
return sprites
