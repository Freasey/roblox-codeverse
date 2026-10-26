--!strict
-- Poses.luau: data animasi karakter: sudut tiap sendi untuk tiap tindakan.
--
-- Modul murni: tanpa game:GetService, tanpa `script`, dan tanpa CFrame. Yang
-- dikembalikan cuma ANGKA. Itu bukan kerumitan yang dicari-cari, justru
-- karena bentuknya angka, seluruh animasi di game ini bisa diuji Lune tanpa
-- menjalankan Roblox sama sekali: "apakah fase 0.0 dan 0.5 pada lari benar-
-- benar cerminan satu sama lain" adalah pertanyaan yang bisa dijawab test,
-- bukan cuma dilihat dengan mata di playtest.
--
-- KENAPA ANIMASINYA DIHITUNG, BUKAN DIPUTAR DARI KLIP
--
-- Jalur biasa di Roblox adalah membuat klip di Animation Editor, meng-upload-
-- nya, lalu memutarnya lewat AnimationId. Jalur itu TIDAK dipakai di sini, dan
-- alasannya ada tiga:
--
--   1. AnimationId terikat ke akun yang meng-upload. Klip yang di-upload satu
--      anggota kelompok tidak bisa diputar di place milik anggota lain tanpa
--      di-upload ulang, file .rbxl-nya pindah, animasinya tidak ikut.
--   2. Roblox tidak menyediakan klip bawaan untuk JONGKOK. Soal 4 memintanya.
--      Jadi satu dari empat tindakan yang diminta memang harus dibuat sendiri,
--      bagaimanapun caranya.
--   3. Animasi yang berupa angka bisa diikat ke kecepatan sungguhan karakter.
--      Klip berjalan pada kecepatan tetap; yang di sini ikut melambat saat
--      pemain jongkok dan ikut cepat saat berlari, tanpa klip tambahan.
--
-- Konsekuensinya jujur dan disebutkan di laporan: gerakan hasil hitungan ini
-- lebih sederhana daripada klip yang dianimasikan tangan per keyframe.
--
-- ARAH PUTARAN TIAP SENDI
--
-- Angka di bawah tidak bisa dibaca tanpa tahu arah sumbunya, jadi ini
-- diturunkan sekali di sini. Pada rig R15, tiap Motor6D memutar Part1
-- terhadap sumbu Part0. Sumbu torso: +X kanan, +Y atas, -Z DEPAN.
--
--   Paha menunjuk ke -Y. Diputar +X sebesar t, komponen Z-nya jadi -sin(t),
--   yaitu ke arah -Z. Jadi: PINGGUL +X = kaki maju.
--   Lengan atas juga menunjuk -Y, jadi BAHU +X = lengan maju.
--   Betis menekuk ke BELAKANG (+Z), jadi LUTUT bertekuk di -X.
--   Lengan bawah menekuk ke DEPAN (-Z), jadi SIKU bertekuk di +X.
--   Torso atas menunjuk +Y. Condong ke depan berarti puncaknya ke -Z, dan
--   dari hitungan yang sama itu berarti PINGGANG condong depan di -X.
--   Leher mengikuti torso atas: menunduk di -X.
--   Bahu diputar +Z menggeser lengan ke +X (kanan). Jadi lengan MERENGGANG
--   dari badan berarti +Z untuk lengan kanan dan -Z untuk lengan kiri.
--
-- Kalau saat playtest ternyata kaki berayun terbalik, yang salah adalah satu
-- tanda ini untuk seluruh game, bukan satu pose. Karena itu disediakan
-- `SWING_SIGN` di bawah: ubah satu angka, bukan tiga puluh.

local Poses = {}

-- Pengali tanda untuk seluruh ayunan maju-mundur (pinggul, bahu, siku, lutut).
-- Ditulis sebagai konstanta supaya kalau turunan arah sumbu di atas keliru,
-- perbaikannya satu baris dan tidak ada pose yang ketinggalan diperbaiki.
local SWING_SIGN = 1

-- Satu entri pose: { rx, ry, rz, tx, ty, tz }.
-- Rotasi dalam RADIAN, translasi dalam STUD. Translasi hanya dipakai sendi
-- `Root` (naik-turun badan saat lari dan saat jongkok); sendi lain memakai
-- rotasi saja.
export type JointPose = { number }
export type Pose = { [string]: JointPose }

