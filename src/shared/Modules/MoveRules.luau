--!strict
-- MoveRules.luau: aturan gerak pemain: sikap badan, stamina, dan dash.
--
-- Modul murni: tanpa game:GetService, tanpa Instance. Dipakai DUA SISI,
-- server memakainya untuk menegakkan aturan, client memakainya untuk
-- menggambar bar stamina. Satu sumber angka, jadi bar di layar tidak pernah
-- bercerita berbeda dari apa yang sebenarnya diizinkan server.
--
-- KENAPA ADA STAMINA SAMA SEKALI
--
-- Soal 4 meminta empat tindakan: idle, run, jump, crouch. Menambahkannya
-- sebagai empat tombol yang bisa ditekan kapan saja memang memenuhi soal, tapi
-- menghasilkan gerak yang tidak pernah jadi KEPUTUSAN: lari terus sepanjang
-- match selalu lebih baik daripada berjalan, dan jongkok tidak pernah ada
-- alasannya sama sekali.
--
-- Stamina yang membuat ketiganya saling terkait:
--   sprint  : cepat, menguras
--   walk    : netral, pulih pelan
--   crouch  : paling lambat, pulih paling cepat
--   dash    : bayar di muka, untuk keluar dari kepungan
-- Jadi pemain yang terjepit di lane harus memilih: mundur sambil jongkok
-- memulihkan tenaga, atau membakar sisa stamina untuk dash menembus.

local MoveRules = {}

export type Stance = string

-- Kecepatan tiap sikap, dalam stud/detik. `walk` 16 adalah kecepatan bawaan
-- Roblox dan sengaja dibiarkan apa adanya: itu patokan yang sudah dirasakan
-- pemain Roblox mana pun, dan menggesernya membuat game terasa aneh sebelum
-- pemain bisa menyebut kenapa.
MoveRules.SPEEDS = {
	walk = 16,
	sprint = 25,
	crouch = 7,
} :: { [string]: number }

-- Tinggi lompat per sikap. Jongkok tidak bisa melompat sama sekali, nol,
-- bukan angka kecil. Lompatan kecil saat jongkok akan terbaca sebagai lompatan
-- yang gagal, dan pemain akan terus mencobanya.
MoveRules.JUMP_HEIGHTS = {
	walk = 7.2,
	sprint = 8.4,
	crouch = 0,
} :: { [string]: number }

MoveRules.MAX_STAMINA = 100

-- Terkuras saat sprint DAN benar-benar bergerak. Berdiri diam sambil menahan
-- tombol sprint tidak menguras apa pun; kalau menguras, pemain yang lupa
-- melepas tombol kehilangan tenaga tanpa pernah tahu sebabnya.
MoveRules.SPRINT_DRAIN = 18

MoveRules.WALK_REGEN = 14
MoveRules.CROUCH_REGEN = 26

MoveRules.DASH_COST = 25
MoveRules.DASH_COOLDOWN = 1.1
MoveRules.DASH_SPEED = 64
MoveRules.DASH_DURATION = 0.22

-- Ambang untuk MULAI sprint lebih tinggi daripada ambang untuk BERHENTI (nol).
--
-- Selisih ini, histeresis, bukan kelebihan. Kalau kedua ambangnya sama,
-- pemain yang staminanya habis akan berganti sprint/walk puluhan kali per
-- detik: satu frame regen menaikkannya di atas ambang, sprint menyala, satu
-- frame drain menjatuhkannya lagi. Hasilnya kecepatan berkedip dan animasi
-- ikut berkedip bersamanya.
MoveRules.SPRINT_START_STAMINA = 18

function MoveRules.isStance(name: unknown): boolean
	return type(name) == "string" and MoveRules.SPEEDS[name] ~= nil
end

function MoveRules.speedFor(stance: Stance): number
	return MoveRules.SPEEDS[stance] or MoveRules.SPEEDS.walk
end

function MoveRules.jumpHeightFor(stance: Stance): number
	local height = MoveRules.JUMP_HEIGHTS[stance]
	if height == nil then
		return MoveRules.JUMP_HEIGHTS.walk
	end
	return height
end

