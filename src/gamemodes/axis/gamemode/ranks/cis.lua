axis.rank.Register("cis_unit", {
    name = "Unit",
    abbreviation = "UNT",
    faction = "cis",
    level = 1,
    permissions = {},
})

axis.rank.Register("cis_sergeant", {
    name = "Droid Sergeant",
    abbreviation = "DSG",
    faction = "cis",
    level = 2,
    permissions = { radio = true, arrest = true },
})

axis.rank.Register("cis_commander", {
    name = "Droid Commander",
    abbreviation = "DCM",
    faction = "cis",
    level = 3,
    color = Color(230, 140, 90),
    weapons = { "weapon_357" },
    permissions = { radio = true, arrest = true, armory = true, promote = true },
})