-- Sendi R15 yang dianimasikan. Dipakai juga oleh controller di client sebagai
-- daftar Motor6D yang perlu di-cache, supaya dua tempat tidak punya daftar
-- sendiri yang bisa berbeda.
Poses.JOINTS = {
	"Root",
	"Waist",
	"Neck",
	"LeftShoulder",
	"LeftElbow",
	"RightShoulder",
	"RightElbow",
	"LeftHip",
	"LeftKnee",
	"LeftAnkle",
	"RightHip",
	"RightKnee",
	"RightAnkle",
}

Poses.STATES = { "idle", "run", "crouch", "dash", "jump", "fall" }

local TAU = math.pi * 2

-- Panjang kaki rig R15 (paha + betis), dalam stud. Dipakai menghitung panjang
-- langkah, jadi dia bukan angka hiasan: salah di sini berarti kaki menggeser
-- di lantai.
Poses.LEG_LENGTH = 4.4

-- Amplitudo ayunan pinggul pada kecepatan penuh, dalam radian.
local HIP_SWING = 0.85

-- SIKAP ISTIRAHAT LENGAN. Dipakai BERSAMA oleh pose diam dan pose lari, dan
-- itulah gunanya ditulis sebagai konstanta alih-alih diketik dua kali.
--
-- Pose lari memakai kedua angka ini sebagai titik awal, lalu menambahkan
-- ayunan sebanding kecepatan di atasnya. Akibatnya `run(fase, 0)` menghasilkan
-- sikap lengan yang SAMA PERSIS dengan pose diam, jadi peralihan berhenti
-- berjalan tidak punya lompatan sudut sama sekali.
--
-- Kalau salah satunya diubah, yang satunya ikut berubah sendiri. Versi
-- sebelumnya menulis angkanya dua kali, dan saat angka di pose diam dinaikkan
-- dari 0.08 ke 0.15, pose lari tertinggal di angka lama tanpa ada yang sadar.
local REST_SHOULDER_SPREAD = 0.15
local REST_ELBOW = 0.12

-- Diekspor supaya test bisa memeriksa kontinuitas idle/lari tanpa menebak
-- angkanya sendiri.
Poses.REST_SHOULDER_SPREAD = REST_SHOULDER_SPREAD
Poses.REST_ELBOW = REST_ELBOW

-- BERAPA LANGKAH PER DETIK, dan kenapa ini dihitung, bukan dipatok.
--
-- Versi sebelumnya memakai irama tetap: `0.75 + 1.35 * amp` siklus per detik,
-- dengan `amp = kecepatan / WalkSpeed`. Kelihatannya masuk akal, tapi ada
-- lubang yang membuat lari terlihat salah dan sulit disebut kenapa:
-- `WalkSpeed` IKUT BERUBAH mengikuti sikap badan. Saat sprint, WalkSpeed jadi
-- 25 dan kecepatan sungguhan juga 25, jadi `amp` tetap 1, dan iramanya
-- tetap sama persis dengan berjalan. Pemain bergerak 56% lebih cepat dengan
-- jumlah langkah yang sama, dan telapak kakinya menggeser di lantai.
--
-- Menggeser di lantai ("foot skating") adalah satu hal yang paling cepat
-- membuat gerakan terbaca sebagai animasi amatir, bahkan oleh orang yang tidak
-- tahu namanya.
--
-- Hubungan yang harus dipenuhi supaya kaki tidak menggeser cuma satu:
--
--     kecepatan = irama x 2 x panjang langkah
--     panjang langkah = 2 x panjang kaki x sin(sudut ayun)
--
-- Satu persamaan, dua hal yang bisa ditentukan. Percobaan pertama menetapkan
-- SUDUT AYUN lalu menghitung irama, dan test langsung menunjukkan kenapa itu
-- keliru: iramanya nyaris tidak berubah (1,67 langkah/detik saat merayap
-- 3 stud/detik, 1,89 saat sprint 25). Karakternya melangkah secepat orang
-- sprint sambil memindahkan kaki 0,9 stud, terbaca sebagai menyeret kaki.
--
-- Jadi dibalik: IRAMA yang ditetapkan dari kecepatan, dan sudut ayun yang
-- dihitung dari sisanya. Ini juga yang lebih dekat ke gerak manusia, orang
-- yang mempercepat langkah menambah frekuensi DAN panjang langkah sekaligus.
--
-- Mengembalikan (irama dalam siklus per detik, sudut ayun pinggul dalam
-- radian). Keduanya dipakai bersama; memakai salah satunya dengan angka lain
-- mengembalikan masalah geser yang baru saja dibuang.
local MAX_SWING = 0.95
local CADENCE_BASE = 1.1
local CADENCE_PER_SPEED = 0.055
local CADENCE_CAP = 2.8