-- Satu langkah waktu untuk stamina. Murni: terima nilai sekarang, kembalikan
-- nilai berikutnya. Tidak menyimpan apa pun, jadi server bisa memanggilnya
-- untuk empat pemain sekaligus dan client bisa memanggilnya untuk dirinya
-- sendiri, dari fungsi yang sama persis.
function MoveRules.stepStamina(current: number, stance: Stance, moving: boolean, dt: number): number
	local next = current

	if stance == "sprint" and moving then
		next -= MoveRules.SPRINT_DRAIN * dt
	elseif stance == "crouch" then
		next += MoveRules.CROUCH_REGEN * dt
	else
		next += MoveRules.WALK_REGEN * dt
	end

	return math.clamp(next, 0, MoveRules.MAX_STAMINA)
end

-- Sikap yang BOLEH dipakai, dengan mempertimbangkan stamina. Dipisah dari
-- `stepStamina` supaya server bisa memanggilnya tanpa ikut mengubah apa pun,
-- dan supaya aturan "sprint butuh tenaga" cuma ditulis sekali.
function MoveRules.resolveStance(
	requested: Stance,
	stamina: number,
	alreadySprinting: boolean
): Stance
	if not MoveRules.isStance(requested) then
		return "walk"
	end

	if requested == "sprint" then
		if stamina <= 0 then
			return "walk"
		end
		if not alreadySprinting and stamina < MoveRules.SPRINT_START_STAMINA then
			return "walk"
		end
	end

	return requested
end

-- Dash diizinkan kalau tenaganya cukup DAN cooldown-nya sudah lewat. Dua
-- syarat, bukan satu: cooldown saja membuat dash jadi tombol gratis yang
-- ditekan terus-menerus, dan biaya saja membuat pemain bisa menghabiskan
-- seluruh stamina dalam satu frame dengan menekan tombolnya berkali-kali.
function MoveRules.canDash(stamina: number, now: number, lastDashAt: number): boolean
	if stamina < MoveRules.DASH_COST then
		return false
	end
	return now - lastDashAt >= MoveRules.DASH_COOLDOWN
end

function MoveRules.validate(): (boolean, string?)
	for name, speed in MoveRules.SPEEDS do
		if MoveRules.JUMP_HEIGHTS[name] == nil then
			return false, string.format("sikap %s tidak punya tinggi lompat", name)
		end
		if speed <= 0 then
			return false, string.format("sikap %s berkecepatan %d", name, speed)
		end
	end

	if MoveRules.SPEEDS.crouch >= MoveRules.SPEEDS.walk then
		return false, "jongkok harus lebih lambat daripada jalan"
	end
	if MoveRules.SPEEDS.sprint <= MoveRules.SPEEDS.walk then
		return false, "sprint harus lebih cepat daripada jalan"
	end

	-- Jongkok harus benar-benar memulihkan lebih cepat daripada berjalan, kalau
	-- tidak tidak ada satu pun alasan untuk menekan tombolnya.
	if MoveRules.CROUCH_REGEN <= MoveRules.WALK_REGEN then
		return false, "jongkok harus memulihkan stamina lebih cepat daripada berjalan"
	end

	-- Sprint dari stamina penuh harus bertahan cukup lama untuk menyeberangi
	-- arena, kalau tidak tombolnya cuma gangguan.
	local sprintSeconds = MoveRules.MAX_STAMINA / MoveRules.SPRINT_DRAIN
	if sprintSeconds < 4 then
		return false, string.format("sprint cuma bertahan %.1f detik", sprintSeconds)
	end

	if MoveRules.SPRINT_START_STAMINA <= 0 then
		return false, "ambang mulai sprint harus di atas nol (lihat catatan histeresis)"
	end

	-- Dua pemeriksaan berikut menangkap jenis kesalahan yang sama: angka yang
	-- sah sendiri-sendiri, tapi menjadikan satu tombol MUSTAHIL ditekan.
	-- Gejalanya tidak terbaca sebagai angka yang salah, melainkan sebagai
	-- tombol yang rusak, dan yang dicari orang pertama kali adalah input-nya.
	if MoveRules.SPRINT_START_STAMINA > MoveRules.MAX_STAMINA then
		return false,
			string.format(
				"ambang mulai sprint %d di atas stamina penuh %d, sprint tidak akan pernah menyala",
				MoveRules.SPRINT_START_STAMINA,
				MoveRules.MAX_STAMINA
			)
	end
	if MoveRules.DASH_COST > MoveRules.MAX_STAMINA then
		return false,
			string.format(
				"dash berharga %d dari stamina penuh %d, dash tidak akan pernah bisa dibayar",
				MoveRules.DASH_COST,
				MoveRules.MAX_STAMINA
			)
	end

	return true, nil
end

return MoveRules
