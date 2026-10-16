-- Places the four team sprites on court_scene.png like the doubles mock
-- (Blue + Gold left, Red + Green right, facing the net), for a scale check.
--
-- aseprite -b --script-param root=<kit root> --script-param dir=<sheets dir>
--          --script-param out=<png> [--script-param scale=4]
--          --script art/sprites/src/scene.lua

local root, dir, outPath = app.params.root, app.params.dir, app.params.out
local scale = tonumber(app.params.scale or "4")

local function rgbImage(path)
  local s = Sprite { fromFile = path }
  app.command.ChangePixelFormat { format = "rgb" }
  local img = Image(s.width, s.height, ColorMode.RGB)
  img:drawImage(s.cels[1].image, s.cels[1].position)
  s:close()
  return img
end

local bg = rgbImage(root .. "/art/snes-pixel/court_scene.png")

-- team, frame slot (1-based), feet x (centre), feet y, flip, ponytail
local players = {
  { "blue", 8, 74, 112, false, false },
  { "gold", 1, 44, 160, false, true },
  { "red", 2, 186, 114, true, false },
  { "green", 3, 214, 160, true, false },
}
local SLOTS = { "idle0", "idle1", "run0", "run1", "run2", "run3",
                "windup", "swing", "follow", "toss", "cheer" }
local f = assert(io.open(root .. "/data/player_frames.json"))
local meta = json.decode(f:read("a"))
f:close()

for _, p in ipairs(players) do
  local team, slot, fx, fy, flip, pony = table.unpack(p)
  local sheet = rgbImage(dir .. "/player_" .. team .. ".png")
  local body = Image(sheet, Rectangle((slot - 1) * 32, 0, 32, 32))
  local x, y = fx - 16, fy - 29
  -- shadow
  for sx = -9, 9 do
    for sy = -2, 2 do
      if sx * sx / 81 + sy * sy / 4 <= 1 then
        local px, py = fx + sx, fy + sy
        local c = Color(bg:getPixel(px, py))
        bg:drawPixel(px, py, Color { r = c.red * 6 // 10, g = c.green * 6 // 10,
                                     b = c.blue * 6 // 10 })
      end
    end
  end
  local layer = Image(32, 32, ColorMode.RGB)
  if pony then
    local acc = meta.frames[SLOTS[slot]].accessory
    layer:drawImage(Image(sheet, Rectangle(#SLOTS * 32, 0, 8, 8)),
                    Point(acc[1], acc[2]))
  end
  layer:drawImage(body, Point(0, 0))
  if flip then layer:flip(FlipType.HORIZONTAL) end
  bg:drawImage(layer, Point(x, y))
end

-- the ball, mid-rally
for bx = -2, 2 do
  for by = -2, 2 do
    if bx * bx + by * by <= 5 then
      bg:drawPixel(98 + bx, 92 + by, (bx * bx + by * by <= 2)
        and Color { r = 250, g = 232, b = 90 } or Color { r = 196, g = 160, b = 30 })
    end
  end
end

local spr = Sprite(bg.width, bg.height, ColorMode.RGB)
spr.cels[1].image = bg
spr:resize(bg.width * scale, bg.height * scale)
spr:saveCopyAs(outPath)
spr:close()