function Poses.gait(speed: number): (number, number)
	if speed < 0.1 then
		return 0, 0
	end

	local cadence = math.clamp(CADENCE_BASE + speed * CADENCE_PER_SPEED, CADENCE_BASE, CADENCE_CAP)
	local stepLength = speed / (2 * cadence)
	local sinAngle = stepLength / (2 * Poses.LEG_LENGTH)

	local maxSin = math.sin(MAX_SWING)
	if sinAngle > maxSin then
		-- Langkah yang dibutuhkan lebih panjang daripada yang sanggup dicapai
		-- kaki. Yang dinaikkan iramanya, BUKAN sudutnya: kaki yang direntang
		-- melebihi batas ini terlihat seperti split, dan tetap tidak akan
		-- menutup selisihnya.
		sinAngle = maxSin
		cadence = speed / (2 * (2 * Poses.LEG_LENGTH * maxSin))
	end

	return cadence, math.asin(sinAngle)
end

local function j(rx: number, ry: number, rz: number, ty: number?): JointPose
	return { rx, ry, rz, 0, ty or 0, 0 }
end

-- --------------------------------------------------------------------------
-- idle, berdiri diam
-- --------------------------------------------------------------------------
--
-- Yang membedakan "diam" dari "patung" cuma satu hal: napas. Amplitudonya
-- sengaja kecil (di bawah 0.04 radian, sekitar 2 derajat). Lebih besar dari
-- itu dan karakter terlihat bergoyang, bukan bernapas.
local function idle(phase: number): Pose
	local b = math.sin(phase * TAU)

	-- Perpindahan berat badan, berjalan pada sepertiga kecepatan napas.
	--
	-- Napas saja membuat karakter terlihat bernapas tapi tetap terpaku di satu
	-- titik. Manusia yang berdiri lama memindahkan berat dari satu kaki ke
	-- kaki lain, pelan dan tidak teratur. Frekuensi yang BUKAN kelipatan
	-- frekuensi napas itu yang penting: kalau kelipatan, keduanya kembali
	-- sefase secara berkala dan matanya menangkap pengulangan.
	local shift = math.sin(phase * TAU * 0.37)

	return {
		Root = j(0, shift * 0.02, shift * 0.035, b * 0.035),
		Waist = j(-0.02 + b * 0.015, shift * -0.03, shift * -0.02),
		Neck = j(0.012 - b * 0.012, shift * 0.02, 0),

		-- Lengan merenggang dari badan supaya siluetnya tidak jadi satu balok.
		-- Dinaikkan dari 0.08 ke 0.15 radian setelah melihat rekaman playtest:
		-- pada 0.08 lengan masih menyentuh sisi rompi, dan ayunannya hilang di
		-- dalam bayangan badan sendiri.
		LeftShoulder = j(b * 0.03 * SWING_SIGN, 0, -REST_SHOULDER_SPREAD),
		RightShoulder = j(b * 0.03 * SWING_SIGN, 0, REST_SHOULDER_SPREAD),
		LeftElbow = j((REST_ELBOW + b * 0.03) * SWING_SIGN, 0, 0),
		RightElbow = j((REST_ELBOW + b * 0.03) * SWING_SIGN, 0, 0),

		LeftHip = j(0, 0, 0),
		RightHip = j(0, 0, 0),
		LeftKnee = j(-0.03 * SWING_SIGN, 0, 0),
		RightKnee = j(-0.03 * SWING_SIGN, 0, 0),
		LeftAnkle = j(0, 0, 0),
		RightAnkle = j(0, 0, 0),
	}
end

