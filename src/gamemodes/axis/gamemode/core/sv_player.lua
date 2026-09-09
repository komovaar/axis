--- Loadout is composed, not replaced: the class provides the base kit and the
--- rank appends to it, so a Sergeant Medic keeps the medic gear and gains the
--- sergeant extras.
---@param ply Player
---@return boolean
function GM:PlayerLoadout(ply)
    ply:StripWeapons()
    ply:StripAmmo()

    local char = ply:GetCharacter()
    if not char then return true end

    local class = char:GetClassTable()
    local rank = char:GetRankTable()

    if class then
        ply:SetMaxHealth(class.health)
        ply:SetHealth(class.health)
        ply:SetArmor(class.armor)

        if class.walkSpeed then ply:SetWalkSpeed(class.walkSpeed) end
        if class.runSpeed then ply:SetRunSpeed(class.runSpeed) end

        for _, weapon in ipairs(class.weapons) do ply:Give(weapon) end
    end

    if rank and rank.weapons then
        for _, weapon in ipairs(rank.weapons) do ply:Give(weapon) end
    end

    hook.Run("AxisPlayerLoadout", ply, char)

    return true
end

--- Model precedence: the rank's override, then the character's own choice, then
--- the class default. The old implementation assumed data.model existed and
--- errored on any job without one.
---@param ply Player
function GM:PlayerSetModel(ply)
    local char = ply:GetCharacter()

    if not char then
        ply:SetModel("models/player/kleiner.mdl")
        return
    end

    local rank = char:GetRankTable()
    local class = char:GetClassTable()

    local model = (rank and rank.model)
        or char:GetModel()
        or (class and class.models[1])
        or "models/player/kleiner.mdl"

    ply:SetModel(model)
end

--- Players without a character are held in a frozen, invisible body until they
--- pick one. Deliberately NOT Spectate(): putting the player into observer mode
--- on the initial spawn can leave the client sitting on the loading screen
--- forever, because it never gets a normal local player to finish spawning on.
---@param ply Player
function GM:PlayerSpawn(ply)
    self.BaseClass:PlayerSpawn(ply)

    if not ply:HasCharacter() then
        ply:SetTeam(TEAM_UNASSIGNED)
        ply:StripWeapons()
        ply:SetNoDraw(true)
        ply:SetNotSolid(true)
        ply:Lock()

        return
    end

    ply:UnLock()
    ply:SetNoDraw(false)
    ply:SetNotSolid(false)
    ply:SetMoveType(MOVETYPE_WALK)

    axis.spawn.Apply(ply)

    hook.Run("AxisPlayerSpawned", ply, ply:GetCharacter())
end

--- Faction is the team index, so the stock team-based friendly fire rule is
--- exactly what we want: same faction cannot damage each other.
---@param ply Player
---@param attacker Entity
---@return boolean?
function GM:PlayerShouldTakeDamage(ply, attacker)
    if not attacker:IsPlayer() then return true end
    if attacker == ply then return true end

    local a, b = ply:GetFaction(), attacker:GetFaction()
    if a and b and a == b then return false end

    return true
end

---@param ply Player
function GM:PlayerDeathThink(ply)
    if not ply:HasCharacter() then return false end

    return self.BaseClass:PlayerDeathThink(ply)
end

--- Sandbox's spawn menu and toolgun have no place for a player without a
--- character, and jail restrictions hang off the same idea.
---@param ply Player
---@return boolean
function GM:PlayerSpawnObject(ply)
    return ply:HasCharacter() and not axis.jail.IsJailed(ply)
end

GM.PlayerSpawnProp = GM.PlayerSpawnObject
GM.PlayerSpawnSENT = GM.PlayerSpawnObject
GM.PlayerSpawnNPC = GM.PlayerSpawnObject
GM.PlayerSpawnSWEP = GM.PlayerSpawnObject
GM.PlayerSpawnVehicle = GM.PlayerSpawnObject
GM.PlayerSpawnEffect = GM.PlayerSpawnObject
GM.PlayerSpawnRagdoll = GM.PlayerSpawnObject
