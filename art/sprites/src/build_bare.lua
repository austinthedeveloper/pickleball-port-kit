-- Builds the bareheaded SNES player set from player_frames_bare.txt.
--
-- aseprite -b --script-param root=<kit root> [--script-param out=<dir>]
--          --script art/sprites/src/build_bare.lua
--
-- Writes to <out> (default art/sprites/bare):
--   player_bare.aseprite   15 frames (11 + 4 new poses), tagged, blue palette
--   ponytail_bare.aseprite 8x8 accessory
--   hats.aseprite          16x8, one frame per hat (cap, visor, headband,
--                          tricorn, bandana), tagged by name
--   player_bare_<team>.png 512x32: 15 frames, then the ponytail in a 32x32
--                          cell (top-left)
--   cap_<team>.png         16x8 cap cell
--   hats_<team>.png        192x8: cap, visor, headband, tricorn, bandana,
--                          beanie, backcap, bucket, crown, whirly, chef, viking

local root = app.params.root or "."
local out = app.params.out or (root .. "/art/sprites/bare")
local src = root .. "/art/sprites/src/player_frames_bare.txt"

local W, H = 32, 32
local SLOTS = { "idle0", "idle1", "run0", "run1", "run2", "run3",
                "windup", "swing", "follow", "toss", "cheer",
                "overhead_windup", "overhead_contact", "reach", "scoop" }
local HATS = { "cap", "visor", "headband", "tricorn", "bandana",
  "beanie", "backcap", "bucket", "crown", "whirly", "chef", "viking" }
local TEAMS = { "blue", "red", "green", "gold" }
local TEAM_PADDLE = { blue = "blue", red = "red", green = "wood", gold = "gold" }
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

local function c5(v)
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

local blocks = {}
do
  local cur
  for line in io.lines(src) do
    local name = line:match("^==%s*(%S+)")
    if name then
      cur = {}
      blocks[name] = cur
    elseif cur and not line:match("^#") and #line > 0 then
      cur[#cur + 1] = line
    end
  end
end

local function block(name, w, h)
  local rows = assert(blocks[name], "missing block " .. name)
  assert(#rows == h, name .. " has " .. #rows .. " rows")
  for i, r in ipairs(rows) do assert(#r == w, name .. " row " .. i .. " width") end
  return rows
end

local function paint(img, rows, ox, oy)
  for y, row in ipairs(rows) do
    for x = 1, #row do
      local idx = assert(KEY[row:sub(x, x)], "bad key")
      if idx ~= 0 then img:drawPixel(ox + x - 1, oy + y - 1, idx) end
    end
  end
end

local function newSprite(w, h, team)
  local s = Sprite(w, h, ColorMode.INDEXED)
  s.transparentColor = 0
  s:setPalette(buildPalette(team))
  return s
end

local function fill(s, frameNo, rows, w, h)
  local img = Image(w, h, ColorMode.INDEXED)
  img:clear(0)
  paint(img, rows, 0, 0)
  s:newCel(s.layers[1], frameNo, img, Point(0, 0))
end

-- Body source, tagged.
local spr = newSprite(W, H, "blue")
spr.layers[1].name = "body"
for i, name in ipairs(SLOTS) do
  if i > 1 then spr:newEmptyFrame() end
  fill(spr, i, block(name, W, H), W, H)
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
tag("overhead", 12, 13, 100)
tag("reach", 14, 14, 200)
tag("scoop", 15, 15, 200)
spr:saveAs(out .. "/player_bare.aseprite")
spr:close()

local pony = newSprite(8, 8, "blue")
fill(pony, 1, block("ponytail", 8, 8), 8, 8)
pony:saveAs(out .. "/ponytail_bare.aseprite")
pony:close()

local hats = newSprite(16, 8, "blue")
for i, name in ipairs(HATS) do
  if i > 1 then hats:newEmptyFrame() end
  fill(hats, i, block("hat_" .. name, 16, 8), 16, 8)
  local t = hats:newTag(i, i)
  t.name = name
end
hats:saveAs(out .. "/hats.aseprite")
hats:close()

for _, team in ipairs(TEAMS) do
  local sheet = newSprite(W * (#SLOTS + 1), H, team)
  local img = Image(sheet.width, H, ColorMode.INDEXED)
  img:clear(0)
  for i, name in ipairs(SLOTS) do paint(img, blocks[name], (i - 1) * W, 0) end
  paint(img, blocks.ponytail, #SLOTS * W, 0)
  sheet:newCel(sheet.layers[1], 1, img, Point(0, 0))
  sheet:saveCopyAs(out .. "/player_bare_" .. team .. ".png")
  sheet:close()

  local cap = newSprite(16, 8, team)
  fill(cap, 1, blocks.hat_cap, 16, 8)
  cap:saveCopyAs(out .. "/cap_" .. team .. ".png")
  cap:close()

  local hs = newSprite(16 * #HATS, 8, team)
  local himg = Image(hs.width, 8, ColorMode.INDEXED)
  himg:clear(0)
  for i, name in ipairs(HATS) do paint(himg, blocks["hat_" .. name], (i - 1) * 16, 0) end
  hs:newCel(hs.layers[1], 1, himg, Point(0, 0))
  hs:saveCopyAs(out .. "/hats_" .. team .. ".png")
  hs:close()
end
