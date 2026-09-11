--- Ranks are a ladder within one faction: `level` orders them and drives
--- axis.rank.AtLeast, `permissions` is in-character authority.
axis.rank.Register("republic_private", {
    name = "Private",
    abbreviation = "PVT",
    faction = "republic",
    level = 1,
    permissions = {},
})

axis.rank.Register("republic_corporal", {
    name = "Corporal",
    abbreviation = "CPL",
    faction = "republic",
    level = 2,
    permissions = { radio = true },
})

axis.rank.Register("republic_sergeant", {
    name = "Sergeant",
    abbreviation = "SGT",
    faction = "republic",
    level = 3,
    permissions = { radio = true, arrest = true },
})

axis.rank.Register("republic_lieutenant", {
    name = "Lieutenant",
    abbreviation = "LT",
    faction = "republic",
    level = 4,
    permissions = { radio = true, arrest = true, armory = true },
})

axis.rank.Register("republic_commander", {
    name = "Commander",
    abbreviation = "CMD",
    faction = "republic",
    level = 5,
    color = Color(230, 200, 90),
    weapons = { "weapon_357" },
    permissions = { radio = true, arrest = true, armory = true, promote = true },
})
