--!strict
-- MapService.luau — satu-satunya tempat yang membaca penanda di map.
--
-- Kenapa dipusatkan. Penanda map (bagian 3.4) dibaca beberapa service:
-- EnemyService butuh waypoint lane dan PrimaryPart Core, MatchService butuh
-- titik spawn, ShopService butuh posisi untuk turret dan penghalang. Kalau
-- masing-masing membaca sendiri, map yang belum ada menghasilkan empat warn
-- yang isinya sama dan pemain melihat output penuh error berantai. Satu modul
-- berarti satu warn, sekali, dengan satu pesan yang menyebut apa yang dicari
-- dan apa yang harus dilakukan.
--
-- `assets/Arena.rbxmx` dan `assets/Lobby.rbxmx` harus keluar dari Roblox Studio
-- (lihat docs/TEST_CASES.md bagian 2), jadi di repo yang baru di-clone map-nya
-- MEMANG tidak ada dan modul ini memang akan mengembalikan nil. Itu bukan bug;
-- gameplay tinggal tidak jalan sampai map-nya ada.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Lanes = require(Shared.Modules.Lanes)

local MapService = {}

export type Lane = {
	name: string,
	-- Waypoint di-cache sebagai Vector3 sekali saat server start (bagian 3.4).
	-- Bukan referensi ke Part: membaca .Position tiap frame untuk 40 musuh
	-- menyentuh properti Instance ribuan kali per detik tanpa alasan, dan
	-- waypoint-nya tidak bergerak.
	waypoints: { Vector3 },
}

export type Arena = {
	root: Instance,
	coreServer: Model,
	corePart: BasePart,
	corePosition: Vector3,
	lanes: { Lane },
	playerSpawn: BasePart?,
}

export type Lobby = {
	root: Instance,
	readyPad: BasePart?,
	spawn: BasePart?,
}

local HELP = "Buat map-nya di Studio (lihat docs/TEST_CASES.md dan "
	.. "scripts/build_arena.luau), simpan lewat klik kanan > Save to File, lalu "
	.. "commit filenya."

local arenaCache: Arena? = nil
local arenaResolved = false
local lobbyCache: Lobby? = nil
local lobbyResolved = false

-- Satu bendera per map: warn-nya cuma boleh keluar sekali, tidak tiap frame.
local arenaWarned = false
local lobbyWarned = false

local function warnArenaOnce(reason: string)
	if arenaWarned then
		return
	end
	arenaWarned = true
	warn(
		string.format(
			"[MapService] Arena tidak bisa dipakai: %s. Gameplay tidak dijalankan. %s",
			reason,
			HELP
		)
	)
end

local function warnLobbyOnce(reason: string)
	if lobbyWarned then
		return
	end
	lobbyWarned = true
	warn(
		string.format(
			"[MapService] Lobby tidak lengkap: %s. Pemain tetap bisa main, tapi "
				.. "spawn dan ReadyPad lobby tidak berfungsi. %s",
			reason,
			HELP
		)
	)
end

local function readLane(laneFolder: Instance): (Lane?, string?)
	local names: { string } = {}
	local parts: { [string]: BasePart } = {}

	for _, child in laneFolder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(names, child.Name)
			parts[child.Name] = child
		end
	end

	-- Urutan dari NAMA yang di-sort numerik, bukan dari GetChildren(). Lihat
	-- Lanes.luau dan bagian 3.4.
	local ordered, problem = Lanes.orderWaypointNames(names)
	if ordered == nil then
		return nil, string.format("%s %s", laneFolder.Name, problem or "tidak valid")
	end

	local waypoints: { Vector3 } = {}
	for _, name in ordered do
		table.insert(waypoints, parts[name].Position)
	end

	return { name = laneFolder.Name, waypoints = waypoints }, nil
end

