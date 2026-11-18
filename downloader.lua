local _args = ...
if type(_args) ~= "table" then _args = {} end
local pinnedCommit = _args.Commit

local isfile = isfile or function(file)
	local suc, res = pcall(function() return readfile(file) end)
	return suc and res ~= nil and res ~= ''
end
local delfile = delfile or function(file) writefile(file, '') end

local function downloadFile(path, func, forceRef)
	if forceRef or not isfile(path) or readfile(path) == '' then
		local suc, res = pcall(function()
			local ref = forceRef
			if type(ref) ~= 'string' or ref == '' then
				ref = isfile('NYX/profiles/commit.txt') and readfile('NYX/profiles/commit.txt')
			end
			if type(ref) ~= 'string' or ref == '' then
				ref = 'main'
			end
			return game:HttpGet('https://raw.githubusercontent.com/nyxv4/nyx1/'..ref..'/'..select(1, path:gsub('NYX/', '')), true)
		end)
		if not suc or type(res) ~= 'string' or res == '' or res == '404: Not Found' then error(res) end
		if path:find('%.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		local dir = path:match('^(.*)/[^/]+$')
		if dir and not isfolder(dir) then makefolder(dir) end
		writefile(path, res)
	end
	return (func or readfile)(path)
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
		if ok and type(files) == 'table' then
			for _, file in pairs(files) do
				if file.name and file.name:find('.txt') and file.name ~= 'commit.txt' then
					local baseName = (file.name:match('^(.-)%.txt$') or file.name):gsub('%d+$', '')
					local fileId = (game.GameId == 2619619496) and game.GameId or game.PlaceId
					local filePath = 'NYX/profiles/premade/' .. baseName .. tostring(fileId) .. '.txt'
					local ds, dc = pcall(function() return game:HttpGet(file.download_url, true) end)
					if ds and dc and type(dc) == 'string' and #dc > 0 and dc ~= '404: Not Found' then writefile(filePath, dc) end
				end
			end
		end
	end
end

local commit
local forceRef = pinnedCommit or 'main'
if not shared.VapeDeveloper then
	commit = isfile('NYX/profiles/commit.txt') and readfile('NYX/profiles/commit.txt') or ''
	local latest = isfile('NYX/profiles/latest.txt') and readfile('NYX/profiles/latest.txt') or ''
	local ok, res = pcall(function()
		return game:HttpGet('https://api.github.com/repos/nyxv4/nyx1/commits/main', true)
	end)
	local h = ok and res and res:match('"sha"%s*:%s*"(%x+)"')
	if h and #h == 40 then
		commit = h
		forceRef = pinnedCommit or h
		pcall(writefile, 'NYX/profiles/latest.txt', h)
	elseif #latest == 40 then
		commit = latest
		forceRef = pinnedCommit or latest
	elseif #commit ~= 40 then
		commit = 'main'
	end
	if forceRef == 'main' and not pinnedCommit and type(commit) == 'string' and #commit == 40 then
		forceRef = commit
	end
	if commit ~= 'main' and (isfile('NYX/profiles/commit.txt') and readfile('NYX/profiles/commit.txt') or '') ~= commit then
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
	local oldCommit = isfile('NYX/profiles/commit.txt') and readfile('NYX/profiles/commit.txt') or ''
	writefile('NYX/profiles/commit.txt', commit)
	local needPremade = (oldCommit ~= commit)
	if not needPremade then
		needPremade = true
		if isfolder('NYX/profiles/premade') then
			for _ in listfiles('NYX/profiles/premade') do
				needPremade = false
				break
			end
		end
	end
	if needPremade then
		pcall(downloadPremadeProfiles, commit)
	end
end

return loadstring(downloadFile('NYX/main.lua', nil, forceRef), 'main')({
	Closet = _args.Closet,
	Commit = forceRef,
})
