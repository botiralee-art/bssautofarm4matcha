--[[
	bee farm v11.5 — wabi sabi ui edition
	fixed tween · walk+tween mode · edge corridors
]]

-- ═══════════════════════════════════════════════════════════
--  LOAD WABI SABI
-- ═══════════════════════════════════════════════════════════
loadstring(game:HttpGet("https://scripts.wabisabi.mom/wabi-sabi-ui-lib.lua"))()
local Library = WabiSabi

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local lp = Players.LocalPlayer

local myHive = nil
local forceReturn = false
local status = "off"
local collecting = false
local moving = false
local bpText = "?"
local currentField = nil
local needSprinkler = false
local sprinklerNotified = false
local autoDetecting = false

local pollenValue = nil
local capLabel = nil
local capValue = nil
local manualCap = nil
local lastCapTry = 0
local rayOK = nil

local statusPar = nil
local hivePar = nil
local statusText = ""

local KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_ONE = 0x57, 0x41, 0x53, 0x44, 0x20, 0x31
local KEY_E, KEY_ESC, KEY_R, KEY_ENTER = 0x45, 0x1B, 0x52, 0x0D
local held = {}

-- ═══════════════════════════════════════════════════════════
--  SETTINGS
-- ═══════════════════════════════════════════════════════════
local S = {
	farm_on     = false,
	field       = "Dandelion Field",
	farm_mode   = "Whole Field",
	close_r     = 12,
	full_pct    = 90,
	move_type   = "Walk + Tween",   -- "Tween", "Walk", "Walk + Tween"
	-- tween
	glide_speed = 200,
	-- walk
	walk_type   = "Custom Speed",
	walk_speed  = 150,
	-- utility
	sprinkler   = "Off",
	find_path   = false,
	token_los   = false,
	dig_click   = false,
	face_center = false,
	reset_mode  = false,
}

local MODE_INDEX = { ["Middle Only"] = 0, ["Close Middle"] = 1, ["Whole Field"] = 2 }
local SPRINK_REPS = { ["Off"] = 0, ["Basic"] = 1, ["Silver"] = 2, ["Gold"] = 3, ["Diamond"] = 4, ["Supreme"] = 1 }
pcall(function() math.randomseed(math.floor(tick())) end)

local function toast(msg)
	pcall(function() Library:Notify({ Title = "bee farm", Content = tostring(msg), Duration = 4 }) end)
end

-- ═══════════════════════════════════════════════════════════
--  CORE HELPERS
-- ═══════════════════════════════════════════════════════════
local function isOn() return S.farm_on == true and not autoDetecting end
local function getHRP()
	local c = lp.Character; return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
	local c = lp.Character; return c and c:FindFirstChildOfClass("Humanoid")
end

