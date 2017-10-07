
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
local screenCentre = {}
local fadeColor = {r=255, g=100, b=40, a=255}
local backgrounds = {}
local castingFonts = {}

local cat = {
  active=false,
  walkOffset = 0,
  health = 5,
  casting = 0, -- spell casting animation times
  zap = 0,     -- lightening zap animation time
  hurt = 0     -- pain timer
}

local levels = {
  {background=1, patternLength=1, count=3, waves=3, speed=15},
  {background=2, patternLength=3, count=5, waves=5, speed=10},
  {background=3, patternLength=3, count=7, waves=5, speed=5},
  {background=4, patternLength=6, count=10, waves=7, speed=5},
}
local currentLevel = 1
local currentWave = 1

local ghosts = {
  {x=20,  y=20,  hurt=0.0, speed=14, pat="^I"}, --  -I^V"},  -- speed is seconds from edge to centre
  {x=740, y=20,  hurt=0.0, speed=17, pat="-I"}, --  -IIVV"}, -- 'dead' get set when the ghost is defeated
  {x=20,  y=550, hurt=0.0, speed=17, pat="<"}, --  ^V^"},
  {x=740, y=550, hurt=0.0, speed=17, pat="Z"}, --  IVIV"}
}

function generatePattern(len)
  local s = "I-V^"
  local x = ""
  for i=1,len do
    local p = math.ceil(math.random(0, 4))
    x = x..(string.sub(s,p,p))
  end
  return x
end

function loadWave()
  ghosts = {}
  local lv = levels[currentLevel]
  for i=0,lv.count do
    table.insert(ghosts, {
      x = (math.cos(i)* screenCentre.x) + screenCentre.x,
      y = (math.sin(i)* screenCentre.y) + screenCentre.y,
      hurt = 0,
      speed = lv.speed,
      pat = generatePattern(lv.patternLength)
    })
  end
end

function love.load()
  px = 0
  py = 0
  globalTime = 0
  gs = 7

  screenWidth, screenHeight = love.graphics.getDimensions()
  screenScale = (screenWidth + screenHeight) / 200

  screenCentre.x = screenWidth/2
  screenCentre.y = screenHeight/2

  table.insert(backgrounds, love.graphics.newImage("assets/bg1.png"))

  textfont = love.graphics.newFont( 14 )
  ghostFont = love.graphics.newImageFont("assets/ghostfont.png", "<I-V^ZGgdHhCcKk")
  catFont = love.graphics.newImageFont("assets/catfont.png", "012345[]abcdefgXx")
  castingFonts["V"] = love.graphics.newImageFont("assets/Vfont.png", "012345")
  castingFonts["^"] = love.graphics.newImageFont("assets/Hatfont.png", "012345")
  castingFonts["Z"] = love.graphics.newImageFont("assets/Zfont.png", "012345")
  castingFonts["I"] = love.graphics.newImageFont("assets/Ifont.png", "012345")
  castingFonts["-"] = love.graphics.newImageFont("assets/-font.png", "012345")
  castingFonts["<"] = love.graphics.newImageFont("assets/heartfont.png", "012345")

  loadWave()
end

function love.keypressed(key)
  if key == 'escape' then love.event.quit() end
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
  if (p == "0246024") or (p == "135713") then return "<" end

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

function anyLightningGhost()
  for i=1,#ghosts do
    if (string.sub (ghosts[i].pat, 1, 1) == "Z") then return true end
  end
  return false
end

function attackGhosts(type)
  if (type == "Z") then -- if there is any match, all ghosts get frazzled
    if anyLightningGhost() then
      cat.casting = 1
      for i=1,#ghosts do
        local g = ghosts[i]
        g.pat = string.sub (g.pat, 2)
        g.hurt = 1 -- time of hurt left
        cat.zap = 1 -- time of zap left
      end
    end
  else
    for i=1,#ghosts do
      local g = ghosts[i]
      if (string.sub (g.pat, 1, 1) == type) then
        if (type == "<") then cat.health = math.min(5, cat.health+1) end
        cat.casting = 1
        g.pat = string.sub (g.pat, 2)
        g.hurt = 0.5 -- time of hurt left
      end
    end
  end
end

function biteCat(ghost)
  -- lose some health, send the ghost backward
  ghost.bite = ghost.speed / 4
  ghost.glyph = "c"
  if (cat.hurt < 0.04) then
    cat.health = math.max(0, cat.health - 1)
  end
  cat.hurt = 1
end

function moveGhosts(dt)
  local activeGhosts = 0
  local cx = screenWidth / 2
  local cy = screenHeight / 2
  local ss = screenScale / gs

  for i=1,#ghosts do
    local g = ghosts[i]
    if not g.bite then g.bite = 0 end
    if (g.pat == "" and g.hurt < 0.04 and cat.zap < 0.04) then
      g.dead = true
    end
    if not g.dead then
      activeGhosts = activeGhosts + 1
      g.hurt = math.max(0, g.hurt - dt)
      g.bite = math.max(0, g.bite - dt)
      if (g.glyph ~= "K") then g.glyph = "G" end
      if (g.pat == "<") then g.glyph = "K" end

      -- vector to centre
      local dx = cx - g.x
      local dy = cy - g.y
      local s = math.sqrt(dx*dx + dy*dy)
      if (s ~= 0) then dx = cx * (dx / s); dy = cy * (dy / s) end

      local dist = math.sqrt(math.pow(screenCentre.x - g.x, 2) + math.pow(screenCentre.y - g.y, 2))
      local f = 1; if (g.x < screenCentre.x) then f = -1 end


      if (g.hurt > 0) then -- ghosts back up slowly when hurt
        dx = -dx / 2; dy = -dy / 2
      elseif (g.bite > 0) then -- ghosts back up fast after a bite
        dx = -dx * 4; dy = -dy * 4
        g.glyph = "c"
      elseif (dist < 1) then
        biteCat(g)
        g.glyph = "c"
      elseif (dist < ss * 27) then
        g.glyph = "C"
      end

      if (g.pat == "<") and (dist < ss * 300) then -- heart ghosts never attack
        dx = -dx; dy = -dy
      end

      if (cat.zap < 0.04) then
        g.x = g.x + (dt * dx / g.speed)
        g.y = g.y + (dt * dy / g.speed)
      end
    end
  end
  if (activeGhosts < 1) then ghosts = {} end
