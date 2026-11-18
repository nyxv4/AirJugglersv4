local _args = ...
if type(_args) ~= "table" then _args = {} end
local pinnedCommit = type(_args.Commit) == 'string' and _args.Commit ~= '' and _args.Commit or nil

local isfile = isfile or function(file)
	local suc, res = pcall(function() return readfile(file) end)
	return suc and res ~= nil and res ~= ''
end
local delfile = delfile or function(file) writefile(file, '') end

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
			local complete = true
			for _, file in pairs(files) do
				if type(file) == 'table' and type(file.name) == 'string' and file.name:match('%.txt$') and file.name ~= 'commit.txt' then
					local baseName = (file.name:match('^(.-)%.txt$') or file.name):gsub('%d+$', '')
					local fileId = (game.GameId == 2619619496) and game.GameId or game.PlaceId
					local filePath = 'NYX/profiles/premade/' .. baseName .. tostring(fileId) .. '.txt'
					local ds, dc = pcall(function() return game:HttpGet(file.download_url, true) end)
					if ds and type(dc) == 'string' and #dc > 0 and dc ~= '404: Not Found' and not dc:match('^%d%d%d:') and not dc:match('^%s*<') then
						writefile(filePath, dc)
					else
						complete = false
					end
				end
			end
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
		local latest = isfile('NYX/profiles/latest.txt') and readfile('NYX/profiles/latest.txt') or ''
		local ok, res = pcall(function()
			return game:HttpGet('https://api.github.com/repos/nyxv4/nyx1/commits/main', true)
		end)
		local h = ok and type(res) == 'string' and res:match('"sha"%s*:%s*"(%x+)"')
		if h and #h == 40 then
			commit = h
			pcall(writefile, 'NYX/profiles/latest.txt', h)
		elseif #latest == 40 then
			commit = latest
		elseif #commit ~= 40 then
			commit = 'main'
		end
	end
	forceRef = commit
	if oldCommit ~= commit then
		wipeFolder('NYX')
		wipeFolder('NYX/games')
		wipeFolder('NYX/guis')
		pcall(function() if isfile('NYX/guis/new.lua') then delfile('NYX/guis/new.lua') end end)
		wipeFolder('NYX/libraries')
		if isfolder('NYX/profiles/premade') then
			for _, file in listfiles('NYX/profiles/premade') do
				pcall(function() if isfile(file) then delfile(file) end end)
			end
		end
	end
	writefile('NYX/profiles/commit.txt', commit)
	local premadeCommit = isfile('NYX/profiles/premade/commit.txt') and readfile('NYX/profiles/premade/commit.txt') or ''
	local needPremade = #commit ~= 40 or not commit:match('^%x+$') or oldCommit ~= commit or premadeCommit ~= commit
	if needPremade then
		pcall(downloadPremadeProfiles, commit)
	end
end

return loadstring(downloadFile('NYX/main.lua', nil, forceRef), 'main')({
	Closet = _args.Closet,
	Commit = forceRef,
})