-- --------------------------------------------------------------------------
-- run, berlari
-- --------------------------------------------------------------------------
--
-- `amp` adalah kecepatan ternormalisasi 0..1. Dia mengalikan SELURUH
-- amplitudo, jadi pose ini sekaligus menjadi pose berjalan saat amp kecil.
-- Itu yang membuat tidak perlu ada klip "walk" terpisah: satu rumus, dua
-- tampilan, dan peralihannya mulus karena memang satu nilai yang berubah.
--
-- "SELURUH amplitudo" itu syarat, bukan keterangan, dan ada test yang
-- menjaganya: `run(phase, 0)` harus menghasilkan pose netral, semua sendi
-- nol. Versi pertama fungsi ini punya dua suku tetap yang tidak dikalikan
-- `amp` (lengan merenggang 0.08 dan siku menekuk 0.3), dan akibatnya pose lari
-- pada kecepatan nyaris nol tetap berbeda 0.18 radian dari pose diam. Pemain
-- yang berhenti berjalan karena itu menyentak sedikit di sendi sikunya, dan
-- sentakan sebesar itu terlalu kecil untuk dicari penyebabnya lewat mata,
-- yang menemukannya test, bukan playtest.
local function run(phase: number, amp: number, swing: number): Pose
	local s = math.sin(phase * TAU)
	local c = math.cos(phase * TAU)

	-- Lutut menekuk hanya saat kakinya ada di belakang badan. `math.max(0, -s)`
	-- untuk kaki kanan: bernilai nol sepanjang ayunan maju, lalu naik mulus
	-- sampai 1 di titik paling belakang. Tanpa ini kedua lutut menekuk
	-- bersamaan dan larinya terlihat seperti meloncat-loncat.
	local rightBack = math.max(0, -s)
	local leftBack = math.max(0, s)

	-- Sudut pinggul dan lutut dihitung lebih dulu, karena pergelangan kaki
	-- dihitung DARI keduanya (lihat catatan "menapak rata" di bawah).
	local leftHip = -s * swing
	local rightHip = s * swing
	local leftKnee = -(0.16 + 0.8 * leftBack) * amp
	local rightKnee = -(0.16 + 0.8 * rightBack) * amp

	-- MENAPAK RATA. Telapak kaki harus mendatar saat berada di bawah badan,
	-- dan boleh miring saat melayang. Tanpa ini karakter berlari dengan ujung
	-- kaki menunjuk ke bawah terus-menerus, terlihat seperti balerina, dan
	-- itu satu lagi penanda animasi yang dibuat seadanya.
	--
	-- `1 - |s|` adalah perkiraan "seberapa dekat kaki ini ke titik terendah":
	-- bernilai 1 tepat saat kaki ada di bawah badan, turun ke 0 di ujung
	-- ayunan depan maupun belakang. Pergelangan melawan jumlah sudut pinggul
	-- dan lutut sebanding nilai itu.
	local plant = 1 - math.abs(s)
	local leftAnkle = -(leftHip + leftKnee) * plant * 0.85
	local rightAnkle = -(rightHip + rightKnee) * plant * 0.85

	return {
		-- Badan naik-turun dua kali per langkah, karena itu `math.abs`:
		-- satu puncak saat kaki kiri menapak, satu lagi saat kaki kanan.
		--
		-- Pinggul juga BERPUTAR mengikuti langkah (sumbu Y). Ini pasangan dari
		-- putaran torso di bawah: manusia berlari dengan bahu dan pinggul
		-- berlawanan arah, dan tanpa itu badan atas terlihat kaku seperti
		-- papan yang kakinya digerakkan dari bawah.
		Root = j(0, s * 0.07 * amp, s * 0.04 * amp, math.abs(c) * 0.09 * amp),

		-- Condong ke depan sebanding kecepatan. Ini yang paling membuat lari
		-- terbaca sebagai lari dan bukan berjalan cepat. Sumbu Y-nya memutar
		-- torso berlawanan dengan pinggul.
		Waist = j(-0.17 * amp, -s * 0.13 * amp, 0),
		-- Leher melawan condongnya badan DAN melawan putaran torso, supaya
		-- kepala tetap menghadap ke arah lari. Kepala yang ikut berputar
		-- bersama bahu membuat pemain terlihat celingukan sambil berlari.
		Neck = j(0.13 * amp, s * 0.1 * amp, 0),

		-- Lengan berlawanan fase dengan kaki di sisi yang sama: kaki kanan
		-- maju bersamaan dengan lengan kiri maju. Itu cara manusia berjalan,
		-- dan kalau dibuat sefase hasilnya langsung terlihat aneh.
		LeftShoulder = j(s * 0.72 * amp * SWING_SIGN, 0, -(REST_SHOULDER_SPREAD + 0.1 * amp)),
		RightShoulder = j(-s * 0.72 * amp * SWING_SIGN, 0, REST_SHOULDER_SPREAD + 0.1 * amp),
		LeftElbow = j((REST_ELBOW + (0.58 + 0.2 * math.abs(s)) * amp) * SWING_SIGN, 0, 0),
		RightElbow = j((REST_ELBOW + (0.58 + 0.2 * math.abs(s)) * amp) * SWING_SIGN, 0, 0),

		LeftHip = j(leftHip * SWING_SIGN, 0, 0),
		RightHip = j(rightHip * SWING_SIGN, 0, 0),
		LeftKnee = j(leftKnee * SWING_SIGN, 0, 0),
		RightKnee = j(rightKnee * SWING_SIGN, 0, 0),
		LeftAnkle = j(leftAnkle * SWING_SIGN, 0, 0),
		RightAnkle = j(rightAnkle * SWING_SIGN, 0, 0),
	}
