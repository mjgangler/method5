begin
    m5_proc(
    p_targets => 'Production',
    p_code => q'[
select
'================================================================================' info,
'Instance Name: '||instance_name info,
'Host Name: '||host_name info,
'Name: '||name info,
'DBID: '||DBID info,
'Database Version: '||version info,
'Open Mode: '||open_mode info,
'Status: '||status info,
'Log Mode: '||log_mode info,
'Flashback On: '||flashback_on info,
'DB Unique Name: '||DB_UNIQUE_NAME info,
'Dataguard Broker: '||DATAGUARD_BROKER info,
'Guard Status: '||GUARD_STATUS info,
'Database Role: '||DATABASE_ROLE info,
'Created: '||to_char(created, 'DD-MON-YYYY:HH24:MI') info,
'Startup Time: '||to_char(STARTUP_TIME,'DD-MON-YYYY HH24:MI') info,
'Now: '||to_char(sysdate, 'DD-MON-YYYY:HH24:MI') info,
'Up Time DD HH:MI:SS : '||rtrim(ltrim( (cast(sysdate as timestamp) - cast (STARTUP_TIME as timestamp)),'+000000000'),'.000000') info
from v$database, v$instance;

]'
);
end;
