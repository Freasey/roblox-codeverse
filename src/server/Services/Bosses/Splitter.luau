--!strict
-- Splitter.luau — mekanik boss wave 5 (CONCEPT.md: analogi Worm).
--
-- Worm menggandakan dirinya dan menyebar lewat jaringan tanpa korban membuka
-- apa pun. Mekaniknya meniru itu: saat HP boss turun melewati 66% dan 33%, dia
-- memecah diri jadi beberapa musuh kecil yang langsung lanjut ke Core dari
-- posisi boss saat itu.
--
-- Pembukuan "ambang mana yang sudah terpicu" dan "ambang mana yang baru
-- terlewati" ada di BossRules.luau (modul murni, ada unit test-nya). Yang
-- tinggal di sini cuma menempatkan musuh pecahannya di dunia.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local BossRules = require(Shared.Modules.BossRules)
local Types = require(Shared.Modules.Types)

local EnemyService = require(script.Parent.Parent.EnemyService)

local Splitter = {}

export type State = {
	triggered: { [number]: boolean },
}

function Splitter.newState(): State
	return { triggered = {} }
end

-- Dipanggil BossService tiap kali HP boss berubah.
function Splitter.onHealthChanged(
	state: State,
	mechanic: Types.SplitterMechanic,
	boss: EnemyService.Enemy
)
	local fraction = BossRules.fraction(boss.hp, boss.maxHp)
	local crossed = BossRules.newlyCrossed(mechanic.thresholds, fraction, state.triggered)

	for _, index in crossed do
		state.triggered[index] = true

		for offset = 1, mechanic.spawnCount do
			-- Disebar sedikit di sekitar boss, bukan semuanya di satu titik:
			-- musuh digerakkan server lewat CFrame dan tidak bertabrakan satu
			-- sama lain, jadi tanpa sebaran mereka benar-benar menumpuk jadi
			-- satu dan pemain cuma melihat satu musuh dengan HP bar bertumpuk.
			local angle = (offset / mechanic.spawnCount) * math.pi * 2
			local spread = Vector3.new(math.cos(angle) * 6, 0, math.sin(angle) * 6)

			-- Pecahan melanjutkan dari waypoint yang SAMA dengan boss, bukan
			-- dari awal lane: inti mekaniknya adalah ancaman yang tiba-tiba
			-- dekat, bukan gelombang baru dari jauh.
			EnemyService.spawnAt(
				mechanic.spawnEnemyId,
				boss.laneIndex,
				boss.position + spread,
				boss.waypointIndex
			)
		end

		print(
			string.format(
				"[Splitter] ambang %.0f%% terlewati, membelah jadi %d %s",
				mechanic.thresholds[index] * 100,
				mechanic.spawnCount,
				mechanic.spawnEnemyId
			)
		)
	end
end

-- Boss mati: tidak ada yang perlu dibersihkan. Musuh pecahan yang masih hidup
-- SENGAJA dibiarkan — wave 5 belum bersih sampai mereka juga habis, dan itu
-- memang bagian dari mekaniknya.
function Splitter.onDefeated(_state: State, _mechanic: Types.SplitterMechanic) end

return Splitter