local function resolveArena(): (Arena?, string?)
	local root = Workspace:FindFirstChild("Arena")
	if root == nil then
		return nil, "Workspace.Arena tidak ada"
	end

	local coreServer = root:FindFirstChild("CoreServer")
	if coreServer == nil or not coreServer:IsA("Model") then
		return nil, "Workspace.Arena.CoreServer tidak ada atau bukan Model"
	end

	local corePart = coreServer.PrimaryPart
	if corePart == nil then
		return nil, "Workspace.Arena.CoreServer.PrimaryPart belum di-set"
	end

	local lanesFolder = root:FindFirstChild("Lanes")
	if lanesFolder == nil then
		return nil, "Workspace.Arena.Lanes tidak ada"
	end

	-- Lane dibaca berurutan (Lane1, Lane2, ...) supaya nomor lane di kode
	-- stabil antar server. Sama alasannya dengan waypoint: urutan
	-- GetChildren() tidak dijamin.
	local laneNames: { string } = {}
	local laneFolders: { [string]: Instance } = {}
	for _, child in lanesFolder:GetChildren() do
		local index = string.match(child.Name, "^Lane(%d+)$")
		if index ~= nil then
			table.insert(laneNames, index)
			laneFolders[index] = child
		end
	end
	local orderedLanes, laneProblem = Lanes.orderWaypointNames(laneNames)
	if orderedLanes == nil then
		return nil, string.format("Workspace.Arena.Lanes %s", laneProblem or "tidak valid")
	end

	local lanes: { Lane } = {}
	for _, index in orderedLanes do
		local lane, problem = readLane(laneFolders[index])
		if lane == nil then
			return nil, string.format("Workspace.Arena.Lanes.%s", problem or "tidak valid")
		end
		if #lane.waypoints < 2 then
			return nil,
				string.format(
					"Workspace.Arena.Lanes.Lane%s cuma punya %d waypoint, minimal 2",
					index,
					#lane.waypoints
				)
		end
		table.insert(lanes, lane)
	end

	local playerSpawnInstance = root:FindFirstChild("PlayerSpawn")
	local playerSpawn: BasePart? = nil
	if playerSpawnInstance ~= nil and playerSpawnInstance:IsA("BasePart") then
		playerSpawn = playerSpawnInstance
	end

	return {
		root = root,
		coreServer = coreServer,
		corePart = corePart,
		corePosition = corePart.Position,
		lanes = lanes,
		playerSpawn = playerSpawn,
	},
		nil
end

-- Arena dibaca sekali lalu di-cache. Kalau map belum ada, satu warn lalu nil
-- selamanya untuk sesi server ini — memeriksa ulang tiap frame tidak akan
-- membuat file muncul, dan Rojo yang men-sync map baru butuh restart playtest.
function MapService.getArena(): Arena?
	if arenaResolved then
		return arenaCache
	end
	arenaResolved = true

	local arena, reason = resolveArena()
	if arena == nil then
		warnArenaOnce(reason or "alasan tidak diketahui")
		return nil
	end

	arenaCache = arena

	local summary: { string } = {}
	for _, lane in arena.lanes do
		table.insert(summary, string.format("%s=%d", lane.name, #lane.waypoints))
	end
	print(
		string.format(
			"[MapService] Arena siap: %d lane, waypoint di-cache (%s)",
			#arena.lanes,
			table.concat(summary, ", ")
		)
	)
	return arenaCache
end

function MapService.getLobby(): Lobby?
	if lobbyResolved then
		return lobbyCache
	end
	lobbyResolved = true

	local root = Workspace:FindFirstChild("Lobby")
	if root == nil then
		warnLobbyOnce("Workspace.Lobby tidak ada")
		return nil
	end

	local readyPadInstance = root:FindFirstChild("ReadyPad")
	local spawnInstance = root:FindFirstChild("SpawnLocation")

	local readyPad: BasePart? = nil
	if readyPadInstance ~= nil and readyPadInstance:IsA("BasePart") then
		readyPad = readyPadInstance
	end
	local lobbySpawn: BasePart? = nil
	if spawnInstance ~= nil and spawnInstance:IsA("BasePart") then
		lobbySpawn = spawnInstance
	end

	if readyPad == nil or lobbySpawn == nil then
		warnLobbyOnce("ReadyPad atau SpawnLocation tidak ada di Workspace.Lobby")
	end

	lobbyCache = { root = root, readyPad = readyPad, spawn = lobbySpawn }
	return lobbyCache
end

-- Dipakai test manual dan hot-reload di Studio: lupakan cache supaya map yang
-- baru di-sync dibaca ulang tanpa restart server.
function MapService.invalidate()
	arenaCache = nil
	arenaResolved = false
	arenaWarned = false
	lobbyCache = nil
	lobbyResolved = false
	lobbyWarned = false
end

return MapService
