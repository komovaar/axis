axis.class.Register("medic", {
    name = "Medic",
    faction = "republic",
    models = { "models/player/combine_soldier_prisonguard.mdl" },
    weapons = { "weapon_pistol", "weapon_medkit", "weapon_crowbar" },
    health = 100,
    armor = 15,
    limit = 4,
    radio = true,
    OnJoin = function(_, ply)
        axis.chat.Notify(ply, "info", "You are the squad medic - keep your troopers alive.")
    end,
})
