-- Builds the practice ball machine from the layer PNGs machine.py draws.
--
-- aseprite -b --script-param root=<kit root> --script art/sprites/machine/src/build_machine.lua
--
-- Writes art/sprites/machine/machine.aseprite (layers body, arm, hub; one
-- frame per arm angle, tagged "swing") and out/machine.png, the game's sheet:
-- cell 0 the body, cells 1..ANGLES the arm (up the screen first), the last
-- cell the hub. The game draws body, arm, hub, so the arm swings alone.

local root = app.params.root or "."
local dir = root .. "/art/sprites/machine"
local layers = dir .. "/src/layers/"
local W, H = 36, 26
local ANGLES = 9

local spr = Sprite(W, H, ColorMode.RGB)
spr.filename = dir .. "/machine.aseprite"
local body = spr.layers[1]
body.name = "body"
local arm = spr:newLayer()
arm.name = "arm"
local hub = spr:newLayer()
hub.name = "hub"

local bodyImg = Image { fromFile = layers .. "body.png" }
local hubImg = Image { fromFile = layers .. "hub.png" }
for i = 1, ANGLES do
  if i > 1 then spr:newEmptyFrame() end
  spr:newCel(body, i, bodyImg, Point(0, 0))
  spr:newCel(arm, i, Image { fromFile = layers .. "arm_" .. (i - 1) .. ".png" }, Point(0, 0))
  spr:newCel(hub, i, hubImg, Point(0, 0))
  spr.frames[i].duration = 0.05
end
local tag = spr:newTag(1, ANGLES)
tag.name = "swing"
tag.aniDir = AniDir.PING_PONG
spr:saveAs(dir .. "/machine.aseprite")

-- the game's sheet, from the saved layers
local sheet = Image(W * (ANGLES + 2), H, ColorMode.RGB)
sheet:drawImage(spr.layers[1]:cel(1).image, spr.layers[1]:cel(1).position)
for i = 1, ANGLES do
  local cel = spr.layers[2]:cel(i)
  sheet:drawImage(cel.image, Point(W * i + cel.position.x, cel.position.y))
end
local hc = spr.layers[3]:cel(1)
sheet:drawImage(hc.image, Point(W * (ANGLES + 1) + hc.position.x, hc.position.y))
os.execute('mkdir -p "' .. dir .. '/out"')
sheet:saveAs(dir .. "/out/machine.png")
