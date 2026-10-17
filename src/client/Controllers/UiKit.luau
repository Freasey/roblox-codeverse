--!strict
-- UiKit.luau — pembuat Instance UI yang dipakai semua controller.
--
-- Kenapa UI dibangun dari kode, bukan dari file .rbxmx: seluruh UI harus bisa
-- di-review di git dan di-edit tanpa Studio. Berbeda dengan geometry arena yang
-- memang perlu dilihat dalam 3D, layout UI 2D sama jelasnya dibaca sebagai kode
-- dan jauh lebih mudah diubah.
--
-- Semua angka di sini murni presentasi. JANGAN taruh angka balancing di file
-- ini — itu milik Balance.luau, dan client tidak boleh jadi sumber kebenaran
-- untuk apa pun.

local UiKit = {}

UiKit.COLOR_BG = Color3.fromRGB(22, 24, 30)
UiKit.COLOR_PANEL = Color3.fromRGB(32, 35, 44)
UiKit.COLOR_TEXT = Color3.fromRGB(235, 238, 245)
UiKit.COLOR_MUTED = Color3.fromRGB(150, 157, 172)
UiKit.COLOR_ACCENT = Color3.fromRGB(90, 170, 240)
UiKit.COLOR_GOOD = Color3.fromRGB(90, 210, 120)
UiKit.COLOR_WARN = Color3.fromRGB(240, 195, 70)
UiKit.COLOR_BAD = Color3.fromRGB(235, 85, 85)

function UiKit.screenGui(name: string, displayOrder: number): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = displayOrder
	return gui
end

function UiKit.panel(parent: Instance, name: string, position: UDim2, size: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = UiKit.COLOR_PANEL
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	return frame
end

function UiKit.label(
	parent: Instance,
	name: string,
	position: UDim2,
	size: UDim2,
	text: string
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = UiKit.COLOR_TEXT
	label.TextScaled = false
	label.TextSize = 16
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = parent
	return label
end

function UiKit.button(
	parent: Instance,
	name: string,
	position: UDim2,
	size: UDim2,
	text: string
): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = position
	button.Size = size
	button.BackgroundColor3 = UiKit.COLOR_ACCENT
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = Color3.fromRGB(16, 18, 24)
	button.TextSize = 15
	button.Text = text
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button

	return button
end

-- Tombol dinonaktifkan secara visual DAN fungsional. Dua-duanya perlu:
-- `Active = false` saja masih terlihat seperti tombol yang bisa diklik, dan
-- hanya menggelapkan warna membuat klik tetap mengirim remote yang pasti
-- ditolak server.
function UiKit.setButtonEnabled(button: TextButton, enabled: boolean)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundColor3 = if enabled then UiKit.COLOR_ACCENT else Color3.fromRGB(70, 74, 84)
	button.TextColor3 = if enabled
		then Color3.fromRGB(16, 18, 24)
		else Color3.fromRGB(140, 145, 155)
end

export type Bar = {
	root: Frame,
	fill: Frame,
	text: TextLabel,
}

function UiKit.bar(parent: Instance, name: string, position: UDim2, size: UDim2): Bar
	local root = Instance.new("Frame")
	root.Name = name
	root.Position = position
	root.Size = size
	root.BackgroundColor3 = Color3.fromRGB(16, 17, 22)
	root.BorderSizePixel = 0
	root.Parent = parent

	local rootCorner = Instance.new("UICorner")
	rootCorner.CornerRadius = UDim.new(0, 4)
	rootCorner.Parent = root

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = UiKit.COLOR_GOOD
	fill.BorderSizePixel = 0
	fill.Parent = root

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fill

	local text = UiKit.label(root, "Text", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), "")
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.TextSize = 13
	text.ZIndex = 2

	return { root = root, fill = fill, text = text }
end

function UiKit.setBar(bar: Bar, value: number, maxValue: number, text: string?)
	local fraction = if maxValue > 0 then math.clamp(value / maxValue, 0, 1) else 0
	bar.fill.Size = UDim2.fromScale(fraction, 1)
	bar.fill.BackgroundColor3 = if fraction > 0.5
		then UiKit.COLOR_GOOD
		elseif fraction > 0.25 then UiKit.COLOR_WARN
		else UiKit.COLOR_BAD
	bar.text.Text = text or string.format("%d / %d", math.floor(value + 0.5), math.floor(maxValue))
end

function UiKit.verticalList(parent: Instance, padding: number): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, padding)
	layout.Parent = parent
	return layout
end

return UiKit
