# Binary modules

Garry's Mod loads binary modules from `garrysmod/lua/bin`, which this directory is
mounted over. Axis needs mysqloo to reach MariaDB.

Download the module matching the server's branch — this server runs the **x86-64**
branch, so it needs the 64-bit Linux build — from
<https://github.com/FredyH/MySQLOO/releases> and drop it in here:

```
src/bin/gmsv_mysqloo_linux64.dll
```

Yes, `.dll`: Garry's Mod uses that suffix on Linux 64-bit too. The server refuses
player connections with a clear message if the module or the database is missing.