end

-- --------------------------------------------------------------------------
-- crouch, jongkok
-- --------------------------------------------------------------------------
--
-- Roblox tidak punya klip jongkok, jadi inilah satu-satunya tindakan yang
-- diminta Soal 4 yang memang WAJIB dibuat sendiri, bagaimanapun caranya.
--
-- SUDUTNYA DIHITUNG, BUKAN DIKIRA-KIRA. Menurunkan badan lewat `Root` saja
-- akan menenggelamkan kaki ke dalam lantai, karena kaki menempel pada torso
-- bawah dan ikut turun bersamanya. Yang benar: pinggul dan lutut menekuk
-- sehingga telapak kaki NAIK terhadap torso, sebanyak badan diturunkan.
--
-- Dengan panjang paha dan betis masing-masing sekitar 2.2 stud, menekuk
-- pinggul sebesar t dan lutut sebesar -2t menaikkan telapak kaki kira-kira
-- sebesar 2 * 2.2 * (1 - cos t). Untuk t = 0.9 radian hasilnya 1.67 stud,
-- dan itulah sebabnya `Root` diturunkan 1.6, bukan angka yang terasa enak
-- dilihat. Ketiganya harus berubah bersama; mengubah salah satu saja membuat
-- karakter melayang atau terbenam.
local CROUCH_HIP = 0.9
local CROUCH_DROP = -1.6

local function crouch(phase: number, amp: number): Pose
	local b = math.sin(phase * TAU)
	-- Saat jongkok sambil bergerak, kaki tetap melangkah, amplitudonya kecil
	-- karena langkah jongkok memang pendek.
	local step = math.sin(phase * TAU) * 0.3 * amp

	return {
		Root = j(0, 0, 0, CROUCH_DROP + b * 0.02),
		-- Badan condong ke depan menyeimbangkan pinggul yang mundur. Tanpa ini
		-- karakter terlihat duduk di kursi tak terlihat, bukan berjongkok.
		Waist = j(-0.42 + b * 0.01, 0, 0),
		Neck = j(0.34, 0, 0),

		LeftShoulder = j((-0.1 + step) * SWING_SIGN, 0, -0.22),
		RightShoulder = j((-0.1 - step) * SWING_SIGN, 0, 0.22),
		LeftElbow = j(0.95 * SWING_SIGN, 0, 0),
		RightElbow = j(0.95 * SWING_SIGN, 0, 0),

		LeftHip = j((CROUCH_HIP - step) * SWING_SIGN, 0, 0),
		RightHip = j((CROUCH_HIP + step) * SWING_SIGN, 0, 0),
		LeftKnee = j(-CROUCH_HIP * 2 * SWING_SIGN, 0, 0),
		RightKnee = j(-CROUCH_HIP * 2 * SWING_SIGN, 0, 0),
		-- Pergelangan mengimbangi sisa kemiringan supaya telapak tetap datar
		-- di lantai, bukan berjinjit.
		LeftAnkle = j(CROUCH_HIP * SWING_SIGN, 0, 0),
		RightAnkle = j(CROUCH_HIP * SWING_SIGN, 0, 0),
	}
end