-- ═══════════════════════════════════════════════════════════
--  POLLEN / CAPACITY (unchanged)
-- ═══════════════════════════════════════════════════════════
local function parseNum(s)
	if not s then return nil end
	s = s:gsub(",", ""):gsub("%s+", "")
	local mults = { K = 1e3, M = 1e6, B = 1e9, T = 1e12 }
	local suf = s:match("([KkMmBbTt])$")
	local mult = 1
	if suf then mult = mults[suf:upper()] or 1; s = s:sub(1, #s - 1) end
	local n = tonumber(s); return n and (n * mult) or nil
end
local function parseCapText(t)
	if type(t) ~= "string" then return nil, nil end
	local a, b = t:match("([%d,]+%s*[KkMmBbTt]?)%s*/%s*([%d,]+%s*[KkMmBbTt]?)")
	if a and b then return parseNum(a), parseNum(b) end; return nil, nil
end
local function readCapLabel()
	if capLabel and capLabel.Parent then
		local ok, t = pcall(function() return capLabel.Text end)
		if ok then local cur, cap = parseCapText(t); if cap then return cur, cap end end
		capLabel = nil
	end; return nil, nil
end
local function findCapLabel()
	local pg = lp:FindFirstChildOfClass("PlayerGui"); if not pg then return nil end
	local okd, desc = pcall(function() return pg:GetDescendants() end)
	if not okd or not desc then return nil end
	for i, o in ipairs(desc) do
		if i % 30 == 0 then wait() end
		local oki, isT = pcall(function() return o:IsA("TextLabel") end)
		if oki and isT then
			local okt, t = pcall(function() return o.Text end)
			if okt then local cur, cap = parseCapText(t); if cur and cap and cap >= 1000 then return o end end
		end
	end; return nil
end
local function detectCap()
	local attrNames = { "PollenCapacity", "BackpackCapacity", "Capacity", "MaxPollen", "PollenMax", "BackpackSpace", "Space" }
	local targets = { lp, lp:FindFirstChild("CoreStats"), lp:FindFirstChild("leaderstats") }
	for _, t in ipairs(targets) do if t then for _, n in ipairs(attrNames) do
		local ok, v = pcall(function() return t:GetAttribute(n) end)
		if ok and type(v) == "number" and v > 0 then return { _attr = n, _t = t } end
	end end end
	local ok, desc = pcall(function() return lp:GetDescendants() end)
	if ok and desc then for _, v in ipairs(desc) do local n = v.Name:lower()
		if n:find("capac") or n:find("space") or n:find("maxpollen") or n:find("pollenmax") or n:find("backpack") then
			local ok2, val = pcall(function() return v.Value end)
			if ok2 and type(val) == "number" and val > 0 then return v end
		end
	end end; return nil
end
local function getCap()
	if manualCap then return manualCap end
	local _, capGui = readCapLabel(); if capGui then return capGui end
	if capValue then
		if capValue._attr then local ok, v = pcall(function() return capValue._t:GetAttribute(capValue._attr) end)
			if ok and type(v) == "number" and v > 0 then return v end; capValue = nil
		elseif capValue.Parent then return capValue.Value else capValue = nil end
	end
	if tick() - lastCapTry > 3 then lastCapTry = tick(); capLabel = findCapLabel()
		if capLabel then local _, c2 = readCapLabel(); if c2 then return c2 end end
		capValue = detectCap()
	end
	if capValue then return getCap() end; return nil
end
local function getPollen()
	if pollenValue and pollenValue.Parent then return pollenValue.Value end
	local core = lp:FindFirstChild("CoreStats")
	if core then pollenValue = core:FindFirstChild("Pollen") end
	if pollenValue then return pollenValue.Value end; return (readCapLabel())
end

-- ═══════════════════════════════════════════════════════════
--  HIVE TEXT DETECTION
-- ═══════════════════════════════════════════════════════════
local function findHiveText()
	local pg = lp:FindFirstChildOfClass("PlayerGui"); if not pg then return nil end
	local okd, desc = pcall(function() return pg:GetDescendants() end)
	if not okd or not desc then return nil end
	for i, o in ipairs(desc) do
		if i % 40 == 0 then wait() end
		local oki, isT = pcall(function() return o:IsA("TextLabel") end)
		if oki and isT then
			local okt, t = pcall(function() return o.Text end)
			if okt and type(t) == "string" and #t > 5 then
				local low = t:lower()
				if low:find("stop making honey") then return "converting"
				elseif low:find("to make honey") then return "empty"
				elseif low:find("make honey") then return "ready"
				elseif low:find("send trade request") then return "trade" end
			end
		end
	end; return nil
end

-- ═══════════════════════════════════════════════════════════
--  FIELD HELPERS
-- ═══════════════════════════════════════════════════════════
local function getField(name)
	local z = Workspace:FindFirstChild("FlowerZones"); return z and z:FindFirstChild(name)
end
local function groundY(f) return f.Position.Y + f.Size.Y / 2 end
local function inField(pos, f, m)
	local c, s = f.Position, f.Size
	return math.abs(pos.X - c.X) <= s.X/2+m and math.abs(pos.Z - c.Z) <= s.Z/2+m and math.abs(pos.Y - c.Y) <= 25
end
local function distToCenter(pos, f)
	local c = f.Position; return Vector3.new(pos.X - c.X, 0, pos.Z - c.Z).Magnitude
end
local function clampTarget(tgt, f, fm, cr)
	if fm == 1 then local c = f.Position; local d = Vector3.new(tgt.X - c.X, 0, tgt.Z - c.Z)
		if d.Magnitude > cr then local dir = d.Unit; return Vector3.new(c.X+dir.X*cr, tgt.Y, c.Z+dir.Z*cr) end
	end; return tgt
end
local function randomPoint(f, r)
	local c, s = f.Position, f.Size
	local rx = math.min(r or (s.X/2-4), s.X/2-4); local rz = math.min(r or (s.Z/2-4), s.Z/2-4)
	local ang = math.random()*math.pi*2; local rad = math.random()
	return Vector3.new(c.X+math.cos(ang)*rad*rx, groundY(f)+2, c.Z+math.sin(ang)*rad*rz)
end
local function stopWalk()
	local h = getHRP(); if h then pcall(function() h.AssemblyLinearVelocity = Vector3.new(0,0,0) end) end
end
local function setStatus()
	local t = "state: "..status.."\npollen: "..bpText
	if t ~= statusText then statusText = t
		if statusPar then pcall(function() statusPar:SetContent(t) end) end
	end
end

-- ═══════════════════════════════════════════════════════════
--  RAYCAST
-- ═══════════════════════════════════════════════════════════
local function losClear(a, b)
	if rayOK == false then return true end
	local ok, res = pcall(function() return Workspace:Raycast(a, b - a) end)
	if not ok then rayOK = false; return true end; rayOK = true
	if res and res.Instance then
		local inst = res.Instance
		local char = lp.Character
		if char and inst:IsDescendantOf(char) then return true end
		local zones = Workspace:FindFirstChild("FlowerZones")
		if zones and inst:IsDescendantOf(zones) then return true end
		local coll = Workspace:FindFirstChild("Collectibles")
		if coll and inst:IsDescendantOf(coll) then return true end
		local okc, cc = pcall(function() return inst.CanCollide end)
		if okc and cc == false then return true end
		if (res.Position - a).Magnitude > 15 then return true end
		return false
	end; return true
end

-- ═══════════════════════════════════════════════════════════
--  INPUT
-- ═══════════════════════════════════════════════════════════
local function setKey(k, down)
	if held[k] == down then return end; held[k] = down
	pcall(function() if down then keypress(k) else keyrelease(k) end end)
end
local function releaseMoveKeys()
	setKey(KEY_W, false); setKey(KEY_A, false); setKey(KEY_S, false); setKey(KEY_D, false)
end
local function pressE()
	pcall(function() keypress(KEY_E) end); wait(0.15); pcall(function() keyrelease(KEY_E) end)
end
local camYawT, camYawVal, camYawOK = 0, 0, false
local function camYaw()
	if tick() - camYawT > 0.25 then camYawT = tick()
		local ok, cf = pcall(function() return Workspace.CurrentCamera.CFrame end)
		if ok and cf then local lv = cf.LookVector; camYawVal = math.atan2(-lv.X, -lv.Z); camYawOK = true
		else camYawOK = false end
	end; return camYawVal, camYawOK
end
local function steer(dir)
	local yaw, ok = camYaw(); if not ok then return false end
	local fx, fz = -math.sin(yaw), -math.cos(yaw)
	local rx, rz = math.cos(yaw), -math.sin(yaw)
	local f = dir.X*fx + dir.Z*fz; local r = dir.X*rx + dir.Z*rz
	setKey(KEY_W, f > 0.3); setKey(KEY_S, f < -0.3)
	setKey(KEY_D, r > 0.3); setKey(KEY_A, r < -0.3)
	return true
end

-- ═══════════════════════════════════════════════════════════
--  MOVER — 2 internal modes: TWEEN or WALK
--
--  TWEEN: hold W key + write hrp.Position each frame
--         W keeps character "activated" so writes take effect
--
--  WALK: WASD steering + optional velocity override
--        escalating stuck-jump, find-path wall-jump
-- ═══════════════════════════════════════════════════════════
local function moveTo(target, thr, skipOnCheck, forceTween)
	moving = true
	thr = thr or 2

	-- decide: tween or walk?
	local useTween
	if forceTween ~= nil then
		useTween = forceTween
	elseif S.move_type == "Tween" then
		useTween = true
	elseif S.move_type == "Walk" then
		useTween = false
	else -- "Walk + Tween"
		useTween = false  -- default to walk for in-field movement
	end

	-- walk setup
	if not useTween then
		if S.walk_type == "Custom Speed" then
			local hum = getHum()
			if hum then pcall(function() hum.WalkSpeed = S.walk_speed or 150 end) end
		end
		local h0 = getHRP()
		if h0 then
			local d0 = Vector3.new(target.X - h0.Position.X, 0, target.Z - h0.Position.Z)
			if d0.Magnitude > 1 then steer(d0.Unit); wait(0.06) end
		end
	end

	local start = tick()
	local lastT = start
	local lastPos = nil
	local lastMoveT = start
	local lastWallJump = 0
	local stuckCount = 0

	while tick() - start < 120 do
		if not skipOnCheck and not isOn() then
			releaseMoveKeys(); stopWalk(); moving = false; return false
		end
		local hrp = getHRP()
		if not hrp then releaseMoveKeys(); wait(0.15); moving = false; return false end

		local now = tick()
		local dt = math.min(math.max(now - lastT, 0.001), 0.25)
		lastT = now
		local pos = hrp.Position
		local delta = target - pos
		local flat = Vector3.new(delta.X, 0, delta.Z)

		-- arrived?
		if flat.Magnitude <= thr and math.abs(delta.Y) <= 5 then
			releaseMoveKeys(); stopWalk(); moving = false; return true
		end

		local dirFlat = (flat.Magnitude > 0.01) and flat.Unit or Vector3.new(0, 0, 1)

		if useTween then
			-- ══════════════════════════════════════════
			--  TWEEN: hold W + write Position
			--  W key keeps character activated so Position writes work
			-- ══════════════════════════════════════════
			setKey(KEY_W, true)

			local speed = S.glide_speed or 200
			local step = math.min(speed * dt, 15, delta.Magnitude)
			pcall(function() hrp.Position = pos + delta.Unit * step end)
			wait(0.02)
		else
			-- ══════════════════════════════════════════
			--  WALK: WASD steering + stuck detection
			-- ══════════════════════════════════════════
			steer(dirFlat)

			-- movement check: did we actually move?
			if lastPos then
				if (pos - lastPos).Magnitude >= 1.5 then
					stuckCount = 0; lastMoveT = now
				end
			else lastMoveT = now end

			-- FIND PATH: wall jump with escalating power
			if S.find_path and (now - lastWallJump) > 2 then
				local eyeA = pos + Vector3.new(0, 2, 0)
				local eyeB = pos + dirFlat * 8 + Vector3.new(0, 2, 0)
				if not losClear(eyeA, eyeB) then
					local jumpPower = 50 + stuckCount * 20
					if jumpPower > 200 then jumpPower = 200 end
					stuckCount = stuckCount + 1; lastWallJump = now
					pcall(function()
						local cv = hrp.AssemblyLinearVelocity
						hrp.AssemblyLinearVelocity = Vector3.new(cv.X, jumpPower, cv.Z)
					end)
					setKey(KEY_SPACE, true); wait(0.2); setKey(KEY_SPACE, false); wait(0.6)
				end
			end

			-- jump if target above
			if target.Y > pos.Y + 3 and flat.Magnitude < 10 and (now - lastWallJump) > 2 then
				local jp = 50 + stuckCount * 15; if jp > 150 then jp = 150 end
				pcall(function() local cv = hrp.AssemblyLinearVelocity
					hrp.AssemblyLinearVelocity = Vector3.new(cv.X, jp, cv.Z) end)
				setKey(KEY_SPACE, true); wait(0.08); setKey(KEY_SPACE, false); lastWallJump = now
			end

			-- STUCK: escalating jump
			if (now - lastWallJump) > 2 and now - lastMoveT > 2 then
				local jp = 50 + stuckCount * 20; if jp > 200 then jp = 200 end
				stuckCount = stuckCount + 1
				pcall(function() local cv = hrp.AssemblyLinearVelocity
					hrp.AssemblyLinearVelocity = Vector3.new(cv.X, jp, cv.Z) end)
				setKey(KEY_SPACE, true); wait(0.15); setKey(KEY_SPACE, false)
				lastMoveT = now; lastWallJump = now
			end

			lastPos = pos

			-- custom speed velocity override
			if S.walk_type == "Custom Speed" then
				local sp = S.walk_speed or 150
				pcall(function() local cv = hrp.AssemblyLinearVelocity
					hrp.AssemblyLinearVelocity = Vector3.new(dirFlat.X * sp, cv.Y, dirFlat.Z * sp) end)
			end
			wait(0.04)
		end
	end
	releaseMoveKeys(); stopWalk(); moving = false; return true
end

-- face center
local function faceCenter(field)
	local hrp = getHRP(); if not hrp then wait(0.1); return end
	local c = field.Position; local pos = hrp.Position
	local d = Vector3.new(c.X - pos.X, 0, c.Z - pos.Z)
	if d.Magnitude < 2 then wait(0.1); return end; d = d.Unit
	local yaw, ok = camYaw(); if not ok then wait(0.1); return end
	local fx, fz = -math.sin(yaw), -math.cos(yaw)
	local rx, rz = math.cos(yaw), -math.sin(yaw)
	local function press(dir)
		local f = dir.X*fx + dir.Z*fz; local r = dir.X*rx + dir.Z*rz
		setKey(KEY_W, f > 0.3); setKey(KEY_S, f < -0.3)
		setKey(KEY_D, r > 0.3); setKey(KEY_A, r < -0.3)
	end
	press(-d); wait(0.08); press(d); wait(0.15); releaseMoveKeys()
	pcall(function() hrp.Position = pos end); wait(0.05)
end

-- ═══════════════════════════════════════════════════════════
--  PATHFINDING — edge-to-edge corridor navigation
--  only used in Walk mode; Tween and Walk+Tween go direct
-- ═══════════════════════════════════════════════════════════
local FIELD_ADJ = {
	HIVE                   = {"Dandelion Field", "Sunflower Field"},
	["Dandelion Field"]    = {"HIVE", "Sunflower Field", "Mushroom Field"},
	["Sunflower Field"]    = {"HIVE", "Dandelion Field", "Mushroom Field", "Blue Flower Field"},
	["Mushroom Field"]     = {"Dandelion Field", "Sunflower Field", "Blue Flower Field", "Spider Field"},
	["Blue Flower Field"]  = {"Sunflower Field", "Mushroom Field", "Clover Field", "Strawberry Field"},
	["Clover Field"]       = {"Blue Flower Field", "Spider Field", "Stump Field"},
	["Spider Field"]       = {"Mushroom Field", "Clover Field", "Strawberry Field", "Pumpkin Patch"},
	["Strawberry Field"]   = {"Blue Flower Field", "Spider Field", "Bamboo Field"},
	["Bamboo Field"]       = {"Strawberry Field", "Pine Tree Forest"},
	["Pineapple Patch"]    = {"Pumpkin Patch", "Cactus Field"},
	["Pumpkin Patch"]      = {"Spider Field", "Pineapple Patch", "Cactus Field"},
	["Cactus Field"]       = {"Pineapple Patch", "Pumpkin Patch", "Rose Field"},
	["Pine Tree Forest"]   = {"Bamboo Field", "Stump Field", "Rose Field"},
	["Rose Field"]         = {"Pine Tree Forest", "Cactus Field", "Mountain Top Field", "Pepper Patch"},
	["Stump Field"]        = {"Clover Field", "Pine Tree Forest"},
	["Mountain Top Field"] = {"Rose Field", "Pepper Patch"},
	["Pepper Patch"]       = {"Rose Field", "Mountain Top Field"},
}

local function hivePad(hive)
	local best, bestY = nil, math.huge
	for _, p in ipairs(hive:GetDescendants()) do
		pcall(function() if p:IsA("BasePart") and p.Position.Y < bestY then bestY = p.Position.Y; best = p end end)
	end; return best or hive.PrimaryPart or hive:FindFirstChildWhichIsA("BasePart")
end
local function padTop(pad) return pad.Position.Y + pad.Size.Y / 2 + 2 end

local function nearestNode(pos)
	local bestName, bestDist = nil, math.huge
	local zones = Workspace:FindFirstChild("FlowerZones")
	if zones then for name, _ in pairs(FIELD_ADJ) do if name ~= "HIVE" then
		local f = zones:FindFirstChild(name)
		if f then local d = Vector3.new(pos.X - f.Position.X, 0, pos.Z - f.Position.Z).Magnitude
			if d < bestDist then bestDist = d; bestName = name end
		end
	end end end
	if myHive then local pad = hivePad(myHive)
		if pad then local d = Vector3.new(pos.X - pad.Position.X, 0, pos.Z - pad.Position.Z).Magnitude
			if d < bestDist then bestDist = d; bestName = "HIVE" end
		end
	end; return bestName
end

local function nodePos(name)
	if name == "HIVE" and myHive then local pad = hivePad(myHive)
		if pad then return Vector3.new(pad.Position.X, padTop(pad), pad.Position.Z) end
	end
	local f = getField(name)
	if f then return Vector3.new(f.Position.X, groundY(f) + 2, f.Position.Z) end; return nil
end

local function fieldEdgeToward(fieldPos, fieldSize, toward, y)
	local dx = toward.X - fieldPos.X; local dz = toward.Z - fieldPos.Z
	local len = math.sqrt(dx*dx + dz*dz)
	if len < 1 then return Vector3.new(fieldPos.X, y, fieldPos.Z) end
	dx = dx/len; dz = dz/len
	local halfX = math.max(fieldSize.X/2 - 3, 1)
	local halfZ = math.max(fieldSize.Z/2 - 3, 1)
	local tX = math.abs(dx) > 0.01 and (halfX / math.abs(dx)) or 9999
	local tZ = math.abs(dz) > 0.01 and (halfZ / math.abs(dz)) or 9999
	local t = math.min(tX, tZ)
	return Vector3.new(fieldPos.X + dx*t, y, fieldPos.Z + dz*t)
end

local function findFieldPathNames(fromName, toName)
	if fromName == toName then return {} end
	if not FIELD_ADJ[fromName] or not FIELD_ADJ[toName] then return {} end
	local queue = {{fromName}}; local visited = {[fromName] = true}
	while #queue > 0 do
		local path = table.remove(queue, 1); local current = path[#path]
		local neighbors = FIELD_ADJ[current]
		if neighbors then for _, nxt in ipairs(neighbors) do
			if not visited[nxt] then visited[nxt] = true
				local newPath = {}; for _, p in ipairs(path) do newPath[#newPath+1] = p end
				newPath[#newPath+1] = nxt
				if nxt == toName then return newPath end
				queue[#queue+1] = newPath
			end
		end end
	end; return {}
end

-- ═══════════════════════════════════════════════════════════
--  navigateTo: smart long-distance navigation
--
--  "Tween"        → direct tween (forceTween=true)
--  "Walk + Tween" → direct tween (forceTween=true) for long travel
--  "Walk"         → edge-to-edge corridor pathfinding
-- ═══════════════════════════════════════════════════════════
local function navigateTo(target, thr, skipOnCheck)
	local mode = S.move_type

	-- Tween and Walk+Tween both tween for long-distance travel
	if mode == "Tween" or mode == "Walk + Tween" then
		return moveTo(target, thr, skipOnCheck, true)  -- forceTween = true
	end

	-- Walk mode: use pathfinding for long distances
	local hrp = getHRP()
	if not hrp then return false end
	if (hrp.Position - target).Magnitude < 40 then
		return moveTo(target, thr, skipOnCheck)
	end

	local fromNode = nearestNode(hrp.Position)
	local toNode = nearestNode(target)
	if not fromNode or not toNode or fromNode == toNode then
		return moveTo(target, thr, skipOnCheck)
	end

	local pathNames = findFieldPathNames(fromNode, toNode)
	if #pathNames < 2 then return moveTo(target, thr, skipOnCheck) end

	-- build edge-to-edge corridor waypoints
	local waypoints = {}
	for i = 1, #pathNames - 1 do
		local nameA, nameB = pathNames[i], pathNames[i+1]
		local posA, posB = nodePos(nameA), nodePos(nameB)
		if posA and posB then
			local fieldA = (nameA ~= "HIVE") and getField(nameA) or nil
			local fieldB = (nameB ~= "HIVE") and getField(nameB) or nil
			local yMax = math.max(posA.Y, posB.Y)
			if fieldA then waypoints[#waypoints+1] = fieldEdgeToward(fieldA.Position, fieldA.Size, posB, posA.Y) end
			waypoints[#waypoints+1] = Vector3.new((posA.X+posB.X)/2, yMax, (posA.Z+posB.Z)/2)
			if fieldB then waypoints[#waypoints+1] = fieldEdgeToward(fieldB.Position, fieldB.Size, posA, posB.Y) end
		end
	end
	if #waypoints == 0 then return moveTo(target, thr, skipOnCheck) end

	for i, wp in ipairs(waypoints) do
		if not skipOnCheck and not isOn() then return false end
		status = "path " .. i .. "/" .. #waypoints; setStatus()
		if not moveTo(wp, 6, skipOnCheck) then return false end
	end
	return moveTo(target, thr, skipOnCheck)
end

-- ═══════════════════════════════════════════════════════════
--  SPRINKLER
-- ═══════════════════════════════════════════════════════════
local function useSprinkler(reps)
	for i = 1, reps do if not isOn() then return end
		local t0 = tick()
		setKey(KEY_SPACE, true); wait(0.05); setKey(KEY_SPACE, false); wait(0.2)
		setKey(KEY_ONE, true); wait(0.06); setKey(KEY_ONE, false); wait(0.4)
		local gap = 1.0 - (tick() - t0); if gap > 0 and i < reps then wait(gap) end
	end
end

-- ═══════════════════════════════════════════════════════════
--  TOKEN SCANNER
-- ═══════════════════════════════════════════════════════════
local function scanTokens(field, farmMode, closeR, eyePos, losOn)
	local out = {}
	local folder = Workspace:FindFirstChild("Collectibles"); if not folder then return out end
	local okk, kids = pcall(function() return folder:GetChildren() end)
	if not okk or not kids then return out end
	for i = 1, #kids do local obj = kids[i]; local pos
		local okp, p = pcall(function() return obj.Position end)
		if okp and p then pos = p else local okm, mp = pcall(function() return obj.PrimaryPart.Position end)
			if okm and mp then pos = mp end end
		if pos and inField(pos, field, 4) then
			if farmMode ~= 1 or distToCenter(pos, field) <= closeR then
				local score = Vector3.new(pos.X - eyePos.X, 0, pos.Z - eyePos.Z).Magnitude
				if losOn and not losClear(eyePos, pos) then score = score + 1000 end
				out[#out+1] = { part = obj, pos = pos, score = score }
			end
		end
		if i % 25 == 0 then wait() end
	end; return out
end

-- ═══════════════════════════════════════════════════════════
--  HIVE
-- ═══════════════════════════════════════════════════════════
local function setHiveManual()
	local honey = Workspace:FindFirstChild("Honeycombs"); local hrp = getHRP()
	if not honey or not hrp then toast("get in game first"); return end
	local best, bestDist = nil, math.huge
	for _, hive in ipairs(honey:GetChildren()) do local pad = hivePad(hive)
		if pad then local d = (pad.Position - hrp.Position).Magnitude
			if d < bestDist then bestDist = d; best = hive end
		end
	end
	if best and bestDist <= 60 then myHive = best; toast("hive: " .. best.Name)
		if hivePar then pcall(function() hivePar:SetContent("hive: " .. best.Name) end) end
	else toast("stand near your hive") end
end

local function autoDetectHive()
	if autoDetecting then return end; autoDetecting = true
	local honey = Workspace:FindFirstChild("Honeycombs")
	if not honey then toast("honeycombs not found"); autoDetecting = false; return end
	local hives = honey:GetChildren(); toast("scanning " .. #hives .. " hives...")
	local unclaimedHive, unclaimedIdx = nil, nil

	for idx = 1, #hives do
		local hive = hives[idx]; local pad = hivePad(hive)
		if pad then
			local pp = pad.Position; local target = Vector3.new(pp.X, padTop(pad), pp.Z)
			status = "detect: hive " .. idx .. "/" .. #hives; setStatus()
			moveTo(target, 3, true, true); wait(1.5)
			local text = findHiveText()
			if text == "trade" then status = "hive " .. idx .. ": other"; setStatus()
			elseif text == "ready" or text == "converting" or text == "empty" then
				myHive = hive; toast("YOUR hive: " .. hive.Name)
				if hivePar then pcall(function() hivePar:SetContent("hive: " .. hive.Name) end) end
				autoDetecting = false; return
			else if not unclaimedHive then unclaimedHive = hive; unclaimedIdx = idx end end
		end; wait(0.5)
	end

	if unclaimedHive then
		local pad = hivePad(unclaimedHive)
		if pad then
			local pp = pad.Position; local target = Vector3.new(pp.X, padTop(pad), pp.Z)
			toast("claiming hive " .. (unclaimedIdx or "?") .. "..."); status = "claiming..."; setStatus()
			moveTo(target, 3, true, true); wait(0.5)
			for attempt = 1, 30 do pressE(); wait(0.8)
				local text = findHiveText()
				if text == "ready" or text == "converting" or text == "empty" then
					myHive = unclaimedHive; toast("claimed: " .. unclaimedHive.Name)
					if hivePar then pcall(function() hivePar:SetContent("hive: " .. unclaimedHive.Name) end) end
					autoDetecting = false; return
				end
				status = "claiming... E #" .. attempt; setStatus(); wait(0.3)
			end; toast("could not claim")
		end
	else toast("all hives taken!") end
	autoDetecting = false
end

-- ═══════════════════════════════════════════════════════════
--  CONVERT
-- ═══════════════════════════════════════════════════════════
local function convertAtHive()
	local pad = hivePad(myHive); if not pad then wait(1); return end
	local pp = pad.Position; local target = Vector3.new(pp.X, padTop(pad), pp.Z)
	collecting = false; status = "going to hive"; setStatus()
	navigateTo(target, 2)

	local dl = tick() + 15
	while isOn() and tick() < dl do
		local hrp = getHRP(); if not hrp then break end
		if Vector3.new(hrp.Position.X - pp.X, 0, hrp.Position.Z - pp.Z).Magnitude <= 3 then break end
		moveTo(target, 2, false, true); wait(0.3)
	end
	if not isOn() then return end; wait(0.5)

	status = "converting"; setStatus(); pressE()
	local cw = tick() + 8
	while isOn() and tick() < cw do local text = findHiveText()
		if text == "converting" or text == "empty" then break end
		if text == "ready" then wait(0.3); pressE() end; wait(0.4)
	end

	dl = tick() + 120
	while isOn() and tick() < dl do
		local text = findHiveText(); if text == "empty" then break end
		local p = getPollen(); if p and p <= 0 then break end
		local hrp = getHRP()
		if hrp then local drift = Vector3.new(hrp.Position.X - pp.X, 0, hrp.Position.Z - pp.Z).Magnitude
			if drift > 4 then status = "re-engaging"; setStatus()
				moveTo(target, 2, false, true); wait(0.5); pressE()
				local rw = tick() + 5
				while isOn() and tick() < rw do local t2 = findHiveText()
					if t2 == "converting" or t2 == "empty" then break end
					if t2 == "ready" then pressE() end; wait(0.4)
				end; status = "converting"; setStatus()
			end
		end
		local pollen = getPollen(); local cap = getCap()
		if pollen and cap then bpText = math.floor(pollen).." / "..math.floor(cap) end
		setStatus(); wait(0.5)
	end
	stopWalk(); pcall(function() keyrelease(KEY_E) end)
	if isOn() then status = "waiting (7s)"; setStatus(); wait(7) end
	needSprinkler = true
end

local function doReset()
	status = "resetting"; setStatus(); releaseMoveKeys()
	pcall(function() keypress(KEY_ESC) end); wait(0.1); pcall(function() keyrelease(KEY_ESC) end); wait(0.5)
	pcall(function() keypress(KEY_R) end); wait(0.1); pcall(function() keyrelease(KEY_R) end); wait(0.5)
	pcall(function() keypress(KEY_ENTER) end); wait(0.1); pcall(function() keyrelease(KEY_ENTER) end); wait(2)
	local dl = tick() + 15
	while isOn() and tick() < dl do if getHRP() then break end; wait(0.3) end
	if currentField and isOn() then status = "returning"; setStatus()
		local c = currentField.Position; navigateTo(Vector3.new(c.X, groundY(currentField)+2, c.Z), 3)
	end; needSprinkler = true
end

local function forever(fn)
	task.spawn(function() while true do local ok = pcall(fn); if not ok then wait(0.5) end end end)
end

-- ═══════════════════════════════════════════════════════════
--  FIELDS
-- ═══════════════════════════════════════════════════════════
local zoneNames = {
	"Dandelion Field", "Sunflower Field", "Mushroom Field", "Blue Flower Field",
	"Clover Field", "Spider Field", "Bamboo Field", "Strawberry Field",
	"Pineapple Patch", "Pumpkin Patch", "Cactus Field", "Pine Tree Forest",
	"Rose Field", "Stump Field", "Mountain Top Field", "Pepper Patch",
}
pcall(function() local zones = Workspace:FindFirstChild("FlowerZones")
	if zones then local known = {}; for _, n in ipairs(zoneNames) do known[n] = true end
		for _, z in ipairs(zones:GetChildren()) do if not known[z.Name] then zoneNames[#zoneNames+1] = z.Name end end
	end
end)

-- ═══════════════════════════════════════════════════════════
--  WABI SABI UI
-- ═══════════════════════════════════════════════════════════
local Window = Library:CreateWindow({
	Title = "Bee Farm", SubTitle = "v11.5 matcha",
	Size = Vector2.new(480, 600), Resize = true,
})

-- ════════════ TAB: FARMING ════════════
local TabF = Window:AddTab({ Title = "Farming", Icon = "layout-dashboard" })
TabF:AddToggle({ Id = "farm_on", Title = "Auto Farm", Default = false,
	Callback = function(v) if v and not S.farm_on then needSprinkler = true end; S.farm_on = v == true end,
})
TabF:AddDropdown({ Id = "field_sel", Title = "Field", Values = zoneNames, Default = "Dandelion Field",
	Callback = function(v) if v ~= S.field then needSprinkler = true end; S.field = v end,
})
TabF:AddDropdown({ Id = "farm_mode", Title = "Farm Mode",
	Values = { "Middle Only", "Close Middle", "Whole Field" }, Default = "Whole Field",
	Callback = function(v) S.farm_mode = v end,
})
TabF:AddDropdown({ Id = "move_type", Title = "Move Type",
	Values = { "Walk + Tween", "Tween", "Walk" }, Default = "Walk + Tween",
	Callback = function(v) S.move_type = v end,
})
TabF:AddSlider({ Id = "close_r", Title = "Close Radius", Min = 5, Max = 60, Default = 12, Rounding = 0,
	Callback = function(v) S.close_r = v end,
})
TabF:AddSlider({ Id = "full_pct", Title = "Go Hive At %", Min = 50, Max = 100, Default = 90, Rounding = 0,
	Callback = function(v) S.full_pct = v end,
})
statusPar = TabF:AddParagraph({ Title = "Status", Content = "state: off\npollen: ?" })

-- ════════════ TAB: HIVE ════════════
local TabH = Window:AddTab({ Title = "Hive", Icon = "home" })
TabH:AddButton({ Title = "Auto Detect Hive", Description = "checks ALL hives, finds yours or claims unclaimed",
	Callback = function() task.spawn(autoDetectHive) end,
})
TabH:AddButton({ Title = "Set Hive (Manual)", Description = "stand near your pad", Callback = setHiveManual })
TabH:AddButton({ Title = "Force Return Now", Callback = function() forceReturn = true end })
TabH:AddToggle({ Id = "reset_mode", Title = "Reset Instead Of Convert", Default = false,
	Callback = function(v) S.reset_mode = v == true end,
})
TabH:AddInput({ Id = "cap_txt", Title = "Manual Cap Override", Default = "", Placeholder = "e.g. 25M",
	Finished = true, Callback = function(text) manualCap = parseNum(text) end,
})
hivePar = TabH:AddParagraph({ Title = "Hive", Content = "hive: not set" })

-- ════════════ TAB: SETTINGS ════════════
local TabS = Window:AddTab({ Title = "Settings", Icon = "settings" })

TabS:AddParagraph({ Title = "─── Tween Settings ───", Content = "applies to Tween + Walk+Tween long travel" })
TabS:AddSlider({ Id = "glide_speed", Title = "Tween Speed", Min = 50, Max = 1000, Default = 200, Rounding = 0,
	Callback = function(v) S.glide_speed = v end,
})

TabS:AddParagraph({ Title = "─── Walk Settings ───", Content = "applies to Walk + Walk+Tween in-field" })
TabS:AddDropdown({ Id = "walk_type", Title = "Walk Type",
	Values = { "Custom Speed", "Default Speed" }, Default = "Custom Speed",
	Callback = function(v) S.walk_type = v end,
})
TabS:AddSlider({ Id = "walk_speed", Title = "Walk Speed (Custom)", Min = 16, Max = 500, Default = 150, Rounding = 0,
	Callback = function(v) S.walk_speed = v end,
})
TabS:AddToggle({ Id = "find_path", Title = "Find Path (Wall Jump)", Default = false,
	Description = "raycast + escalating jump, walk only",
	Callback = function(v) S.find_path = v == true end,
})

TabS:AddParagraph({ Title = "─── Utility ───", Content = "" })
TabS:AddDropdown({ Id = "sprinkler_sel", Title = "Sprinkler (hotkey 1)",
	Values = { "Off", "Basic", "Silver", "Gold", "Diamond", "Supreme" }, Default = "Off",
	Callback = function(v) S.sprinkler = v end,
})
TabS:AddToggle({ Id = "dig_click", Title = "Auto Click (Dig)", Default = false,
	Callback = function(v) S.dig_click = v == true end,
})
TabS:AddToggle({ Id = "face_center", Title = "Face Center", Default = false,
	Callback = function(v) S.face_center = v == true end,
})
TabS:AddToggle({ Id = "token_los", Title = "Token Raycast", Default = false,
	Callback = function(v) S.token_los = v == true end,
})

Library:Notify({ Title = "Bee Farm", Content = "v11.5 loaded — Walk+Tween mode", Duration = 4 })

-- ═══════════════════════════════════════════════════════════
--  THREADS
-- ═══════════════════════════════════════════════════════════
forever(function()
	if isOn() and S.dig_click and collecting then pcall(function() mouse1click() end) end; wait(0.5)
end)
forever(function()
	if isOn() and S.face_center and collecting and not moving and currentField
		and (S.move_type == "Tween") then faceCenter(currentField) end; wait(0.15)
end)

-- ═══════════════════════════════════════════════════════════
--  MAIN LOOP
-- ═══════════════════════════════════════════════════════════
forever(function()
	if not isOn() then status = "off"; collecting = false; stopWalk(); releaseMoveKeys()
		pcall(function() keyrelease(KEY_E) end); setStatus(); wait(0.25); return end

	local field = getField(S.field); currentField = field
	if not field then status = "no FlowerZones"; collecting = false; setStatus(); wait(1); return end

	local pollen = getPollen(); local cap = getCap()
	if pollen and cap then bpText = math.floor(pollen).." / "..math.floor(cap)
	elseif pollen then bpText = math.floor(pollen).." / ?" else bpText = "?" end

	local full = forceReturn or (pollen and cap and cap > 0 and pollen >= cap * ((S.full_pct or 90) / 100))
	if full then forceReturn = false; collecting = false
		if S.reset_mode then doReset()
		elseif myHive then convertAtHive()
		else status = "FULL - set hive!"; setStatus(); wait(0.5) end; return
	end

	local hrp = getHRP()
	if not hrp then collecting = false; setStatus(); wait(0.5); return end

	local c = field.Position; local center = Vector3.new(c.X, groundY(field)+2, c.Z)
	local farmMode = MODE_INDEX[S.farm_mode] or 2; local closeR = S.close_r or 12
	local standY = groundY(field) + 2
	local faceOn = S.face_center and S.move_type == "Tween"

	local reps = SPRINK_REPS[S.sprinkler] or 0
	if needSprinkler and reps > 0 then
		if not sprinklerNotified then sprinklerNotified = true; toast("sprinkler in slot 1") end
		needSprinkler = false; collecting = false
		status = "to field"; setStatus(); navigateTo(center, 3)
		status = "sprinklers"; setStatus(); useSprinkler(reps)
	end; needSprinkler = false

	-- go to field if far away
	if not inField(hrp.Position, field, 10) then
		status = "going to field"; setStatus()
		navigateTo(center, 5)
	end

	collecting = true

	if farmMode == 0 then
		if distToCenter(hrp.Position, field) > 4 or math.abs(hrp.Position.Y - standY) > 5 then
			status = "to middle"; setStatus(); moveTo(center, 3)
		end
		status = "collecting (middle)"; setStatus()
		if faceOn then faceCenter(field) else wait(0.15) end; return
	end

	status = "collecting"; setStatus()
	local visited, refreshes = {}, 0
	local deadline = tick() + 6
	local list = scanTokens(field, farmMode, closeR, hrp.Position + Vector3.new(0,2,0), S.token_los)

	while isOn() and tick() < deadline do
		local root = getHRP(); if not root then break end; local pos = root.Position
		if not inField(pos, field, 0) or (farmMode == 1 and distToCenter(pos, field) > closeR) then
			status = "returning"; setStatus()
			moveTo(clampTarget(center, field, farmMode, closeR), 3)
			status = "collecting"; setStatus()
		end
		local bestI, bestD = nil, math.huge
		for i = 1, #list do if not visited[i] then local t = list[i]
			local d = Vector3.new(t.pos.X - pos.X, 0, t.pos.Z - pos.Z).Magnitude
			if t.score >= 1000 then d = d + 1000 end
			if d < bestD then bestD = d; bestI = i end
		end end
		if not bestI then refreshes = refreshes + 1; if refreshes > 3 then break end
			local r2 = getHRP(); if not r2 then break end
			list = scanTokens(field, farmMode, closeR, r2.Position + Vector3.new(0,2,0), S.token_los); visited = {}
		else local t = list[bestI]
			moveTo(clampTarget(Vector3.new(t.pos.X, standY, t.pos.Z), field, farmMode, closeR), 2)
			if faceOn then faceCenter(field) else wait(0.1) end; visited[bestI] = true
		end
	end

	if isOn() then local roamR = farmMode == 1 and (closeR * 0.8) or nil
		local root = getHRP()
		if root and (farmMode == 1 or distToCenter(root.Position, field) > 4) then
			moveTo(clampTarget(randomPoint(field, roamR), field, farmMode, closeR), 3)
		end
	end; setStatus()
end)

print("[bee farm] v11.5 loaded")
