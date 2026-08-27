FROM cm2network/steamcmd:root

USER steam

# Force install Garry's Mod using the x86-64 branch
RUN ./steamcmd.sh +force_install_dir /home/steam/server +login anonymous +app_update 4020 -beta x86-64 validate +quit || \
    ./steamcmd.sh +force_install_dir /home/steam/server +login anonymous +app_update 4020 -beta x86-64 validate +quit

WORKDIR /home/steam/server

CMD ["./srcds_run_x64", "-game", "garrysmod", "+maxplayers", "16", "+map", "gm_construct", "+gamemode", "sandbox", "-norestart"]