-- --------------------------------------------------------------------------
-- dash, lesatan pendek
-- --------------------------------------------------------------------------
--
-- Cuma tampil 0.22 detik, jadi yang penting SILUETNYA, bukan kehalusannya:
-- badan rendah ke depan, satu kaki menjejak di belakang, kedua lengan tersapu
-- ke belakang. Dalam waktu sesingkat itu mata cuma sempat menangkap bentuk.
local function dash(): Pose
	return {
		Root = j(0, 0, 0, -0.5),
		Waist = j(-0.62, 0, 0),
		Neck = j(0.5, 0, 0),

		-- Lengan ke belakang, bukan ke depan: itu bentuk tubuh yang dibaca
		-- orang sebagai "melesat", bukan "mendorong".
		LeftShoulder = j(-0.95 * SWING_SIGN, 0, -0.35),
		RightShoulder = j(-0.95 * SWING_SIGN, 0, 0.35),
		LeftElbow = j(0.3 * SWING_SIGN, 0, 0),
		RightElbow = j(0.3 * SWING_SIGN, 0, 0),

		LeftHip = j(0.95 * SWING_SIGN, 0, 0),
		RightHip = j(-0.75 * SWING_SIGN, 0, 0),
		LeftKnee = j(-1.15 * SWING_SIGN, 0, 0),
		RightKnee = j(-0.35 * SWING_SIGN, 0, 0),
		LeftAnkle = j(0.25 * SWING_SIGN, 0, 0),
		RightAnkle = j(0.45 * SWING_SIGN, 0, 0),
	}
end

-- --------------------------------------------------------------------------
-- jump, fase naik
-- --------------------------------------------------------------------------
--
-- Dipisah dari `fall` karena bentuk tubuhnya memang berbeda, bukan sekadar
-- supaya ada dua state: saat naik lutut ditarik ke dada, saat jatuh kaki
-- terjulur mencari pijakan. Satu pose untuk keduanya membuat lompatan terlihat
-- menggantung.
local function jump(): Pose
	return {
		Root = j(0, 0, 0, 0),
		Waist = j(-0.12, 0, 0),
		Neck = j(0.1, 0, 0),

		LeftShoulder = j(-0.42 * SWING_SIGN, 0, -0.9),
		RightShoulder = j(-0.42 * SWING_SIGN, 0, 0.9),
		LeftElbow = j(0.8 * SWING_SIGN, 0, 0),
		RightElbow = j(0.8 * SWING_SIGN, 0, 0),

		LeftHip = j(0.55 * SWING_SIGN, 0, 0),
		RightHip = j(0.5 * SWING_SIGN, 0, 0),
		LeftKnee = j(-1.0 * SWING_SIGN, 0, 0),
		RightKnee = j(-0.9 * SWING_SIGN, 0, 0),
		LeftAnkle = j(0.2 * SWING_SIGN, 0, 0),
		RightAnkle = j(0.2 * SWING_SIGN, 0, 0),
	}
end

-- --------------------------------------------------------------------------
-- fall, melayang turun
-- --------------------------------------------------------------------------
local function fall(): Pose
	return {
		Root = j(0, 0, 0, 0),
		Waist = j(0.08, 0, 0),
		Neck = j(-0.06, 0, 0),

		LeftShoulder = j(-0.12 * SWING_SIGN, 0, -1.25),
		RightShoulder = j(-0.12 * SWING_SIGN, 0, 1.25),
		LeftElbow = j(0.35 * SWING_SIGN, 0, 0),
		RightElbow = j(0.35 * SWING_SIGN, 0, 0),

		LeftHip = j(0.24 * SWING_SIGN, 0, 0),
		RightHip = j(0.1 * SWING_SIGN, 0, 0),
		LeftKnee = j(-0.45 * SWING_SIGN, 0, 0),
		RightKnee = j(-0.2 * SWING_SIGN, 0, 0),
		LeftAnkle = j(0, 0, 0),
		RightAnkle = j(0, 0, 0),
	}
end

-- --------------------------------------------------------------------------
-- Serangan: lapisan di ATAS pose yang sedang berjalan
-- --------------------------------------------------------------------------
--
-- Berbeda dari enam state di atas, ini BUKAN pose utuh. Yang dikembalikan cuma
-- sendi yang benar-benar dipakai menyerang; sisanya dibiarkan apa adanya.
--
-- Alasannya: menyerang tidak membatalkan apa yang sedang dilakukan pemain.
-- Seseorang bisa menembak sambil berlari, dan kalau serangan mengembalikan
-- pose utuh, kakinya akan berhenti melangkah setiap kali dia menembak,
-- empat kali per detik dengan Packet Rifle.
--
-- `t` berjalan 0..1 sepanjang satu gerakan.

-- Durasi tiap jenis serangan, dalam detik. Jarak dekat lebih lama karena
-- ayunan memang perjalanan; jarak jauh pendek karena yang digambarkan cuma
-- hentakan laras.
Poses.ATTACK_DURATION = {
	melee = 0.36,
	ranged = 0.2,
} :: { [string]: number }

