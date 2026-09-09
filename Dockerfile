FROM cm2network/steamcmd:root

USER steam

# Force install Garry's Mod using the x86-64 branch
RUN ./steamcmd.sh +force_install_dir /home/steam/server +login anonymous +app_update 4020 -beta x86-64 validate +quit || \
    ./steamcmd.sh +force_install_dir /home/steam/server +login anonymous +app_update 4020 -beta x86-64 validate +quit

WORKDIR /home/steam/server

# Deliberately below the steamcmd layer: copying above it would invalidate the
# cache on every entrypoint edit and re-download the whole game.
USER root
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
USER steam

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["./srcds_run_x64", "-game", "garrysmod", "+maxplayers", "16", "+map", "gm_construct", "+gamemode", "sandbox", "-norestart"]
