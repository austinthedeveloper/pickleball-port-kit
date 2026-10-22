-- v2 test build: the HD players from v2/src/frames.json (rig_v2.py) +
-- ../src/palettes.json, written next to this folder with a _v2 suffix.
--
-- aseprite -b --script-param root=<kit root> [--script-param out=<dir>]
--          --script art/sprites/hd/v2/src/build_hd_v2.lua
--
-- Writes <out>/player_hd_<variant>_v2.aseprite (blue palette, tagged) and
-- <out>/player_hd_<variant>_v2_<team>.png sheets (frames left to right in
-- slot order) for every team.

local root = app.params.root or "."
local src = root .. "/art/sprites/hd/v2/src/"
local palsDir = root .. "/art/sprites/hd/src/"
local out = app.params.out or (root .. "/art/sprites/hd/v2")

local function readJson(path)
  local f = assert(io.open(path, "r"), path)
  local t = json.decode(f:read("a"))
  f:close()
  return t
end

local data = readJson(src .. "frames.json")
local pals = readJson(palsDir .. "palettes.json")
local W, H = data.size[1], data.size[2]
local ROLES = data.roles
local TEAMS = { "blue", "red", "green", "gold" }

local KEY = {}
for i = 1, #ROLES do KEY[ROLES:sub(i, i)] = i - 1 end

local function buildPalette(team, skin, hair)
  local roleColor = {}
  for k, v in pairs(pals.base) do roleColor[k] = v end
  for k, v in pairs(pals.teams[team]) do roleColor[k] = v end
  for k, v in pairs(pals.paddles[team]) do roleColor[k] = v end
  for k, v in pairs(pals.skins[skin or "light"]) do roleColor[k] = v end
  for k, v in pairs(pals.hairs[hair or "brown"]) do roleColor[k] = v end
  roleColor.k = pals.teams[team].M
  roleColor.K = pals.teams[team].d
  local pal = Palette(#ROLES)
  pal:setColor(0, Color { r = 0, g = 0, b = 0, a = 0 })
  for i = 2, #ROLES do
    local ch = ROLES:sub(i, i)
    local c = assert(roleColor[ch], "no colour for role " .. ch)
    pal:setColor(i - 1, Color { r = c[1], g = c[2], b = c[3] })
  end
  return pal
end

local function paint(img, rows, ox, oy)
  for y, row in ipairs(rows) do
    for x = 1, #row do
      local idx = KEY[row:sub(x, x)]
      assert(idx, "unknown key " .. row:sub(x, x))
      if idx ~= 0 then img:drawPixel(ox + x - 1, oy + y - 1, idx) end
    end
  end
end

local TAGS = {
  { "idle", "idle0", "idle1", 300 }, { "run", "run0", "run3", 90 },
  { "swing", "windup", "follow", 70 }, { "toss", "toss", "toss", 200 },
  { "cheer", "cheer", "cheer", 200 },
}

for _, variant in ipairs { "male", "female" } do
  local slots = data.slots
  local index = {}
  for i, s in ipairs(slots) do index[s] = i end

  local spr = Sprite(W, H, ColorMode.INDEXED)
  spr.transparentColor = 0
  spr:setPalette(buildPalette("blue"))
  local layer = spr.layers[1]
  layer.name = "body"
  for i, name in ipairs(slots) do
    if i > 1 then spr:newEmptyFrame() end
    local img = Image(W, H, ColorMode.INDEXED)
    img:clear(0)
    paint(img, data.frames[name][variant], 0, 0)
    spr:newCel(layer, i, img, Point(0, 0))
    spr.frames[i].duration = 0.1
  end
  for _, t in ipairs(TAGS) do
    local a, b = index[t[2]], index[t[3]]
    if a and b then
      local tag = spr:newTag(a, b)
      tag.name = t[1]
      for f = a, b do spr.frames[f].duration = t[4] / 1000 end
    end
  end
  spr:saveAs(out .. "/player_hd_" .. variant .. "_v2.aseprite")
  spr:close()

  for _, team in ipairs(TEAMS) do
    local sheet = Sprite(W * #slots, H, ColorMode.INDEXED)
    sheet.transparentColor = 0
    sheet:setPalette(buildPalette(team))
    local img = Image(sheet.width, H, ColorMode.INDEXED)
    img:clear(0)
    for i, name in ipairs(slots) do
      paint(img, data.frames[name][variant], (i - 1) * W, 0)
    end
    sheet:newCel(sheet.layers[1], 1, img, Point(0, 0))
    sheet:saveCopyAs(out .. "/player_hd_" .. variant .. "_v2_" .. team .. ".png")
    sheet:close()
  end
end