local function attackMelee(t: number): Pose
	-- Dua fase. Ayunan yang kecepatannya rata terlihat seperti lengan yang
	-- didorong, bukan diayunkan: tenaga ada pada perbedaan kecepatan antara
	-- tarikan ke belakang yang lambat dan hentakan ke depan yang cepat.
	local windup = math.clamp(t / 0.35, 0, 1)
	local swing = math.clamp((t - 0.35) / 0.65, 0, 1)

	-- Pangkat tiga pada hentakan: nyaris diam di awal lalu melesat di akhir.
	local strike = swing * swing * swing
	local raise = windup * (1 - swing)

	return {
		RightShoulder = j((-1.5 * raise + 1.35 * strike) * SWING_SIGN, 0, 0.3 + 0.35 * raise),
		RightElbow = j((1.5 * raise + 0.15) * SWING_SIGN, 0, 0),
		LeftShoulder = j((0.3 * raise - 0.45 * strike) * SWING_SIGN, 0, -0.3),
		LeftElbow = j((0.7 + 0.3 * raise) * SWING_SIGN, 0, 0),
		-- Badan ikut berputar sedikit. Ayunan yang cuma melibatkan lengan
		-- terlihat seperti mengibaskan tangan.
		Waist = j(-0.12 * strike, (0.3 * raise - 0.35 * strike) * SWING_SIGN, 0),
	}
end

local function attackRanged(t: number): Pose
	-- Hentakan naik cepat lalu turun pelan: itu bentuk recoil. Dibalik,
	-- naik pelan turun cepat, gerakannya terbaca sebagai mengangkat senjata,
	-- bukan sebagai senjata yang menendang.
	local kick = if t < 0.25 then t / 0.25 else 1 - (t - 0.25) / 0.75

	return {
		-- Kedua lengan terangkat ke depan membidik, dan tetap begitu sepanjang
		-- gerakan; yang berubah cuma hentakannya.
		RightShoulder = j((-1.25 - 0.3 * kick) * SWING_SIGN, 0, 0.18),
		RightElbow = j((0.55 + 0.25 * kick) * SWING_SIGN, 0, 0),
		LeftShoulder = j((-1.15 - 0.2 * kick) * SWING_SIGN, 0, -0.42),
		LeftElbow = j((0.85 + 0.2 * kick) * SWING_SIGN, 0, 0),
		Waist = j(-0.08 - 0.12 * kick, 0, 0),
		Neck = j(0.1 + 0.08 * kick, 0, 0),
	}
end

-- `t` dijepit di sini, sama seperti `amp` di `solve`: pemanggil yang salah
-- hitung tidak boleh bisa menghasilkan sudut di luar rancangan.
function Poses.attack(kind: string, t: number): Pose
	local clamped = math.clamp(t, 0, 1)
	if kind == "ranged" then
		return attackRanged(clamped)
	end
	return attackMelee(clamped)
end

function Poses.attackDuration(kind: string): number
	return Poses.ATTACK_DURATION[kind] or Poses.ATTACK_DURATION.melee
end

-- --------------------------------------------------------------------------
-- Mendarat: lapisan di atas pose, seperti serangan
-- --------------------------------------------------------------------------
--
-- Tanpa ini, lompatan berakhir dengan karakter yang tiba-tiba berdiri tegak di
-- frame berikutnya setelah menyentuh lantai. Mata menangkapnya sebagai gerakan
-- yang terpotong, bukan sebagai pendaratan, dan inilah satu dari dua hal
-- (bersama kaki yang menggeser) yang paling membedakan lompatan yang terasa
-- berbobot dari yang terasa seperti karakter ditarik tali.
--
-- `t` berjalan 0..1. `strength` 0..1 ikut kecepatan jatuh: turun dari platform
-- setinggi 6 stud harus terlihat lebih berat daripada melompat di tempat.
Poses.LAND_DURATION = 0.3

local function easeOutBack(t: number): number
	-- Naik cepat, melewati sasaran sedikit, lalu kembali. Itu yang membuat
	-- badan terlihat memantul balik setelah menekuk, bukan sekadar lurus lagi.
	local inverted = 1 - t
	return 1 - (inverted * inverted * (1 + 1.6 * inverted) - 0.6 * inverted)
end

