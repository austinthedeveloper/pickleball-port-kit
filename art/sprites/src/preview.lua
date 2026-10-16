-- Preview: every team's frames side by side on a court-teal background,
-- scaled up. Optional female row (ponytail at each frame's accessory offset).
--
-- aseprite -b --script-param dir=<sheets dir> --script-param root=<kit root>
--          [--script-param scale=6] [--script-param frames=1,2,3]
--          --script-param out=<png> --script art/sprites/src/preview.lua

local dir = app.params.dir
local root = app.params.root
local scale = tonumber(app.params.scale or "6")
local outPath = app.params.out
local teams = {}
for t in (app.params.teams or "blue,red,green,gold"):gmatch("%a+") do teams[#teams + 1] = t end
local SLOTS = { "idle0", "idle1", "run0", "run1", "run2", "run3",
                "windup", "swing", "follow", "toss", "cheer" }

local pick = {}
if app.params.frames then
  for n in app.params.frames:gmatch("%d+") do pick[#pick + 1] = tonumber(n) end
else
  for i = 1, #SLOTS do pick[i] = i end
end

local f = assert(io.open(root .. "/data/player_frames.json"))
local meta = json.decode(f:read("a"))
f:close()

local CELL, PAD = 32, 4
local cols, rows = #pick, #teams * 2
local w = cols * (CELL + PAD) + PAD
local h = rows * (CELL + PAD) + PAD
local canvas = Image(w, h, ColorMode.RGB)
canvas:clear(Color { r = 46, g = 128, b = 112 })

for ti, team in ipairs(teams) do
  local ss = Sprite { fromFile = dir .. "/player_" .. team .. ".png" }
  app.command.ChangePixelFormat { format = "rgb" }
  local sheet = Image(ss.width, ss.height, ColorMode.RGB)
  sheet:drawImage(ss.cels[1].image, ss.cels[1].position)
  ss:close()
  for female = 0, 1 do
    local row = (ti - 1) * 2 + female
    for ci, slot in ipairs(pick) do
      local dx = PAD + (ci - 1) * (CELL + PAD)
      local dy = PAD + row * (CELL + PAD)
      if female == 1 then
        local acc = meta.frames[SLOTS[slot]].accessory
        local pony = Image(sheet, Rectangle(#SLOTS * CELL, 0, 8, 8))
        canvas:drawImage(pony, Point(dx + acc[1], dy + acc[2]))
      end
      -- shadow
      for x = 6, 25 do
        for y = 28, 30 do
          if (x - 15.5) ^ 2 / 100 + (y - 29) ^ 2 / 2.2 <= 1 then
            canvas:drawPixel(dx + x, dy + y, Color { r = 30, g = 84, b = 74 })
          end
        end
      end
      canvas:drawImage(Image(sheet, Rectangle((slot - 1) * CELL, 0, CELL, CELL)),
                       Point(dx, dy))
    end
  end
end

local spr = Sprite(w, h, ColorMode.RGB)
spr.cels[1].image = canvas
spr:resize(w * scale, h * scale)
spr:saveCopyAs(outPath)
spr:close()
