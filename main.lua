
local points = {}
local fadePoints = {}
local symfont, textfont

-- 1  0  7
-- 2  *  6
-- 3  4  5
local directions = {} -- 0: N, 1: NW, 2:W, 3:SW, 4:S, 5:SE, 6:E, 7:NE -- 0: N, 1: NW, 2:W, 3:SW, 4:S, 5:SE, 6:E, 7:NE
local px, py
local lastDir = -1
local lastDecision = "..."
local screenScale, screenWidth, screenHeight
local fadeColor = {r=255, g=100, b=40, a=255}

local ghosts = { "I-I^V", "--IIVV", "V^V^", "VIVIV" }

function love.load()
  px = 0
  py = 0

  screenWidth, screenHeight = love.graphics.getDimensions()
  screenScale = (screenWidth + screenHeight) / 200

  textfont = love.graphics.newFont( 14 )
  symfont = love.graphics.newImageFont("assets/font.png", "<I-V^G")
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

function attackGhosts(type)
  for i=1,#ghosts do
    if (string.sub (ghosts[i], 1, 1) == type) then
      ghosts[i] = string.sub (ghosts[i], 2)
    end
  end
end

function love.update(dt)
  if dt > 0.7 then return end

  fadeColor.a = math.max(0, fadeColor.a * 0.9) -- (dt*255))

  if not love.mouse.isDown(1) then
    if #points > 0 then
      fadePoints = points
      points = {}
      lastDecision = decide(directions)
      attackGhosts(lastDecision)
      setFadeColor(lastDecision)
    end
    lastDir = -1
    return
  else
    if (#points == 0) then
      directions = {}
    end
  end

  local x,y = love.mouse.getPosition()
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


function love.draw()
  -- draw points

  love.graphics.setFont(textfont)
  love.graphics.setLineWidth( screenScale )
  love.graphics.setLineJoin( "none" )

  love.graphics.setColor(fadeColor.r, fadeColor.g, fadeColor.b, fadeColor.a)
  if #fadePoints > 3 then
    love.graphics.line(fadePoints)
  end

  love.graphics.setColor(255, 255, 127, 255)
  if #points > 3 then
    love.graphics.line(points)
  end

  love.graphics.setColor(255, 255, 255, 255)
  for i=1,#directions do
    love.graphics.print(directions[i], 10 + (i*8), 10)
  end
  love.graphics.print(lastDecision, 20, 40)


  love.graphics.setFont(symfont)
  love.graphics.setColor(255, 255, 255, 255)
  for i=1,#ghosts do
    love.graphics.print(ghosts[i], screenWidth - 170, (i-1) * 140)
    love.graphics.print("G", screenWidth - 170, 40 + (i-1) * 140)
  end
end