function Poses.land(t: number, strength: number): Pose
	local clampedT = math.clamp(t, 0, 1)
	local power = math.clamp(strength, 0, 1)

	-- Tekukan paling dalam di awal, lalu pulih.
	local depth = (1 - easeOutBack(clampedT)) * power

	return {
		Root = j(0, 0, 0, -1.1 * depth),
		Waist = j(-0.4 * depth, 0, 0),
		Neck = j(0.3 * depth, 0, 0),
		LeftHip = j(0.75 * depth * SWING_SIGN, 0, 0),
		RightHip = j(0.75 * depth * SWING_SIGN, 0, 0),
		LeftKnee = j(-1.5 * depth * SWING_SIGN, 0, 0),
		RightKnee = j(-1.5 * depth * SWING_SIGN, 0, 0),
		LeftAnkle = j(0.75 * depth * SWING_SIGN, 0, 0),
		RightAnkle = j(0.75 * depth * SWING_SIGN, 0, 0),
	}
end

-- --------------------------------------------------------------------------
-- Condong mengikuti arah gerak
-- --------------------------------------------------------------------------
--
-- Bukan pose, melainkan dua angka yang DITAMBAHKAN ke pose yang sedang
-- berjalan. Pemain yang berlari ke samping sambil menghadap depan, yang
-- terjadi sepanjang waktu di game ini, karena arah hadap ditentukan bidikan
-- dan arah lari ditentukan tombol, akan terlihat meluncur menyamping tanpa
-- condong sama sekali. Condongnya yang memberi tahu mata bahwa dia sedang
-- berpindah, bukan digeser.
--
-- `forward` dan `lateral` adalah kecepatan ternormalisasi -1..1 pada sumbu
-- badan: +forward maju, +lateral ke kanan.
function Poses.lean(forward: number, lateral: number): (number, number)
	local f = math.clamp(forward, -1, 1)
	local l = math.clamp(lateral, -1, 1)
	-- Condong ke samping jauh lebih kecil daripada ke depan: badan yang miring
	-- berlebihan saat bergerak menyamping terlihat seperti kehilangan
	-- keseimbangan.
	return -f * 0.1, -l * 0.13
end

-- --------------------------------------------------------------------------
-- Pintu masuk
-- --------------------------------------------------------------------------
--
-- `phase` berputar 0..1 dan BOLEH melewati 1; sinus mengurusnya sendiri, jadi
-- pemanggil tidak perlu membungkusnya. `amp` dijepit di sini, bukan di
-- pemanggil, supaya kecepatan yang aneh (karakter terlempar ledakan) tidak
-- pernah bisa menghasilkan sudut sendi di luar rancangan.
function Poses.solve(state: string, phase: number, amp: number, swing: number?): Pose
	local clamped = math.clamp(amp, 0, 1)
	-- Sudut ayun bawaan dipakai kalau pemanggil tidak menghitungnya sendiri
	-- lewat `Poses.gait`. Dipertahankan supaya pose bisa dilihat pada satu
	-- amplitudo tanpa perlu memilih kecepatan, dipakai test dan alat bantu.
	local hipSwing = swing or (HIP_SWING * clamped)

	if state == "run" then
		return run(phase, clamped, hipSwing)
	elseif state == "crouch" then
		return crouch(phase, clamped)
	elseif state == "dash" then
		return dash()
	elseif state == "jump" then
		return jump()
	elseif state == "fall" then
		return fall()
	end
	return idle(phase)
end

-- Dipakai test. Dua hal yang dijaga, dan dua-duanya pernah jadi bug nyata saat
-- pose ditambah dengan menyalin blok yang sudah ada:
--   1. tiap state mengisi SEMUA sendi di `Poses.JOINTS`. Sendi yang terlewat
--      tidak error, dia cuma tertinggal di pose state sebelumnya dan
--      karakternya terlihat patah saat berpindah tindakan.
--   2. tiap entri berisi tepat enam angka.
function Poses.validate(): (boolean, string?)
	for _, state in Poses.STATES do
		local pose = Poses.solve(state, 0.25, 1)
		for _, joint in Poses.JOINTS do
			local entry = pose[joint]
			if entry == nil then
				return false, string.format("state %s tidak mengisi sendi %s", state, joint)
			end
			if #entry ~= 6 then
				return false,
					string.format(
						"state %s sendi %s berisi %d angka, harus 6",
						state,
						joint,
						#entry
					)
			end
			for index, value in entry do
				if value ~= value then
					return false,
						string.format(
							"state %s sendi %s angka ke-%d bukan bilangan",
							state,
							joint,
							index
						)
				end
			end
		end
	end
	return true, nil
end

return Poses
