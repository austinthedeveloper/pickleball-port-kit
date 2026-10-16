-- Scale check: the four HD players at the level-03 doubles spots, drawn on a
-- concept image shrunk to its native pixel size (about 320x280).
--
-- aseprite -b --script-param bg=<shrunk concept png> --script-param dir=<sheets dir>
--          --script-param out=<png> [--script-param scale=3]
--          --script art/sprites/hd/src/scene_hd.lua

local dir, outPath = app.params.dir, app.params.out
local scale = tonumber(app.params.scale or "3")

local function rgbImage(path)
  local s = Sprite { fromFile = path }
  if s.colorMode ~= ColorMode.RGB then app.command.ChangePixelFormat { format = "rgb" } end
  local img = Image(s.width, s.height, ColorMode.RGB)
  img:drawImage(s.cels[1].image, s.cels[1].position)
  s:close()
  return img
end

local bg = rgbImage(app.params.bg)
local CELL, GROUND, ANCHOR_X = 64, 58, 28

-- team, variant, frame (1-based), feet x, feet y, facing left
local players = {
  { "blue", "male", 8, 104, 137, false },
  { "gold", "female", 1, 52, 197, false },
  { "red", "male", 2, 222, 143, true },
  { "green", "male", 3, 272, 197, true },
}

for _, p in ipairs(players) do
  local team, variant, slot, fx, fy, left = table.unpack(p)
  local sheet = rgbImage(dir .. "/player_hd_" .. variant .. "_" .. team .. ".png")
  local img = Image(sheet, Rectangle((slot - 1) * CELL, 0, CELL, CELL))
  local ax = ANCHOR_X
  if left then
    img:flip(FlipType.HORIZONTAL)
    ax = CELL - 1 - ANCHOR_X
  end
  for sx = -13, 13 do
    for sy = -3, 3 do
      if sx * sx / 169 + sy * sy / 9 <= 1 then
        local px, py = fx + sx, fy + sy
        if px >= 0 and py >= 0 and px < bg.width and py < bg.height then
          local c = Color(bg:getPixel(px, py))
          bg:drawPixel(px, py, Color { r = c.red * 6 // 10, g = c.green * 6 // 10,
                                       b = c.blue * 6 // 10 })
        end
      end
    end
  end
  bg:drawImage(img, Point(fx - ax, fy - GROUND))
end

local spr = Sprite(bg.width, bg.height, ColorMode.RGB)
spr.cels[1].image = bg
spr:resize(bg.width * scale, bg.height * scale)
spr:saveCopyAs(outPath)
spr:close()
