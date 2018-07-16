--Kill any active Method5 sessions 
begin for sessions in ( select 'alter system kill session '''||sid||','||serial#||',@'||inst_id||'''' v_sql from gv$session 
where username = 'METHOD5' ) 
loop 
execute immediate sessions.v_sql; 
end loop; 
end;
/
drop user method5 cascade; 
drop table sys.m5_sys_session_guid; 
drop package sys.m5_runner; 
drop procedure sys.m5_run_shell_script; 
drop database link m5_sys_key; 
drop role m5_minimum_remote_privs; 
drop role m5_optional_remote_privs;
