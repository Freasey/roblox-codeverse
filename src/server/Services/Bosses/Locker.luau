--!strict
-- Locker.luau — mekanik boss wave 10 (CONCEPT.md: analogi Ransomware).
--
-- Ransomware tidak melarang korban berbelanja; dia menyandera yang sudah
-- dimiliki korban lalu meminta tebusan. Mekaniknya meniru itu dengan
-- MENYANDERA UPGRADE TIM yang sudah dibeli: selama Locker hidup, damage dan
-- attack speed kembali ke nilai dasar. Sambil itu dia memanggil minion
-- terus-menerus, jadi menunggu bukan pilihan.
--
-- Kunci toko (`setLocked`) juga dipasang, tapi sadari bahwa dia tidak menolak
-- apa pun: toko cuma buka saat `Intermission`, Locker cuma hidup saat
-- `WaveActive`, dan wave 10 adalah wave terakhir v1 sehingga tidak ada
-- `Intermission` sesudahnya. Jadi kunci itu cuma membuat pesan penolakannya
-- benar; yang betulan mengikat adalah sanderanya.
--
-- Pasang dan lepas WAJIB berpasangan. Kalau boss mati lewat jalur yang tidak
-- memanggil `onDefeated` (match dibatalkan, Core hancur di detik yang sama),
-- sanderanya akan terbawa ke match berikutnya dan terlihat sebagai damage yang
-- diam-diam mengecil. Dua jaring pengamannya: `Locker.cleanup` di bawah, dan
-- `ShopService.reset()` yang dipanggil saat match mulai.

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
		ShopService.setSuspended(true)
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
		ShopService.setSuspended(false)
	end
	print("[Locker] boss mati, upgrade tim dipulihkan")
end

-- Dipanggil juga saat match dibatalkan atau Core hancur, lewat jalur yang
-- bukan kematian boss. Tanpa dua baris ini, sandera upgrade bisa terbawa ke
-- match berikutnya; `ShopService.reset()` saat match mulai adalah jaring
-- pengaman keduanya.
function Locker.cleanup(state: State)
	stopSummoning(state)
	ShopService.setLocked(false)
	ShopService.setSuspended(false)
end

return Locker
