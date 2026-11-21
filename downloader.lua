local _args = ...
if type(_args) ~= "table" then _args = {} end
local pinnedCommit = type(_args.Commit) == 'string' and _args.Commit ~= '' and _args.Commit or nil

local isfile = isfile or function(file)
	local suc, res = pcall(function() return readfile(file) end)
	return suc and res ~= nil and res ~= ''
end
local delfile = delfile or function(file) writefile(file, '') end

local UPDATE_CHECK_INTERVAL = 300
local function unixTime()
	local ok, t = pcall(function() return os.time() end)
	return ok and t or 0
end

local function downloadFile(path, func, forceRef)
	local cached = (isfile(path) and readfile(path)) or ''
	local ref = forceRef or (isfile('NYX/profiles/commit.txt') and readfile('NYX/profiles/commit.txt')) or 'main'
	if ref == '' then ref = 'main' end
	local watermark = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'
	local cachePrefix = #ref == 40 and ref:match('^%x+$') and (watermark..'--NYXCOMMIT:'..ref..'\n') or nil
	local current = cachePrefix and cached:sub(1, #cachePrefix) == cachePrefix
	if cached == '' or (forceRef and not current) then
		local res
		for attempt = 1, 3 do
			local suc, result = pcall(function()
				return game:HttpGet('https://raw.githubusercontent.com/nyxv4/nyx1/'..ref..'/'..select(1, path:gsub('^NYX/', '')), true)
			end)
			if suc and type(result) == 'string' and #result > 0 and result ~= '404: Not Found' and not result:match('^%d%d%d:') and not result:match('^%s*<') then
				res = result
				break
			end
			if suc and result == '404: Not Found' then break end
			if attempt < 3 then task.wait(0.5) end
		end
		if res then
			if path:find('%.lua') then res = (cachePrefix or watermark)..res end
			local dir = path:match('^(.*)/[^/]+$')
			if dir and not isfolder(dir) then makefolder(dir) end
			writefile(path, res)
			cached = res
		elseif cached == '' then
			error('Could not download '..path..' (GitHub unreachable)')
		end
	end
	if func then return func(path) end
	return cached
end

local function wipeFolder(path)
	if not isfolder(path) then return end
	for _, file in listfiles(path) do
		if file:find('loader') then continue end
		if isfile(file) and select(1, readfile(file):find('--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.')) == 1 then
			delfile(file)
		end
	end
end

for _, folder in {'NYX', 'NYX/games', 'NYX/profiles', 'NYX/assets', 'NYX/libraries', 'NYX/guis'} do
	if not isfolder(folder) then makefolder(folder) end
end

if not isfile('NYX/profiles/commit.txt') then
	writefile('NYX/profiles/commit.txt', 'main')
end

local function downloadPremadeProfiles(commit)
	local httpService = game:GetService('HttpService')
	if isfolder('NYX/profiles/premade') then
		for _, file in listfiles('NYX/profiles/premade') do
			pcall(function() if isfile(file) then delfile(file) end end)
		end
	else
		makefolder('NYX/profiles/premade')
	end
	local success, response = pcall(function()
		return game:HttpGet('https://api.github.com/repos/nyxv4/nyx1/contents/profiles/premade?ref=' .. commit)
	end)
	if success and response then
		local ok, files = pcall(function() return httpService:JSONDecode(response) end)
		if ok and type(files) == 'table' and response:match('^%s*%[') then
			local targets = {}
			for _, file in pairs(files) do
				if type(file) == 'table' and type(file.name) == 'string' and file.name:match('%.txt$') and file.name ~= 'commit.txt' then
					local baseName = (file.name:match('^(.-)%.txt$') or file.name):gsub('%d+$', '')
					local fileId = (game.GameId == 2619619496) and game.GameId or game.PlaceId
					table.insert(targets, {
						url = file.download_url,
						path = 'NYX/profiles/premade/' .. baseName .. tostring(fileId) .. '.txt',
					})
				end
			end
			local pending = #targets
			local complete = true
			for _, target in ipairs(targets) do
				task.spawn(function()
					local ds, dc = pcall(function() return game:HttpGet(target.url, true) end)
					if ds and type(dc) == 'string' and #dc > 0 and dc ~= '404: Not Found' and not dc:match('^%d%d%d:') and not dc:match('^%s*<') then
						writefile(target.path, dc)
					else
						complete = false
					end
					pending = pending - 1
				end)
			end
			while pending > 0 do task.wait() end
			if complete then writefile('NYX/profiles/premade/commit.txt', commit) end
		end
	end
end

local commit
local forceRef = pinnedCommit or 'main'
if not shared.VapeDeveloper then
	local oldCommit = readfile('NYX/profiles/commit.txt')
	commit = pinnedCommit or oldCommit
	if not pinnedCommit then
		-- Use the last known commit so inject never blocks on the API; the
		-- freshness check runs in the background for the next inject.
		local latest = isfile('NYX/profiles/latest.txt') and readfile('NYX/profiles/latest.txt') or ''
		if #latest == 40 and latest:match('^%x+$') then
			commit = latest
		end
		local lastCheck = tonumber(isfile('NYX/profiles/lastcheck.txt') and readfile('NYX/profiles/lastcheck.txt') or '') or 0
		if unixTime() - lastCheck >= UPDATE_CHECK_INTERVAL and not shared.NYXUpdateCheckRunning then
			shared.NYXUpdateCheckRunning = true
			task.spawn(function()
				local ok, res = pcall(function()
					return game:HttpGet('https://api.github.com/repos/nyxv4/nyx1/commits/main', true)
				end)
				local h = ok and type(res) == 'string' and res:match('"sha"%s*:%s*"(%x+)"')
				if h and #h == 40 then
					pcall(writefile, 'NYX/profiles/latest.txt', h)
					pcall(writefile, 'NYX/profiles/lastcheck.txt', tostring(unixTime()))
				end
				shared.NYXUpdateCheckRunning = nil
			end)
		end
	end
	forceRef = commit
	if oldCommit ~= commit then
		local pending = 0
		for _, folder in {'NYX', 'NYX/games', 'NYX/guis', 'NYX/libraries'} do
			pending = pending + 1
			task.spawn(function()
				pcall(wipeFolder, folder)
				pending = pending - 1
			end)
		end
		pcall(function() if isfile('NYX/guis/new.lua') then delfile('NYX/guis/new.lua') end end)
		while pending > 0 do task.wait() end
	end
	writefile('NYX/profiles/commit.txt', commit)
	local premadeCommit = isfile('NYX/profiles/premade/commit.txt') and readfile('NYX/profiles/premade/commit.txt') or ''
	local needPremade = #commit ~= 40 or not commit:match('^%x+$') or oldCommit ~= commit or premadeCommit ~= commit
	if needPremade then
		task.spawn(function() pcall(downloadPremadeProfiles, commit) end)
	end
end

return loadstring(downloadFile('NYX/main.lua', nil, forceRef), 'main')({
	Closet = _args.Closet,
	Commit = forceRef,
})
