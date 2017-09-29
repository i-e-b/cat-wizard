
local points = {}
local fadePoints = {}
local ghostFont, textfont, catfont

-- 1  0  7
-- 2  *  6
-- 3  4  5
local directions = {} -- 0: N, 1: NW, 2:W, 3:SW, 4:S, 5:SE, 6:E, 7:NE -- 0: N, 1: NW, 2:W, 3:SW, 4:S, 5:SE, 6:E, 7:NE
local px, py, globalTime
local lastDir = -1
local lastSpell = "..."
local screenScale, screenWidth, screenHeight, gs
local fadeColor = {r=255, g=100, b=40, a=255}
local backgrounds = {}

local cat = {
  active=false,
  walkOffset = 0
}

local ghosts = {
  {x=20,  y=20,  hurt=0.0, speed=14, pat="I"}, --  -I^V"},  -- speed is seconds from edge to centre
  {x=740, y=20,  hurt=0.0, speed=17, pat="-"}, --  -IIVV"}, -- 'dead' get set when the ghost is defeated
  {x=20,  y=550, hurt=0.0, speed=17, pat="V"}, --  ^V^"},
  {x=740, y=550, hurt=0.0, speed=17, pat="Z"}, --  IVIV"}
}

function love.load()
  px = 0
  py = 0
  globalTime = 0
  gs = 7

  screenWidth, screenHeight = love.graphics.getDimensions()
  screenScale = (screenWidth + screenHeight) / 200

  table.insert(backgrounds, love.graphics.newImage("assets/bg1.png"))

  textfont = love.graphics.newFont( 14 )
  ghostFont = love.graphics.newImageFont("assets/ghostfont.png", "<I-V^ZGgd")
  catFont = love.graphics.newImageFont("assets/catfont.png", "012345[]abcdefg")
end

function vecMoreThanTwo(newDir, oldDir)
  if (newDir < 0) then return false end
  if (oldDir < 0) then return true end
  local dd = math.abs(newDir - oldDir)
  return ((dd < 7) and (dd > 1))
end

function vec2compass(dx, dy)
  if dx == 0 then
    if dy == 0 then return -1 end
    if dy < 0 then return 0 end
    if dy > 0 then return 4 end
  end
  if dy == 0 then
    if dx == 0 then return -1 end
    if dx < 0 then return 2 end
    if dx > 0 then return 6 end
  end

  local slope = dy / dx
  -- 0: N, 1: NW, 2:W, 3:SW, 4:S, 5:SE, 6:E, 7:NE
  if dx > 0 and dy < 0 then -- up right quadrant
    if slope > -0.5 then return 6 end
    if slope < -2.5 then return 0 end
    return 7
  elseif dx > 0 and dy > 0 then --down right quadrant
    if slope > 2.5 then return 4 end
    if slope < 0.5 then return 6 end
    return 5
  elseif dx < 0 and dy < 0 then  -- up left quadrant
    if slope < 0.5 then return 2 end
    if slope > 2.5 then return 0 end
    return 1
  elseif dx < 0 and dy > 0 then -- down left quadrant
    if slope < -2.5 then return 4 end
    if slope > -0.5 then return 2 end
    return 3
  end
end

-- decide on the shape of a swipe
function decide(ds)
  local p = table.concat(ds,"")

  -- V patterns
  if (p == "50") or (p == "57") or (p == "47") or (p == "40") or (p == "41") then return "V" end
  if (p == "31") or (p == "30") then return "V" end

  -- I patterns
  if (p == "4") or (p == "0") then return "I" end

  -- - patterns
  if (p == "6") or (p == "2") then return "-" end

  -- ^ patterns
  if (p == "04") or (p == "05") or (p == "03") or (p == "74") or (p == "75") then return "^" end
  if (p == "14") or (p == "13") then return "^" end

  -- Z patterns
  if (p == "363") or (p == "364") or (p == "463") or (p == "464") or (p == "353") then return "Z" end

  -- <3 pattens
  if (p == "0246024") or (p == "135713") then return "<3" end

  return "?"
end

function setFadeColor(type)
  if     type == "?" then fadeColor = {r=255, g=0, b=0, a=255}
  elseif type == "V" then fadeColor = {r=255, g=0, b=255, a=255}
  elseif type == "^" then fadeColor = {r=0, g=255, b=255, a=255}
  elseif type == "-" then fadeColor = {r=0, g=0, b=255, a=255}
  elseif type == "I" then fadeColor = {r=0, g=255, b=0, a=255}
  elseif type == "Z" then fadeColor = {r=255, g=255, b=0, a=255}
  elseif type == "<3" then fadeColor = {r=255, g=127, b=127, a=255}
  else fadeColor = {r=127, g=127, b=127, a=127}
  end
end

