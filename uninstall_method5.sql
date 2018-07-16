
	--Stop current jobs:
	begin
		method5.m5_pkg.stop_jobs;
	end;
	/

	--Drop house-keeping and global data dictionary jobs:
	declare
		procedure drop_job_not_exists(p_job_name varchar2) is
			v_unknown_job exception;
			v_job_does_not_exist exception;
			pragma exception_init(v_unknown_job, -27475);
			pragma exception_init(v_job_does_not_exist, -27476);
		begin
			dbms_scheduler.drop_job(p_job_name);
		exception when v_unknown_job or v_job_does_not_exist then null;
		end;
	begin
		drop_job_not_exists('method5.cleanup_m5_temp_triggers_job');
		drop_job_not_exists('method5.cleanup_m5_temp_tables_job');
		drop_job_not_exists('method5.direct_m5_grants_job');
		drop_job_not_exists('method5.email_m5_daily_summary_job');
		drop_job_not_exists('method5.stop_timed_out_jobs_job');
		drop_job_not_exists('method5.backup_m5_database_job');

		for jobs in
		(
			select owner, job_name
			from dba_scheduler_jobs
			where job_name in (
				--Housekeeping job that must be run by a user
				'CLEANUP_REMOTE_M5_OBJECTS_JOB',
				--Global data dictionary.
				'M5_DBA_USERS_JOB', 'M5_V$PARAMETER_JOB', 'M5_PRIVILEGES_JOB', 'M5_USER$_JOB',
				--Refreshes links in user schemas.
				'M5_LINK_REFRESH_JOB'
			)
			order by 1,2
		) loop
			drop_job_not_exists(jobs.owner||'.'||jobs.job_name);
		end loop;

	end;
	/

	--Kill any remaining Method5 user sessions:
	begin
		for sessions in
		(
			select 'alter system kill session '''||sid||','||serial#||''' immediate' kill_sql
			from gv$session
			where schemaname = 'METHOD5'
		) loop
			execute immediate sessions.kill_sql;
		end loop;
	end;
	/

	--Remove all user links:
	begin
		for users in
		(
			select distinct owner
			from dba_db_links
			where db_link like 'M5_%'
				and owner not in ('METHOD5', 'SYS')
			order by owner
		) loop
			method5.method5_admin.drop_m5_db_links_for_user(users.owner);
		end loop;
	end;
	/

	--Drop the ACL used for sending emails:
	begin
		dbms_network_acl_admin.drop_acl(acl => 'method5_email_access.xml');
	end;
	/

	--Drop the user.
	drop user method5 cascade;

	--Drop a global context used for Method4:
	drop context method4_context;

	--Drop public synonyms:
	begin
		for synonyms in
		(
			select 'drop public synonym '||synonym_name v_sql
			from dba_synonyms
			where table_owner = 'METHOD5'
			order by 1
		) loop
			execute immediate synonyms.v_sql;
		end loop;
	end;
	/

	--Drop temporary tables that hold Method5 data retrieved from targets:
	begin
		for tables in
		(
			select 'drop table '||owner||'.'||table_name||' purge' v_sql
			from dba_tables
			where table_name like 'M5_TEMP%'
			order by 1
		) loop
			execute immediate tables.v_sql;
		end loop;
	end;
	/

	--Drop role granted to all Method5 users.
	drop role m5_run;

--Drop SYS objects.
drop procedure sys.m5_change_db_link_pw;
drop procedure sys.m5_create_triggers;
drop procedure sys.get_method5_hashes;
drop procedure sys.m5_protect_config_tables;
