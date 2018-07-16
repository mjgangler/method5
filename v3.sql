select DATABASE_NAME, the_date, "Tablespace", "allocated_mb", "used_mb", "free_mb"
                             ,the_date - min(the_date) over () + 1 date_number_asc
                             ,max(the_date) over () - the_date + 1 date_number_desc
                         from
                         (
                             --Historical "Tablespace" sizes.
                             select a."DATABASE_NAME", the_date, "Tablespace", "allocated_mb", "allocated_mb" - a."free_mb" calc_mb, "free_mb"
                             from nonasm_diskgroup_fcst a
                             join
                             (
                             --Databases and hosts.
                             select
                                 lower(database_name) database_name,
                                 --Remove anything after a "." to keep the display name short.
                                 listagg(regexp_replace(host_name, '\..*'), chr(10)) within group (order by host_name) hosts
                             from m5_database b
                             group by lower(database_name)
                             ) databases
                            on a.database_name = databases.database_name
                             where "allocated_mb" <> 0
                             and the_date > sysdate - 30
                             --Exclude some "Tablespace"s that constantly grow and shrink.
                             and "Tablespace" not like '%TEMP%'
                             and "Tablespace" not like '%FRADG%'
                             order by "Tablespace", hosts, the_date)
/
