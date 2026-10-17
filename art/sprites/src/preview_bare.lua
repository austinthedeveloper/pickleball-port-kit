-- Preview of the bareheaded set, laid out the way the game composes it:
-- row 1 bare, row 2 with ponytail, row 3 with the cap cell, row 4 idle0
-- wearing each hat. Uses offsets_bare.json for every placement.
--
-- aseprite -b --script-param root=<kit root> --script-param out=<png>
--   [--script-param team=blue] [--script-param scale=6]
--   --script art/sprites/src/preview_bare.lua

local root = app.params.root or "."
local dir = app.params.dir or (root .. "/art/sprites/bare")
local team = app.params.team or "blue"
local scale = tonumber(app.params.scale or "6")
local outPath = app.params.out

local function readJson(path)
  local f = assert(io.open(path, "r"), path)
  local t = json.decode(f:read("a"))
  f:close()
  return t
end

local function rgbImage(path)
  local s = Sprite { fromFile = path }
  app.command.ChangePixelFormat { format = "rgb" }
  local img = Image(s.width, s.height, ColorMode.RGB)
  img:drawImage(s.cels[1].image, s.cels[1].position)
  s:close()
  return img
end

local offs = readJson(root .. "/art/sprites/src/offsets_bare.json").frames
local sheet = rgbImage(dir .. "/player_bare_" .. team .. ".png")
local hats = rgbImage(dir .. "/hats_" .. team .. ".png")
local n = #offs
local CELL, PAD = 32, 3
local pony = Image(sheet, Rectangle(n * CELL, 0, 8, 8))
local cap = Image(hats, Rectangle(0, 0, 16, 8))

local w = n * (CELL + PAD) + PAD
local h = 4 * (CELL + PAD) + PAD
local canvas = Image(w, h, ColorMode.RGB)
canvas:clear(Color { r = 46, g = 128, b = 112 })

for i, o in ipairs(offs) do
  local body = Image(sheet, Rectangle((i - 1) * CELL, 0, CELL, CELL))
  for row = 0, 2 do
    local dx = PAD + (i - 1) * (CELL + PAD)
    local dy = PAD + row * (CELL + PAD)
    if row == 1 then
      canvas:drawImage(pony, Point(dx + o.accessory[1], dy + o.accessory[2]))
    end
    canvas:drawImage(body, Point(dx, dy))
    if row == 2 then
      canvas:drawImage(cap, Point(dx + o.hat[1], dy + o.hat[2]))
    end
  end
end

-- idle0 wearing each hat, in hats_<team>.png order
local idle = Image(sheet, Rectangle(0, 0, CELL, CELL))
for k = 0, math.floor(hats.width / 16) - 1 do
  local dx = PAD + k * (CELL + PAD)
  local dy = PAD + 3 * (CELL + PAD)
  canvas:drawImage(idle, Point(dx, dy))
  canvas:drawImage(Image(hats, Rectangle(k * 16, 0, 16, 8)),
                   Point(dx + offs[1].hat[1], dy + offs[1].hat[2]))
end

local spr = Sprite(w, h, ColorMode.RGB)
spr.cels[1].image = canvas
spr:resize(w * scale, h * scale)
spr:saveCopyAs(outPath)
spr:close()
