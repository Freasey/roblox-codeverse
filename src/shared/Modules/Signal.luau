--!strict
-- Signal.luau — implementasi sinyal minimal.
--
-- Kenapa tidak BindableEvent: BindableEvent menyalin argumennya lewat batas
-- Instance, jadi tabel yang dikirim bukan tabel yang sama lagi. Untuk
-- PlayerDataService.onLoaded kita justru ingin mengoper referensi data yang
-- asli. Kenapa tidak Wally: satu file 60 baris tidak sebanding dengan
-- menambah dependensi dan langkah `wally install` ke semua orang.

export type Connection = {
	Disconnect: (self: Connection) -> (),
}

type Handler<T...> = (T...) -> ()

local Signal = {}
Signal.__index = Signal

export type Signal<T...> = typeof(setmetatable(
	{} :: {
		_handlers: { Handler<T...> },
	},
	Signal
))

function Signal.new<T...>(): Signal<T...>
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal.Connect<T...>(self: Signal<T...>, handler: Handler<T...>): Connection
	table.insert(self._handlers, handler)
	return {
		Disconnect = function()
			local index = table.find(self._handlers, handler)
			if index then
				table.remove(self._handlers, index)
			end
		end,
	}
end

-- Handler dijalankan di thread terpisah supaya satu handler yang error atau
-- yield tidak menghentikan yang lain, dan tidak menahan pemanggil Fire.
function Signal.Fire<T...>(self: Signal<T...>, ...: T...)
	for _, handler in table.clone(self._handlers) do
		task.spawn(handler, ...)
	end
end

function Signal.DisconnectAll<T...>(self: Signal<T...>)
	table.clear(self._handlers)
end

return Signal
