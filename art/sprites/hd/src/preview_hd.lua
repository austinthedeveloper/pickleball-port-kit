-- Preview: chosen frames for chosen teams (male row, female row), scaled,
-- on a court-teal background with ground shadows.
--
-- aseprite -b --script-param dir=<sheets dir> --script-param out=<png>
--   [--script-param frames=1,2] [--script-param teams=blue,red]
--   [--script-param scale=4] --script art/sprites/hd/src/preview_hd.lua

local dir, outPath = app.params.dir, app.params.out
local scale = tonumber(app.params.scale or "4")
local teams = {}
for t in (app.params.teams or "blue,red,green,gold"):gmatch("%a+") do teams[#teams + 1] = t end

local function rgbImage(path)
  local s = Sprite { fromFile = path }
  app.command.ChangePixelFormat { format = "rgb" }
  local img = Image(s.width, s.height, ColorMode.RGB)
  img:drawImage(s.cels[1].image, s.cels[1].position)
  s:close()
  return img
end

local CELL, PAD, GROUND = 64, 2, 58
local probe = rgbImage(dir .. "/player_hd_male_" .. teams[1] .. ".png")
local nframes = probe.width // CELL
local pick = {}
if app.params.frames then
  for n in app.params.frames:gmatch("%d+") do pick[#pick + 1] = tonumber(n) end
else
  for i = 1, nframes do pick[i] = i end
end

local w = #pick * (CELL + PAD) + PAD
local h = #teams * 2 * (CELL + PAD) + PAD
local canvas = Image(w, h, ColorMode.RGB)
canvas:clear(Color { r = 44, g = 122, b = 108 })

local row = 0
for _, team in ipairs(teams) do
  for _, variant in ipairs { "male", "female" } do
    local sheet = rgbImage(dir .. "/player_hd_" .. variant .. "_" .. team .. ".png")
    for ci, slot in ipairs(pick) do
      local dx = PAD + (ci - 1) * (CELL + PAD)
      local dy = PAD + row * (CELL + PAD)
      for x = 0, CELL - 1 do
        for y = GROUND - 3, GROUND + 3 do
          if ((x - 27) / 15) ^ 2 + ((y - GROUND) / 2.6) ^ 2 <= 1 then
            canvas:drawPixel(dx + x, dy + y, Color { r = 28, g = 82, b = 72 })
          end
        end
      end
      canvas:drawImage(Image(sheet, Rectangle((slot - 1) * CELL, 0, CELL, CELL)),
                       Point(dx, dy))
    end
    row = row + 1
  end
end

local spr = Sprite(w, h, ColorMode.RGB)
spr.cels[1].image = canvas
spr:resize(w * scale, h * scale)
spr:saveCopyAs(outPath)
spr:close()