end

function moveCat(dt)
  cat.zap = math.max(0, cat.zap - dt)
  cat.casting = math.max(0, cat.casting - dt)
  cat.hurt = math.max(0, cat.hurt - dt)

  if #ghosts < 1 then -- phase over / level over?
    cat.walkOffset = cat.walkOffset + dt*30*screenScale
    if (cat.walkOffset > screenCentre.x) then -- off screen, now transition
      cat.walkOffset = -(screenCentre.x)
      --TODO
    end
  end
end

function checkLevel()
  if #ghosts < 1 then -- end of wave
    currentWave = currentWave + 1
    if currentWave <= levels[currentLevel].waves then
      loadWave()
    end
  end
end

function love.update(dt)
  if dt > 0.7 then return end
  checkLevel()

  globalTime = globalTime + dt
  fadeColor.a = math.max(0, fadeColor.a * 0.9)

  moveGhosts(dt)
  moveCat(dt)
  if cat.hurt < 0.04 then
    readInputs()
  end
  love.graphics.setBackgroundColor( 40, 40, 70 )
end

function drawZap(x,y)
  local dx1 = (math.random() * 10) - 5
  local dx2 = (math.random() * 10) - 5
  local ss = screenScale * 2

  for i=0,y,ss do
    love.graphics.line(x + dx1, i - ss, x + dx2, i)
    dx1 = dx2
    dx2 = (math.random() * 10) - 5
  end
end

function drawGhosts()
  love.graphics.setFont(ghostFont)
  local ss = screenScale / gs
  local ds = 30 * ss

  for i=1,#ghosts do
    local g = ghosts[i]
    if not g.dead then
      local glyph = g.glyph;
      love.graphics.setColor(255, 255, 255, 255)
      if g.hurt > 0 then
        if (g.glyph == "K") then
          glyph = "k"
        elseif g.pat == "" then
          glyph = "d"
          love.graphics.setColor(255, 255, 255, 255 * g.hurt)
        else
          glyph = "g"
        end
      end
      local bob = math.sin(0.1 * g.x) * 4
      local f = 1
      local sy = 0
      if (g.x < screenCentre.x) then f = -1; sy = 2*ds end

      love.graphics.print(g.pat, g.x - sy, bob + g.y - 2*ds, 0, ss, ss)
      love.graphics.print(glyph, g.x, bob + g.y - ds, 0, ss*f, ss)
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

  if cat.zap > 0 then
    love.graphics.setColor(255, 255, 0, math.min(255, cat.zap * 255))

    for i=1,#ghosts do
      local g = ghosts[i]
      if not g.dead then
        drawZap(g.x,g.y)
      end
    end
  end
end

function drawCat()
  love.graphics.setColor(255, 255, 255, 255)
  local ds = 22 * screenScale / gs
  local ss = screenScale / gs
  local cx = screenCentre.x - ds*2
  local cy = screenCentre.y - ds

  -- Health
  love.graphics.setFont(ghostFont)
  for i=1,cat.health do
    love.graphics.print("H", ss*40*i, 10, 0, ss)
  end
  for i=cat.health+1,5 do
    love.graphics.print("h", ss*40*i, 10, 0, ss)
  end


  -- Cat
  love.graphics.setFont(catFont)

  if #ghosts < 1 then -- phase over / level over?
    local glyph = string.char(98 + math.floor((globalTime * 10) % 6))
    love.graphics.print(glyph, cat.walkOffset + cx,cy, 0, ss)
  elseif cat.active then
    local glyph = ""..math.floor((globalTime * 10) % 6)
    love.graphics.print(glyph, cx,cy, 0, ss)
  elseif cat.hurt > 0 then
    local glyph = "X"; if math.floor((globalTime * 10) % 2) > 0 then glyph = "x" end
    love.graphics.print(glyph, cx,cy, 0, ss)
  elseif cat.casting > 0 then
    local f = castingFonts[lastSpell]
    if (f ~= nil) then
      love.graphics.setFont(f)
      local glyph = ""..math.floor(6 - (cat.casting*6))
      love.graphics.print(glyph, cx - 10, cy - 70, 0, ss)
    end
  else
    local glyph = "["; if math.floor((globalTime * 0.4) % 2) > 0 then glyph = "]" end
    love.graphics.print(glyph, cx,cy, 0, ss)
  end
end

function love.draw()
  if cat.zap > 0 then
    love.graphics.setColor(127, 127, 127, 255)
  else
    love.graphics.setColor(255, 255, 255, 255)
  end
  local width, height = backgrounds[1]:getDimensions()
  love.graphics.draw( backgrounds[1], 0, 0, 0, screenWidth/width, screenHeight/height)

  drawCat()
  drawGhosts()
  drawMagic()
end
