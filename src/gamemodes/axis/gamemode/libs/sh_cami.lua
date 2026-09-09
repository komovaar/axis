--- CAMI - Common Admin Mod Interface.
--- A shared contract between admin mods and the addons that need to ask them
--- questions. Bundled so Axis works on a bare server; if an admin mod ships a
--- newer copy it wins the version check below and this file does nothing.
local version = 1.2

if CAMI and CAMI.Version >= version then return end

CAMI = CAMI or {}
CAMI.Version = version

---@class CAMI_USERGROUP
---@field Name string
---@field Inherits string

---@class CAMI_PRIVILEGE
---@field Name string
---@field MinAccess "user"|"admin"|"superadmin"
---@field Description string?
---@field HasAccess fun(privilege: CAMI_PRIVILEGE, actor: Player, target: Player?): boolean?

local usergroups = CAMI.GetUsergroups and CAMI.GetUsergroups() or {
    user = { Name = "user", Inherits = "user", CAMI_Source = "CAMI" },
    admin = { Name = "admin", Inherits = "user", CAMI_Source = "CAMI" },
    superadmin = { Name = "superadmin", Inherits = "admin", CAMI_Source = "CAMI" },
}

local privileges = CAMI.GetPrivileges and CAMI.GetPrivileges() or {}

---@param usergroup CAMI_USERGROUP
---@param source any
---@return CAMI_USERGROUP
function CAMI.RegisterUsergroup(usergroup, source)
    usergroups[usergroup.Name] = usergroup
    usergroup.CAMI_Source = source

    hook.Call("CAMI.OnUsergroupRegistered", nil, usergroup, source)

    return usergroup
end

---@param usergroupName string
---@param source any
---@return boolean
function CAMI.UnregisterUsergroup(usergroupName, source)
    if not usergroups[usergroupName] then return false end

    local usergroup = usergroups[usergroupName]
    usergroups[usergroupName] = nil

    hook.Call("CAMI.OnUsergroupUnregistered", nil, usergroup, source)

    return true
end

---@return table<string, CAMI_USERGROUP>
function CAMI.GetUsergroups()
    return usergroups
end

---@param usergroupName string
---@return CAMI_USERGROUP?
function CAMI.GetUsergroup(usergroupName)
    return usergroups[usergroupName]
end

---@param usergroupName string
---@param potentialAncestor string
---@return boolean
function CAMI.UsergroupInherits(usergroupName, potentialAncestor)
    repeat
        if usergroupName == potentialAncestor then return true end

        local usergroup = usergroups[usergroupName]
        usergroupName = usergroup and usergroup.Inherits or usergroupName
    until not usergroups[usergroupName] or usergroups[usergroupName].Inherits == usergroupName

    -- Every usergroup ultimately inherits from user
    return usergroupName == potentialAncestor or potentialAncestor == "user"
end

---@param usergroupName string
---@return string
function CAMI.InheritanceRoot(usergroupName)
    if not usergroups[usergroupName] then return "user" end

    local inherits = usergroups[usergroupName].Inherits

    while inherits ~= usergroups[usergroupName].Name do
        usergroupName = usergroups[usergroupName].Inherits
        inherits = usergroups[usergroupName] and usergroups[usergroupName].Inherits or "user"
    end

    return usergroupName
end

---@param privilege CAMI_PRIVILEGE
---@return CAMI_PRIVILEGE
function CAMI.RegisterPrivilege(privilege)
    privileges[privilege.Name] = privilege

    hook.Call("CAMI.OnPrivilegeRegistered", nil, privilege)

    return privilege
end

---@param privilegeName string
---@return boolean
function CAMI.UnregisterPrivilege(privilegeName)
    if not privileges[privilegeName] then return false end

    local privilege = privileges[privilegeName]
    privileges[privilegeName] = nil

    hook.Call("CAMI.OnPrivilegeUnregistered", nil, privilege)

    return true
end

---@return table<string, CAMI_PRIVILEGE>
function CAMI.GetPrivileges()
    return privileges
end

---@param privilegeName string
---@return CAMI_PRIVILEGE?
function CAMI.GetPrivilege(privilegeName)
    return privileges[privilegeName]
end

---@param actor Player
---@param privilegeName string
---@param callback fun(hasAccess: boolean, reason: string?)
---@param targetPly Player?
---@param extraInfoTbl table?
function CAMI.PlayerHasAccess(actor, privilegeName, callback, targetPly, extraInfoTbl)
    local hasAccess, reason = nil, nil

    local function allow(hasAccess_, reason_)
        if hasAccess ~= nil then return end
        hasAccess, reason = hasAccess_, reason_
    end

    hook.Call("CAMI.PlayerHasAccess", nil, actor, privilegeName, allow, targetPly, extraInfoTbl)

    if hasAccess ~= nil then
        callback(hasAccess, reason)
        return
    end

    -- No admin mod answered, so fall back to the privilege's own rule, then to
    -- the engine's user/admin/superadmin ladder.
    local privilege = privileges[privilegeName]

    if not IsValid(actor) then
        callback(true, "Console has access to everything.")
        return
    end

    if privilege and privilege.HasAccess then
        local ok = privilege.HasAccess(privilege, actor, targetPly)

        if ok ~= nil then
            callback(ok, "Privilege rule.")
            return
        end
    end

    local minAccess = privilege and privilege.MinAccess or "admin"
    local granted =
        minAccess == "user" or
        (minAccess == "admin" and actor:IsAdmin()) or
        (minAccess == "superadmin" and actor:IsSuperAdmin())

    callback(granted, "Fallback.")
end

---@param privilegeName string
---@param callback fun(players: Player[])
---@param targetPly Player?
---@param extraInfoTbl table?
function CAMI.GetPlayersWithAccess(privilegeName, callback, targetPly, extraInfoTbl)
    local allowed, waiting = {}, player.GetCount()

    if waiting == 0 then
        callback(allowed)
        return
    end

    for _, ply in ipairs(player.GetAll()) do
        CAMI.PlayerHasAccess(ply, privilegeName, function(hasAccess)
            if hasAccess then allowed[#allowed + 1] = ply end

            waiting = waiting - 1
            if waiting == 0 then callback(allowed) end
        end, targetPly, extraInfoTbl)
    end
end

---@param steamID string
---@param privilegeName string
---@param callback fun(hasAccess: boolean, reason: string?)
---@param targetPly Player?
---@param extraInfoTbl table?
function CAMI.SteamIDHasAccess(steamID, privilegeName, callback, targetPly, extraInfoTbl)
    local hasAccess, reason = nil, nil

    local function allow(hasAccess_, reason_)
        if hasAccess ~= nil then return end
        hasAccess, reason = hasAccess_, reason_
    end

    hook.Call("CAMI.SteamIDHasAccess", nil, steamID, privilegeName, allow, targetPly, extraInfoTbl)

    callback(hasAccess or false, reason)
end

---@param ply Player
---@param old string
---@param new string
---@param source any
function CAMI.SignalUserGroupChanged(ply, old, new, source)
    hook.Call("CAMI.PlayerUsergroupChanged", nil, ply, old, new, source)
end

---@param steamID string
---@param old string
---@param new string
---@param source any
function CAMI.SignalSteamIDUserGroupChanged(steamID, old, new, source)
    hook.Call("CAMI.SteamIDUsergroupChanged", nil, steamID, old, new, source)
end
