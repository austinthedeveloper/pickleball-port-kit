-- Builds the player sprite from player_frames.txt (indexed, palette contract v2).
--
-- aseprite -b --script-param root=<kit root> --script-param out=<dir> \
--          --script art/sprites/src/build_player.lua
--
-- Writes <out>/player.aseprite (blue team, tagged animations) and
-- <out>/player_<team>.png sheets (11 frames in player_frames.json slot order,
-- plus ponytail accessory) for every team palette.

local root = app.params.root or "."
local out = app.params.out or (root .. "/art/sprites")
local src = root .. "/art/sprites/src/player_frames.txt"

local W, H = 32, 32
local SLOTS = { "idle0", "idle1", "run0", "run1", "run2", "run3",
                "windup", "swing", "follow", "toss", "cheer" }
local TEAMS = { "blue", "red", "green", "gold" }
local TEAM_PADDLE = { blue = "blue", red = "red", green = "wood", gold = "gold" }

-- ASCII key -> contract v2 index (ADR-013)
local KEY = {
  ["."] = 0, o = 1, a = 2, b = 3, c = 4, D = 5, M = 6, L = 7,
  q = 8, w = 9, x = 10, p = 11, P = 12, e = 13, h = 14, r = 15,
}

local function readJson(path)
  local f = assert(io.open(path, "r"), path)
  local t = json.decode(f:read("a"))
  f:close()
  return t
end

local function c5(v) -- 5-bit SNES RGB -> 8-bit
  return Color { r = v[1] * 255 // 31, g = v[2] * 255 // 31, b = v[3] * 255 // 31 }
end

local function buildPalette(team)
  local pd = root .. "/data/palettes/"
  local shared = readJson(pd .. "shared.json")
  local skin = readJson(pd .. "skin_light.json")
  local t = readJson(pd .. "team_" .. team .. ".json")
  local pad = readJson(pd .. "paddle_" .. TEAM_PADDLE[team] .. ".json")
  local pal = Palette(16)
  pal:setColor(0, Color { r = 255, g = 0, b = 255, a = 0 })
  pal:setColor(1, c5(shared.outline))
  for i = 1, 3 do pal:setColor(1 + i, c5(skin.skin[i])) end
  for i = 1, 3 do pal:setColor(4 + i, c5(t.shirt[i])) end
  pal:setColor(8, c5(t.shorts[1]))
  pal:setColor(9, c5(t.shorts[2]))
  pal:setColor(10, c5(t.shoe))
  pal:setColor(11, c5(pad.face[1]))
  pal:setColor(12, c5(pad.face[2]))
  pal:setColor(13, c5(pad.edge))
  pal:setColor(14, c5(shared.highlight))
  pal:setColor(15, c5(skin.hair))
  return pal
end

-- Parse "== name" blocks of up to 32 rows of 32 chars (8 for the ponytail).
local function readFrames()
  local frames, order, cur = {}, {}, nil
  for line in io.lines(src) do
    local name = line:match("^==%s*(%S+)")
    if name then
      cur = {}
      frames[name] = cur
      order[#order + 1] = name
    elseif cur and not line:match("^#") and #line > 0 then
      local w = order[#order] == "ponytail" and 8 or W
      assert(#line == w, ("%s row %d is %d wide"):format(order[#order], #cur, #line))
      cur[#cur + 1] = line
    end
  end
  for name, rows in pairs(frames) do
    assert(#rows <= H, name .. " has too many rows")
  end
  return frames
end

local function paint(img, rows, ox, oy)
  for y, row in ipairs(rows) do
    for x = 1, #row do
      local ch = row:sub(x, x)
      local idx = KEY[ch]
      assert(idx, "unknown key '" .. ch .. "'")
      if idx ~= 0 then img:drawPixel(ox + x - 1, oy + y - 1, idx) end
    end
  end
end

local frames = readFrames()

-- Source file: one tagged animation per pose, blue palette.
local spr = Sprite(W, H, ColorMode.INDEXED)
spr.transparentColor = 0
spr:setPalette(buildPalette("blue"))
local body = spr.layers[1]
body.name = "body"
for i, name in ipairs(SLOTS) do
  if i > 1 then spr:newEmptyFrame() end
  local img = Image(W, H, ColorMode.INDEXED)
  img:clear(0)
  paint(img, assert(frames[name], "missing frame " .. name), 0, 0)
  spr:newCel(body, i, img, Point(0, 0))
  spr.frames[i].duration = 0.1
end
local function tag(name, a, b, ms)
  local t = spr:newTag(a, b)
  t.name = name
  for f = a, b do spr.frames[f].duration = ms / 1000 end
end
tag("idle", 1, 2, 300)
tag("run", 3, 6, 100)
tag("swing", 7, 9, 67)
tag("toss", 10, 10, 200)
tag("cheer", 11, 11, 200)
spr:saveAs(out .. "/player.aseprite")

-- Ponytail accessory (ADR-014), 8x8 in its own little sprite.
local pony = Sprite(8, 8, ColorMode.INDEXED)
pony.transparentColor = 0
pony:setPalette(buildPalette("blue"))
local pimg = Image(8, 8, ColorMode.INDEXED)
pimg:clear(0)
paint(pimg, assert(frames["ponytail"]), 0, 0)
pony:newCel(pony.layers[1], 1, pimg, Point(0, 0))
pony:saveAs(out .. "/ponytail.aseprite")

-- Per-team sheets: frames in slot order, then the ponytail in a 32x32 cell.
for _, team in ipairs(TEAMS) do
  local sheet = Sprite(W * (#SLOTS + 1), H, ColorMode.INDEXED)
  sheet.transparentColor = 0
  sheet:setPalette(buildPalette(team))
  local img = Image(sheet.width, H, ColorMode.INDEXED)
  img:clear(0)
  for i, name in ipairs(SLOTS) do paint(img, frames[name], (i - 1) * W, 0) end
  paint(img, frames["ponytail"], #SLOTS * W, 0)
  sheet:newCel(sheet.layers[1], 1, img, Point(0, 0))
  sheet:saveCopyAs(out .. "/player_" .. team .. ".png")
  sheet:close()
end
pony:close()
spr:close()