function handleInput(pressed, x, y)
  cat.active = pressed
  if not pressed then
    if #points > 0 then -- user just finished drawing a shape
      fadePoints = points
      points = {}
      lastSpell = decide(directions) -- figure out the shape
      attackGhosts(lastSpell)        -- remove matching initial symbol from all ghosts
      setFadeColor(lastSpell)        -- set color based on shape, for fade effect
    end
    lastDir = -1
    return
  else
    if (#points == 0) then
      directions = {}
    end
  end

  if ( math.abs(px - x) + math.abs(py - y) > screenScale * 4 ) then
    table.insert(points, x)
    table.insert(points, y)

    if (#points > 2) then
      local dx = x - px
      local dy = y - py
      local dir = vec2compass(dx,dy)
      if vecMoreThanTwo(dir, lastDir) then
        table.insert(directions, dir)
        lastDir = dir
      end
    end
    px = x
    py = y
  end
end

function readInputs()
  local x,y

  if love.mouse.isDown(1) then
    x,y = love.mouse.getPosition()
    handleInput(true, x, y)
    return
  end

  local touches = love.touch.getTouches()
  if (#touches > 0) then -- pick any touch and go with than
    for i, id in ipairs(touches) do x,y = love.touch.getPosition(id) end
    handleInput(pressed, x, y)
    return
  end

  handleInput(false, 0, 0)
end

function attackGhosts(type)
  for i=1,#ghosts do
    local g = ghosts[i]
    if (string.sub (g.pat, 1, 1) == type) then
      g.pat = string.sub (g.pat, 2)
      g.hurt = 0.5 -- time of hurt left
    end
  end
end

function moveGhosts(dt)
  local activeGhosts = 0
  local cx = screenWidth / 2
  local cy = screenHeight / 2
  for i=1,#ghosts do
    local g = ghosts[i]
    if (g.pat == "" and g.hurt < 0.04) then
      g.dead = true
    end
    if not g.dead then
      activeGhosts = activeGhosts + 1
      g.hurt = math.max(0, g.hurt - dt)

      -- vector to centre
      local dx = cx - g.x
      local dy = cy - g.y
      local s = math.sqrt(dx*dx + dy*dy)
      if (s ~= 0) then dx = cx * (dx / s); dy = cy * (dy / s) end

      -- ghosts back up slowly when hurt
      if (g.hurt > 0) then dx = -dx / 2; dy = -dy / 2 end

      g.x = g.x + (dt * dx / g.speed)
      g.y = g.y + (dt * dy / g.speed)
    end
  end
  if (activeGhosts < 1) then ghosts = {} end
end

function moveCat(dt)
    if #ghosts < 1 then -- phase over / level over?
      cat.walkOffset = cat.walkOffset + dt*30*screenScale
      if (cat.walkOffset > (screenWidth / 2)) then -- off screen, now transition
        cat.walkOffset = -(screenWidth / 2)
        --TODO
      end
    end
end

function love.update(dt)
  if dt > 0.7 then return end

  globalTime = globalTime + dt
  fadeColor.a = math.max(0, fadeColor.a * 0.9)

  moveGhosts(dt)
  moveCat(dt)
  readInputs()
  love.graphics.setBackgroundColor( 40, 40, 70 )
end

function drawGhosts()
  love.graphics.setFont(ghostFont)
  local ss = screenScale / gs
  local ds = 22 * ss

  for i=1,#ghosts do
    local g = ghosts[i]
    if not g.dead then
      local glyph = "G";
      love.graphics.setColor(255, 255, 255, 255)
      if g.hurt > 0 then
        if g.pat == "" then
          glyph = "d"
          love.graphics.setColor(255, 255, 255, 255 * g.hurt)
        else
          glyph = "g"
        end
      end
      local bob = math.sin(0.1 * g.x) * 4
      love.graphics.print(g.pat, g.x - ds, bob + g.y - 2*ds, 0, ss)
      love.graphics.print(glyph, g.x - ds, bob + g.y - ds, 0, ss)
    end
  end
end

function drawMagic()
  love.graphics.setLineWidth( screenScale )
  love.graphics.setLineJoin( "none" )

  love.graphics.setColor(fadeColor.r, fadeColor.g, fadeColor.b, fadeColor.a)
  if #fadePoints > 3 then
    love.graphics.line(fadePoints)
  end

  love.graphics.setColor(255, 255, 255, 127)
  if #points > 3 then
    love.graphics.line(points)
  end
end

function drawCat()
  love.graphics.setFont(catFont)
  love.graphics.setColor(255, 255, 255, 255)
  local ds = 22 * screenScale / gs
  local cx = screenWidth/2 - ds
  local cy = screenHeight/2 - ds

  if #ghosts < 1 then -- phase over / level over?
    local glyph = string.char(98 + math.floor((globalTime * 10) % 6))
    love.graphics.print(glyph, cat.walkOffset + cx,cy, 0, screenScale / gs)
  elseif cat.active then
    local glyph = ""..math.floor((globalTime * 10) % 6)
    love.graphics.print(glyph, cx,cy, 0, screenScale / gs)
  else
    local glyph = "["; if math.floor((globalTime * 0.4) % 2) > 0 then glyph = "]" end
    love.graphics.print(glyph, cx,cy, 0, screenScale / gs)
  end
end

function love.draw()
  local width, height = backgrounds[1]:getDimensions()

  love.graphics.draw( backgrounds[1], 0, 0, 0, screenWidth/width, screenHeight/height)

  drawCat()
  drawGhosts()
  drawMagic()
end
