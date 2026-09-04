require("full-border"):setup()
require("git"):setup({ order = 1500 })

-- Superfile keeps a clipboard panel and a process panel on screen. Yazi has
-- no sidebar, so the counts live in the status bar and stay hidden when
-- there is nothing to report.

-- A status child that throws stops yazi drawing the parent and current
-- panes entirely, so every reader of cx is behind a pcall.
local function guarded(fn)
	return function()
		local ok, res = pcall(fn)
		return ok and res or ""
	end
end

Status:children_add(guarded(function()
	local n = #cx.yanked
	if n == 0 then
		return ""
	end
	local cut = cx.yanked.is_cut
	return ui.Line({
		ui.Span((cut and " cut " or " yank ") .. n .. " "):fg(cut and "red" or "green"),
	})
end), 2000, Status.RIGHT)

-- 26.9.1 exposes cx.tasks.summary { total, success, failed }. The older
-- cx.tasks.progress is gone; reading it is what broke the layout.
Status:children_add(guarded(function()
	local s = cx.tasks.summary
	local running = s.total - s.success - s.failed
	if running <= 0 and s.failed == 0 then
		return ""
	end
	local text = " " .. running .. "/" .. s.total
	if s.failed > 0 then
		text = text .. " !" .. s.failed
	end
	return ui.Line({
		ui.Span(text .. " "):fg(s.failed > 0 and "red" or "yellow"),
	})
end), 2100, Status.RIGHT)
