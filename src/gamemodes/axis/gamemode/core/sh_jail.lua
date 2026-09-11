axis.jail = axis.jail or {}

--- Sentences are absolute timestamps rather than remaining seconds, so the clock
--- keeps running while a player is disconnected and a server restart is
--- invisible to it.
---@param ply Player
---@return boolean
function axis.jail.IsJailed(ply)
    return axis.jail.GetRemaining(ply) > 0
end

---@param ply Player
---@return number seconds
function axis.jail.GetRemaining(ply)
    if not IsValid(ply) then return 0 end

    local releaseAt

    if SERVER then
        local char = ply:GetCharacter()
        releaseAt = char and char:GetJailUntil() or 0
    else
        releaseAt = ply:GetNW2Int("axisJailUntil", 0)
    end

    return math.max(0, releaseAt - os.time())
end

---@param ply Player
---@return string
function axis.jail.GetReason(ply)
    if SERVER then
        local char = ply:GetCharacter()
        return char and char:GetJailReason() or ""
    end

    return ply:GetNW2String("axisJailReason", "")
end

---@param seconds number
---@return string
function axis.jail.FormatTime(seconds)
    seconds = math.max(0, math.floor(seconds))

    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)

    if hours > 0 then
        return string.format("%dh %02dm %02ds", hours, minutes, seconds % 60)
    end

    return string.format("%02d:%02d", minutes, seconds % 60)
end
