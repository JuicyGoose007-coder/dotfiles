--- @sync entry
-- `l` enters directories and opens files (with the [opener] rules, so nvim for text).
return {
	entry = function()
		local h = cx.active.current.hovered
		ya.emit(h and h.cha.is_dir and "enter" or "open", { hovered = true })
	end,
}
