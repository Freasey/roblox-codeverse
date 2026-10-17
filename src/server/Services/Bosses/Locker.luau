--!strict
-- Locker.luau — mekanik boss wave 10 (CONCEPT.md: analogi Ransomware).
--
-- Ransomware mengunci file korban lalu meminta tebusan. Mekaniknya meniru itu
-- dengan mengunci Toko Match: selama Locker hidup, tidak ada yang bisa dibeli.
-- Sambil itu dia memanggil minion terus-menerus, jadi menunggu bukan pilihan.
--
-- Kunci toko dipasang di `onSpawned` dan dilepas di `onDefeated`. Dua-duanya
-- WAJIB berpasangan: kalau boss mati lewat jalur yang tidak memanggil
-- onDefeated (match dibatalkan, Core hancur), toko akan tetap terkunci sampai
-- match berikutnya — jadi BossService juga melepasnya saat state keluar dari
-- WaveActive. Lihat komentar di sana.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Modules.Types)

local EnemyService = require(script.Parent.Parent.EnemyService)
local ShopService = require(script.Parent.Parent.ShopService)

local Locker = {}

export type State = {
	summonThread: thread?,
}

function Locker.newState(): State
	return { summonThread = nil }
end

local function stopSummoning(state: State)
	local thread = state.summonThread
	if thread ~= nil then
		task.cancel(thread)
		state.summonThread = nil
	end
end

function Locker.onSpawned(state: State, mechanic: Types.LockerMechanic, boss: EnemyService.Enemy)
	if mechanic.locksShop then
		ShopService.setLocked(true)
	end

	stopSummoning(state)

	local bossId = boss.id
	state.summonThread = task.spawn(function()
		while true do
			task.wait(mechanic.summonInterval)

			-- Boss diambil ulang dari EnemyService tiap putaran, bukan dipegang
			-- sebagai referensi: tabel `boss` yang dipegang di sini tetap ada
			-- di memori setelah musuhnya dihapus, jadi memeriksa `boss.dead`
			-- pada salinan lama bisa saja benar sementara entitasnya sudah
			-- tidak ada di arena.
			local current = EnemyService.get(bossId)
			if current == nil or current.dead then
				break
			end

			for offset = 1, mechanic.summonCount do
				-- Minion muncul dari AWAL lane, bukan dari posisi boss. Beda
				-- dari Splitter dengan sengaja: Locker memanggil bantuan dari
				-- luar (seperti ransomware yang menarik payload tambahan),
				-- bukan memecah dirinya sendiri.
				local laneCount = math.max(1, EnemyService.laneCount())
				local lane = (offset - 1) % laneCount + 1
				EnemyService.queue(mechanic.summonEnemyId, lane)
			end
		end
	end)

	print(
		string.format(
			"[Locker] toko dikunci, memanggil %d %s tiap %.0f detik",
			mechanic.summonCount,
			mechanic.summonEnemyId,
			mechanic.summonInterval
		)
	)
end

function Locker.onDefeated(state: State, mechanic: Types.LockerMechanic)
	stopSummoning(state)
	if mechanic.locksShop then
		ShopService.setLocked(false)
	end
	print("[Locker] boss mati, toko dibuka lagi")
end

-- Dipanggil juga saat match dibatalkan atau Core hancur, lewat jalur yang
-- bukan kematian boss.
function Locker.cleanup(state: State)
	stopSummoning(state)
	ShopService.setLocked(false)
end

return Locker
