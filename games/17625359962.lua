-- RIVALS

local run = function(func)
	local ok, err = pcall(func)
	if not ok then
		warn('[NYX] module failed: '..tostring(err))
	end
end
local cloneref = cloneref or function(obj) return obj end
local playersService = cloneref(game:GetService('Players'))
local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity

run(function()
	local silent = vape.Modules['SilentAim']
	if silent then
		local method = silent.Options['Method']
		if method and method.Value ~= 'Raycast' then
			method:SetValue('Raycast')
		end
		local mode = silent.Options['Mode']
		if mode and mode.Value ~= 'Mouse' then
			mode:SetValue('Mouse')
		end
		local range = silent.Options['Range']
		if range and range.Value < 400 then
			range:SetValue(400)
		end
	end

	local trigger = vape.Modules['TriggerBot']
	if trigger then
		local distance = trigger.Options['Distance']
		if distance and distance.Value < 400 then
			distance:SetValue(400)
		end
	end
end)

run(function()
	local AutoShoot
	local Part
	local MaxAngle
	local Range
	local Delay
	local VisibleOnly

	local function findTarget()
		if not entitylib or not entitylib.isAlive then
			return
		end
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local origin, look = camera.CFrame.Position, camera.CFrame.LookVector
		local bestDot = math.cos(math.rad(MaxAngle.Value))
		local best
		for ent in entitylib.List do
			if ent.RootPart and ent.RootPart.Parent and entitylib.isVulnerable(ent) and entitylib.targetCheck(ent) then
				local part = Part.Value == 'Head' and ent.Head or ent.RootPart
				if part and part.Parent then
					local delta = part.Position - origin
					if delta.Magnitude <= Range.Value then
						local dot = look:Dot(delta.Unit)
						if dot >= bestDot then
							if not VisibleOnly.Enabled or not entitylib.Wallcheck(origin, part.Position, nil, ent) then
								best, bestDot = ent, dot
							end
						end
					end
				end
			end
		end
		return best
	end

	local function fire()
		local character = lplr.Character
		local tool = character and character:FindFirstChildWhichIsA('Tool')
		if tool then
			pcall(function()
				tool:Activate()
			end)
		end
		if mouse1click then
			pcall(mouse1click)
		end
	end

	AutoShoot = vape.Categories.Combat:CreateModule({
		Name = 'AutoShoot',
		Function = function(callback)
			if callback then
				repeat
					if findTarget() then
						fire()
					end
					task.wait(Delay.Value)
				until not AutoShoot.Enabled
			end
		end,
		Tooltip = 'Fires your equipped weapon whenever an enemy is in front of you'
	})
	Part = AutoShoot:CreateDropdown({
		Name = 'Part',
		List = {'Head', 'Body'},
		Tooltip = 'The part of the enemy that has to be in view'
	})
	MaxAngle = AutoShoot:CreateSlider({
		Name = 'Max Angle',
		Min = 0,
		Max = 45,
		Default = 6,
		Suffix = '°'
	})
	Range = AutoShoot:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 1000,
		Default = 300,
		Suffix = 'studs'
	})
	Delay = AutoShoot:CreateSlider({
		Name = 'Delay',
		Min = 0.05,
		Max = 1,
		Decimal = 100,
		Default = 0.1,
		Suffix = 's'
	})
	VisibleOnly = AutoShoot:CreateToggle({
		Name = 'Visible Only',
		Default = true
	})
end)
