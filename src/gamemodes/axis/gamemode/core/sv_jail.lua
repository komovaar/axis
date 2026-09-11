local CHAR = axis.char.meta

---@param releaseAt number absolute unix timestamp
---@param reason string?
function CHAR:SetJail(releaseAt, reason)
    self.jailUntil = math.max(0, math.floor(releaseAt or 0))
    self.jailReason = reason

    self:MarkDirty()

    local ply = self:GetPlayer()

    if IsValid(ply) then
        ply:SetNW2Int("axisJailUntil", self.jailUntil)
        ply:SetNW2String("axisJailReason", reason or "")
    end
end

--- Teleports to a jail spawnpoint for the player's faction, falling back to any
--- jail point on the map so a half-configured server still contains prisoners.
---@param ply Player
function axis.jail.SendToCell(ply)
    local point = axis.spawn.PickFor(ply, axis.spawn.KIND_JAIL)

    if not point then
        for _, candidate in pairs(axis.spawn.GetAll()) do
            if candidate.kind == axis.spawn.KIND_JAIL then
                point = candidate
                break
            end
        end
    end

    if not point then
        axis.LogError("no jail spawnpoint on %s - %s cannot be confined", game.GetMap(), ply:Nick())
        return false
    end

    ply:SetPos(point.pos)
    ply:SetEyeAngles(point.ang)

    return true
end

--- Everything that must be true while a sentence is running, applied both on
--- arrest and on a mid-sentence reconnect.
---@param ply Player
local function ApplyRestrictions(ply)
    ply:StripWeapons()
    ply:StripAmmo()
    ply:SetMoveType(MOVETYPE_WALK)
    axis.jail.SendToCell(ply)

    local remaining = axis.jail.GetRemaining(ply)

    timer.Create("AxisJail" .. ply:SteamID64(), remaining, 1, function()
        if IsValid(ply) then axis.jail.Release(ply, true) end
    end)
end

---@param ply Player
---@param seconds number
---@param reason string?
---@param arrester Player?
---@return boolean, string? err
function axis.jail.Arrest(ply, seconds, reason, arrester)
    local char = ply:GetCharacter()
    if not char then return false, "That player has no active character." end

    if seconds <= 0 then return false, "A sentence must be longer than zero." end

    char:SetJail(os.time() + seconds, reason)
    char:Save()

    ApplyRestrictions(ply)

    local reasonText = reason and reason ~= "" and (" for " .. reason) or ""

    axis.chat.Send(nil,
        axis.config.color.error, "[Jail] ",
        color_white, ply,
        color_white, " has been arrested for " .. axis.jail.FormatTime(seconds) .. reasonText .. ".")

    hook.Run("AxisPlayerArrested", ply, seconds, reason, arrester)

    return true
end

---@param ply Player
---@param served boolean? true when the sentence expired rather than being lifted
function axis.jail.Release(ply, served)
    local char = ply:GetCharacter()
    if not char then return end

    char:SetJail(0, nil)
    char:Save()

    timer.Remove("AxisJail" .. ply:SteamID64())

    if IsValid(ply) then
        ply:Spawn()

        axis.chat.Send(nil,
            axis.config.color.success, "[Jail] ",
            color_white, ply,
            color_white, served and " has served their sentence." or " has been released.")
    end

    hook.Run("AxisPlayerReleased", ply, served)
end

--- A sentence outlives the session, so re-apply it as soon as the character is
--- back in play.
hook.Add("AxisCharacterLoaded", "AxisJailRestore", function(ply, char)
    ply:SetNW2Int("axisJailUntil", char:GetJailUntil())
    ply:SetNW2String("axisJailReason", char:GetJailReason() or "")

    if axis.jail.GetRemaining(ply) > 0 then
        ApplyRestrictions(ply)

        axis.chat.Notify(ply, "error", "You are still serving " ..
            axis.jail.FormatTime(axis.jail.GetRemaining(ply)) .. " of your sentence.")
    else
        char:SetJail(0, nil)
    end
end)

hook.Add("AxisPlayerSpawned", "AxisJailReconfine", function(ply)
    if axis.jail.GetRemaining(ply) > 0 then
        timer.Simple(0, function()
            if IsValid(ply) then ApplyRestrictions(ply) end
        end)
    end
end)

hook.Add("PlayerCanPickupWeapon", "AxisJailNoWeapons", function(ply)
    if axis.jail.IsJailed(ply) then return false end
end)

hook.Add("PlayerNoClip", "AxisJailNoClip", function(ply)
    if axis.jail.IsJailed(ply) then return false end
end)

hook.Add("CanPlayerSuicide", "AxisJailNoSuicide", function(ply)
    if axis.jail.IsJailed(ply) then return false end
end)

hook.Add("PlayerDisconnected", "AxisJailCleanup", function(ply)
    timer.Remove("AxisJail" .. ply:SteamID64())
end)
