axis.faction.Register("police", {
    name = "Police Department",
    desc = "Law enforcement.",
})

axis.team.Register("detective", {
    name = "Detective",
    faction = "police",
    model = "models/player/dod_german.mdl",
    color = Color(50, 50, 150),
    OnJoin = function(self, ply)
        ply:ChatPrint("You are now a Detective. Check the evidence locker.")
    end
})
