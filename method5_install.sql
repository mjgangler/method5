REM INSERTING into EXPORT_TABLE
SET DEFINE OFF;
Insert into EXPORT_TABLE ("METHOD5.METHOD5_ADMIN.GENERATE_REMOTE_INSTALL_SCRIPT()") values ('
----------------------------------------
--Install Method5 on remote target.
--Run this script as SYS.
--Do NOT save this output - it contains password hashes and should be regenerated each time.
----------------------------------------
		

--Create the profile that Method5 uses on the management server, if it doesn't exist.
declare
	v_count number;
begin
	select count(*) into v_count from dba_profiles where profile = 'ZENOSS_PROFILE';
	if v_count = 0 then
		execute immediate 'create profile ZENOSS_PROFILE limit cpu_per_call unlimited';
	end if;
end;
/


--Create the Method5 user with the appropriate hash.
declare
	v_sec_case_sensitive_logon varchar2(4000);
begin
	select upper(value)
	into v_sec_case_sensitive_logon
	from v$parameter
	where name = 'sec_case_sensitive_logon';

	--Do nothing if this is the management database - the user already exists.
	if lower(sys_context('userenv', 'db_name')) = 'oem12dg' then
		null;
	else
		--Change the hash for 10g and 11g.
		$if dbms_db_version.ver_le_11_2 $then
				execute immediate q'!create user method5 profile ZENOSS_PROFILE identified by values 'S:AC0775909510C6C81A739DC4DE6640E21E3123C4E131CEE9D26C42FF1D8C'!';
		--Change the hash for 12c.
		$else
			execute immediate q'!create user method5 profile ZENOSS_PROFILE identified by values 'S:AC0775909510C6C81A739DC4DE6640E21E3123C4E131CEE9D26C42FF1D8C;T:F1FADECF7832D402A0CE5BD9C3EE409479E17B0EC2CB571A826AFF6A7B68D688242A65D0E0BC3038061DBA58DD0CFACF8F606C524D5609D00EAFE52AE19C2F277FE3BA7242492F3E26E26E614C11AF25'!';
		$end
	end if;
end;
/


--REQUIRED: Create and grant role of minimum Method5 remote target privileges.
--Do NOT remove or change this block or Method5 will not work properly.
declare
	v_role_conflicts exception;
	pragma exception_init(v_role_conflicts, -1921);
begin
	begin
		execute immediate 'create role m5_minimum_remote_privs';
	exception when v_role_conflicts then null;
	end;

	execute immediate 'grant m5_minimum_remote_privs to method5';

	execute immediate 'grant create session to m5_minimum_remote_privs';
	execute immediate 'grant create table to m5_minimum_remote_privs';
	execute immediate 'grant create procedure to m5_minimum_remote_privs';
	execute immediate 'grant execute on sys.dbms_sql to m5_minimum_remote_privs';
end;
/

--REQUIRED: Grant Method5 unlimited access to the default tablespace.
--You can change the quota or tablespace but Method5 must have at least a little space.
declare
	v_default_tablespace varchar2(128);
begin
	select property_value
	into v_default_tablespace
	from database_properties
	where property_name = 'DEFAULT_PERMANENT_TABLESPACE';

	execute immediate 'alter user method5 quota unlimited on '||v_default_tablespace;
end;
/

--REQUIRED: Create and grant role for additional Method5 remote target privileges.
--Do NOT remove or change this block or Method5 will not work properly.
declare
	v_role_conflicts exception;
	pragma exception_init(v_role_conflicts, -1921);
begin
	begin
		execute immediate 'create role m5_optional_remote_privs';
	exception when v_role_conflicts then null;
	end;

	execute immediate 'grant m5_optional_remote_privs to method5';
end;
/

--REQUIRED: DBMS_SCHEDULER should already be granted to PUBLIC.
--Some security/audit/hardening scripts may revoke it but only because they are using an
--old version of the DoD STIG (secure technical implementation guidelines).  The new version
--does not revoke this public grant anymore.
--It is required to make the SANDBOX users work.
grant execute on sys.dbms_scheduler to public;

--OPTIONAL, but recommended: Grant DBA to Method5 role.
--WARNING: The privilege granted here is the upper-limit applied to ALL users.
--  If you only want to block specific users from having DBA look at the table M5_USER.
--
--If you don't trust Method5 or are not allowed to grant DBA, you can manually modify this block.
--Simply removing it would make Method5 worthless.  But you may want to replace it with something
--less powerful.  For example, you could make a read-only Method5 with these two commented out lines:
--	grant select any table to m5_optional_remote_privs;
--	grant select any dictionary to m5_optional_remote_privs;
grant dba to m5_optional_remote_privs;

--OPTIONAL, but recommended: Grant access to a table useful for password management and synchronization.
grant select on sys.user$ to m5_optional_remote_privs;

--OPTIONAL, but recommended: Direct grants for objects that are frequently revoked from PUBLIC, as
--recommended by the Security Technical Implementation Guide (STIG).
--Use "with grant option" since these will probably also need to be granted to users.
begin
	for packages in
	(
		select 'grant execute on '||column_value||' to m5_optional_remote_privs with grant option' v_sql
		from table(sys.odcivarchar2list(
			'DBMS_ADVISOR','DBMS_BACKUP_RESTORE','DBMS_CRYPTO','DBMS_JAVA','DBMS_JAVA_TEST',
			'DBMS_JOB','DBMS_JVM_EXP_PERMS','DBMS_LDAP','DBMS_LOB','DBMS_OBFUSCATION_TOOLKIT',
			'DBMS_PIPE','DBMS_RANDOM','DBMS_SCHEDULER','DBMS_SQL','DBMS_SYS_SQL','DBMS_XMLGEN',
			'DBMS_XMLQUERY','HTTPURITYPE','UTL_FILE','UTL_HTTP','UTL_INADDR','UTL_SMTP','UTL_TCP'
		))
	) loop
		begin
			execute immediate packages.v_sql;
		exception when others then null;
		end;
	end loop;
end;
/


--Audit everything done by Method5.
audit all statements by method5;

--Prevent Method5 from connecting directly.
create or replace trigger sys.m5_prevent_direct_logon
after logon on method5.schema
/*
	Purpose: Prevent anyone from connecting directly as Method5.
		All Method5 connections must be authenticated by the Method5
		program and go through a database link.

	Note: These checks are not foolproof and it's possible to spoof some
		of these values.  The primary protection of the Method5 comes from
		only using password hashes and nobody ever knowing the password.
		This trigger is another layer of protection, but not a great one.
*/
declare
	--Only an ORA-600 error can stop logons for users with either
	--"ADMINISTER DATABASE TRIGGER" or "ALTER ANY TRIGGER".
	--The ORA-600 also generates an alert log entry and may warn an admin.
	internal_exception exception;
	pragma exception_init( internal_exception, -600 );

	procedure check_module_for_link is
	begin
		--TODO: This is not tested!
		if
			sys_context('userenv','module') like 'oracle@%'
			or
			sys_context('userenv','BG_JOB_ID') is not null
		 then
			null;
		else
			raise internal_exception;
		end if;
	end;
begin
	--Check that the connection comes from the management server.
	if sys_context('userenv', 'session_user') = 'METHOD5'
	   and lower(sys_context('userenv', 'host')) not like '%msp-orapl01%' then
		raise internal_exception;
	end if;

	--Check that the connection comes over a database link or through a scheduled job.
	$if dbms_db_version.ver_le_9 $then
		check_module_for_link;
	$elsif dbms_db_version.ver_le_10 $then
		check_module_for_link;
	$elsif dbms_db_version.ver_le_11_1 $then
		check_module_for_link;
	$else
		if
			sys_context('userenv', 'dblink_info') is not null
			or
			sys_context('userenv','BG_JOB_ID') is not null
		then
			null;
		else
			raise internal_exception;
		end if;
	$end
end;
/


--Create table to hold Session GUIDs.
create table sys.m5_sys_session_guid
(
	session_guid raw(16),
	constraint m5_sys_session_guid_pk primary key(session_guid)
);
comment on table sys.m5_sys_session_guid is 'Session GUID to prevent Method5 SYS replay attacks.';


--Create package to enable remote execution of commands as SYS.
create or replace package sys.m5_runner is

--Copyright (C) 2017 Jon Heller, Ventech Solutions, and CMS.  This program is licensed under the LGPLv3.
--Version 1.0.1
--Read this page if you're curious about this program or concerned about security implications:
--https://github.com/method5/method5/blob/master/user_guide.md#security
procedure set_sys_key(p_sys_key in raw);
procedure run_as_sys(p_encrypted_command in raw);
procedure get_column_metadata
(
	p_plsql_block                in     varchar2,
	p_encrypted_select_statement in     raw,
	p_has_column_gt_30           in out number,
	p_has_long                   in out number,
	p_explicit_column_list       in out varchar2,
	p_explicit_expression_list   in out varchar2
);

end;
/


create or replace package body sys.m5_runner is

/******************************************************************************/
--Throw an error if the connection is not remote and not from an expected host.
procedure validate_remote_connection is
	procedure check_module_for_link is
	begin
		--TODO: This is not tested!
		if sys_context('userenv','module') not like 'oracle@%' then
			raise_application_error(-20200, 'This procedure was called incorrectly.');
		end if;
	end;
begin
	--Check that the connection comes from the management server.
	if sys_context('userenv', 'session_user') = 'METHOD5'
		and lower(sys_context('userenv', 'host')) not like '%msp-orapl01%' then
			raise_application_error(-20201, 'This procedure was called incorrectly.');
	end if;

	--Check that the connection comes over a database link.
	$if dbms_db_version.ver_le_9 $then
		check_module_for_link;
	$elsif dbms_db_version.ver_le_10 $then
		check_module_for_link;
	$elsif dbms_db_version.ver_le_11_1 $then
		check_module_for_link;
	$else
		if sys_context('userenv', 'dblink_info') is null then
			raise_application_error(-20203, 'This procedure was called incorrectly.');
		end if;
	$end
end validate_remote_connection;

/******************************************************************************/
--Set LINK$ to contain the secret key to control SYS access, but ONLY if the key
--is not currently set.
--LINK$ is a special table that not even SELECT ANY DICTIONARY can select from
--since 10g.
procedure set_sys_key(p_sys_key in raw) is
	v_count number;
begin
	--Only allow specific remote connections.
	validate_remote_connection;

	--Disable bind variables so nobody can spy on keys.
	execute immediate 'alter session set statistics_level = basic';

	--Throw error if the remote key already exists.
	select count(*) into v_count from dba_db_links where owner = 'SYS' and db_link like 'M5_SYS_KEY%';
	if v_count = 1 then
		raise_application_error(-20204, 'The SYS key already exists on the remote database.  '||
			'If you want to reset the SYS key, run these steps:'||chr(10)||
			'1. On the remote database, as SYS: DROP DATABASE LINK M5_SYS_KEY;'||chr(10)||
			'2. On the local database: re-run this procedure.');
	end if;

	--Create database link.
	execute immediate q'!
		create database link m5_sys_key
		connect to not_a_real_user
		identified by "Not a real password"
		using 'Not a real connect string'
	!';

	--Modify the link to store the sys key.
	update sys.link$
	set passwordx = p_sys_key
	--The name may be different because of GLOBAL_NAMES setting.
	where name like 'M5_SYS_KEY%'
		and userid = 'NOT_A_REAL_USER'
		and owner# = (select user_id from dba_users where username = 'SYS');

	commit;
end set_sys_key;

/******************************************************************************/
--Only allow connections from the right place, with the right encryption key,
--and the right session id.
function authenticate_and_decrypt(p_encrypted_command in raw) return varchar2 is
	v_sys_key raw(32);
	v_command varchar2(32767);
	v_guid raw(16);
	v_count number;
	pragma autonomous_transaction;
begin
	--Only allow specific remote connections.
	validate_remote_connection;

	--Disable bind variables so nobody can spy on keys.
	execute immediate 'alter session set statistics_level = basic';

	--Get the key.
	begin
		select passwordx
		into v_sys_key
		from sys.link$
		where owner# = (select user_id from dba_users where username = 'SYS')
			and name like 'M5_SYS_KEY%';
	exception when no_data_found then
		raise_application_error(-20205, 'The SYS key was not installed correctly.  '||
			'See the file administer_method5.md for help.'||chr(10)||
			sys.dbms_utility.format_error_stack||sys.dbms_utility.format_error_backtrace);
	end;

	--Decrypt the command.
	begin
		v_command := utl_i18n.raw_to_char(
			dbms_crypto.decrypt
			(
				src => p_encrypted_command,
				typ => dbms_crypto.encrypt_aes256 + dbms_crypto.chain_cbc + dbms_crypto.pad_pkcs5,
				key => v_sys_key
			),
			'AL32UTF8'
		);
	exception when others then
		raise_application_error(-20206, 'There was an error during decryption, the SYS key is probably '||
			'installed incorrectly.  See the file administer_method5.md for help.'||chr(10)||
			sys.dbms_utility.format_error_stack||sys.dbms_utility.format_error_backtrace);
	end;

	--Remove the GUID at the front.
	v_guid := hextoraw(substr(v_command, 1, 32));
	v_command := substr(v_command, 33);

	--Check that the GUID is new, to prevent a replay attack.
	select count(*) into v_count from sys.m5_sys_session_guid where session_guid = v_guid;
	if v_count >= 1 then
		raise_application_error(-20207, 'The SESSION_ID has already been run.  '||
			'This procedure can only be called from Method5 and cannot reuse a SESSION_ID.');
	end if;

	--Store the GUID, which acts as a session ID.
	--This is why the function is an autonomous transaction - the session ID must
	--be saved even if everything else fails.
	insert into sys.m5_sys_session_guid values(v_guid);
	commit;

	return v_command;
end authenticate_and_decrypt;

/******************************************************************************/
--Run a (properly encrypted) command as SYS.
procedure run_as_sys(p_encrypted_command in raw) is
	v_command varchar2(32767);
begin
	v_command := authenticate_and_decrypt(p_encrypted_command);

	--Run the command.
	execute immediate v_command;

	--Do NOT commit.  The caller must commit to preserve the rowcount for the feedback message.
end;

/******************************************************************************/
--Get column metadata as SYS.  This procedure is only meant to work with the
--private procedure Method5.m5_pkg.get_column_metadata, using input encrypted
--with Method5.m5_pkg.get_encrypted_raw.
procedure get_column_metadata
(
	p_plsql_block                in     varchar2,
	p_encrypted_select_statement in     raw,
	p_has_column_gt_30           in out number,
	p_has_long                   in out number,
	p_explicit_column_list       in out varchar2,
	p_explicit_expression_list   in out varchar2
) is
	v_select_statement varchar2(32767);
begin
	v_select_statement := authenticate_and_decrypt(p_encrypted_select_statement);

	execute immediate p_plsql_block
	using v_select_statement
		,out p_has_column_gt_30
		,out p_has_long
		,out p_explicit_column_list
		,out p_explicit_expression_list;
end get_column_metadata;

end;
/


grant execute on sys.m5_runner to method5;


create or replace procedure sys.m5_run_shell_script(p_script in clob, p_table_name in varchar2) is
--------------------------------------------------------------------------------
--Purpose: Execute a shell script and store results in a table.
--Parameters:
--	p_script - A shell script that starts with a shebang and will be
--		run by the Oracle software owner.
--	p_table_name - The table to store the results.
--Side-Effects: Creates the table P_TABLE_NAME in the Method5 schema, with results.
--Requires:
--	Must be run as SYS because only SYS jobs are run as the Oracle owner.
--	Only works on Unix and Linux.
--	Oracle software owner must be able to read and write to /tmp/
--Notes:
--	The scheduler overhead always adds a few seconds to the run time.
--
--Copyright (C) 2017 Jon Heller, Ventech Solutions, and CMS.  This program is licensed under the LGPLv3.
--Version 1.0.3
--Read this page if you're curious about this program or concerned about security implications:
--https://github.com/method5/method5/blob/master/user_guide.md#security

	--This unique string prevents operating system duplicates.
	c_unique_string varchar2(100) := to_char(sysdate, 'YYYY_MM_DD_HH24_MI_SS_')||rawtohex(sys_guid());
	--This random number prevents Oracle duplicates.
	c_random_number varchar2(100) := to_char(trunc(dbms_random.value*100000000));

	c_script_file_name constant varchar2(100) := 'm5_script_'||c_unique_string||'.sh';
	c_redirect_file_name constant varchar2(100) := 'm5_redirect_'||c_unique_string||'.sh';
	c_output_file_name constant varchar2(100) := 'm5_output_'||c_unique_string||'.out';

	c_temp_path constant varchar2(100) := '/tmp/method5/';
	c_directory constant varchar2(100) := 'M5_TMP_DIR';

	v_job_failed exception;
	pragma exception_init(v_job_failed, -27369);

	pragma autonomous_transaction;


	------------------------------------------------------------------------------
	procedure create_file(p_directory varchar2, p_file_name varchar2, p_text clob) is
		v_file_type utl_file.file_type;
	begin
		v_file_type := utl_file.fopen(p_directory, p_file_name, 'W', 32767);
		utl_file.put(v_file_type, p_text);
		utl_file.fclose(v_file_type);
	end create_file;


	------------------------------------------------------------------------------
	--Purpose: Check if the directory /tmp/method5 exists.
	function does_tmp_method5_dir_not_exist return boolean is
		v_file_type utl_file.file_type;
		v_invalid_file_operation exception;
		pragma exception_init(v_invalid_file_operation, -29283);
	begin
		--Try to create a test file on the directory.
		--If it fails, then the directory does not exist.
		create_file(
			p_directory => c_directory,
			p_file_name => 'test_if_method5_directory_exists.txt',
			p_text      => 'This file only exists to quickly check the existence of a file.'
		);

		--The directory exists if we got this far.
		return false;
	exception when v_invalid_file_operation then
		return true;
	end does_tmp_method5_dir_not_exist;


	------------------------------------------------------------------------------
	--Purpose: Create the Method5 operating system directory.
	procedure create_os_directory is
	begin
		--Create program.
		dbms_scheduler.create_program (
			program_name        => 'M5_TEMP_MKDIR_PROGRAM_'||c_random_number,
			program_type        => 'EXECUTABLE',
			program_action      => '/usr/bin/mkdir',
			number_of_arguments => 1,
			comments            => 'Temporary program created for Method5.  Created on: '||to_char(systimestamp, 'YYYY-MM-DD HH24:MI:SS')
		);

		--Create program arguments.
		dbms_scheduler.define_program_argument(
			program_name      => 'M5_TEMP_MKDIR_PROGRAM_'||c_random_number,
			argument_position => 1,
			argument_name     => 'M5_TEMP_MKDIR_ARGUMENT_1',
			argument_type     => 'VARCHAR2'
		);

		dbms_scheduler.enable('M5_TEMP_MKDIR_PROGRAM_'||c_random_number);

		--Create job.
		dbms_scheduler.create_job (
			job_name     => 'M5_TEMP_MKDIR_JOB_'||c_random_number,
			program_name => 'M5_TEMP_MKDIR_PROGRAM_'||c_random_number,
			comments     => 'Temporary job created for Method5.  Created on: '||to_char(systimestamp, 'YYYY-MM-DD HH24:MI:SS')
		);

		--Create job argument values.
		dbms_scheduler.set_job_argument_value(
			job_name       => 'M5_TEMP_MKDIR_JOB_'||c_random_number,
			argument_name  => 'M5_TEMP_MKDIR_ARGUMENT_1',
			argument_value => '/tmp/method5/'
		);

		--Run job synchronously.  This works even if JOB_QUEUE_PROCESSES=0.
		begin
			dbms_scheduler.run_job('M5_TEMP_MKDIR_JOB_'||c_random_number);
		exception when others then
			--Ignore errors if the file exists.
			if sqlerrm like '%File exists%' then
				null;
			else
				raise;
			end if;
		end;

	end create_os_directory;


	------------------------------------------------------------------------------
	--Purpose: Create the Oracle directory, if it does not exist.
	procedure create_ora_dir_if_not_exists is
		v_count number;
	begin
		--Check for existing directory.
		select count(*)
		into v_count
		from all_directories
		where directory_name = c_directory
			and directory_path = c_temp_path;

		--Create if it doesn't exist.
		if v_count = 0 then
			execute immediate 'create or replace directory '||c_directory||' as '''||c_temp_path||'''';
		end if;
	end create_ora_dir_if_not_exists;


	------------------------------------------------------------------------------
	--Parameters:
	--	p_mode: The chmod mode, for example: u+x
	--	p_file: The full path to a single file.  Cannot include multiple files
	--		or any globbing.  E.g., no "*" in the file name.
	procedure chmod(p_mode varchar2, p_file varchar2) is
	begin
		--Create program.
		dbms_scheduler.create_program (
			program_name        => 'M5_TEMP_CHMOD_PROGRAM_'||c_random_number,
			program_type        => 'EXECUTABLE',
			program_action      => '/usr/bin/chmod',
			number_of_arguments => 2,
			comments            => 'Temporary program created for Method5.  Created on: '||to_char(systimestamp, 'YYYY-MM-DD HH24:MI:SS')
		);

		--Create program arguments.
		dbms_scheduler.define_program_argument(
			program_name      => 'M5_TEMP_CHMOD_PROGRAM_'||c_random_number,
			argument_position => 1,
			argument_name     => 'M5_TEMP_CHMOD_ARGUMENT_1',
			argument_type     => 'VARCHAR2'
		);
		dbms_scheduler.define_program_argument(
			program_name      => 'M5_TEMP_CHMOD_PROGRAM_'||c_random_number,
			argument_position => 2,
			argument_name     => 'M5_TEMP_CHMOD_ARGUMENT_2',
			argument_type     => 'VARCHAR2'
		);

		dbms_scheduler.enable('M5_TEMP_CHMOD_PROGRAM_'||c_random_number);

		--Create job.
		dbms_scheduler.create_job (
			job_name     => 'M5_TEMP_CHMOD_JOB_'||c_random_number,
			program_name => 'M5_TEMP_CHMOD_PROGRAM_'||c_random_number,
			comments     => 'Temporary job created for Method5.  Created on: '||to_char(systimestamp, 'YYYY-MM-DD HH24:MI:SS')
		);

		--Create job argument values.
		dbms_scheduler.set_job_argument_value(
			job_name       => 'M5_TEMP_CHMOD_JOB_'||c_random_number,
			argument_name  => 'M5_TEMP_CHMOD_ARGUMENT_1',
			argument_value => p_mode
		);
		dbms_scheduler.set_job_argument_value(
			job_name       => 'M5_TEMP_CHMOD_JOB_'||c_random_number,
			argument_name  => 'M5_TEMP_CHMOD_ARGUMENT_2',
			argument_value => p_file
		);

		--Run job synchronously.  This works even if JOB_QUEUE_PROCESSES=0.
		dbms_scheduler.run_job('M5_TEMP_CHMOD_JOB_'||c_random_number);
	end chmod;


	------------------------------------------------------------------------------
	procedure run_script(p_full_path_to_file varchar2) is
	begin
		--Create program.
		dbms_scheduler.create_program (
			program_name   => 'M5_TEMP_RUN_PROGRAM_'||c_random_number,
			program_type   => 'EXECUTABLE',
			program_action => p_full_path_to_file,
			enabled        => true,
			comments       => 'Temporary program created for Method5.  Created on: '||to_char(systimestamp, 'YYYY-MM-DD HH24:MI:SS')
		);

		--Create job.
		dbms_scheduler.create_job (
			job_name     => 'M5_TEMP_RUN_JOB_'||c_random_number,
			program_name => 'M5_TEMP_RUN_PROGRAM_'||c_random_number,
			comments     => 'Temporary job created for Method5.  Created on: '||to_char(systimestamp, 'YYYY-MM-DD HH24:MI:SS')
		);

		--Run job synchronously.  This works even if JOB_QUEUE_PROCESSES=0.
		dbms_scheduler.run_job('M5_TEMP_RUN_JOB_'||c_random_number);
	end run_script;


	------------------------------------------------------------------------------
	procedure create_external_table(p_directory varchar2, p_script_output_file_name varchar2) is
	begin
		execute immediate '
		create table sys.m5_temp_output_'||c_random_number||'(output varchar2(4000))
		organization external
		(
			type oracle_loader default directory '||p_directory||'
			access parameters
			(
				records delimited by newline
				fields terminated by ''only_one_line_never_terminate_fields''
				missing field values are null
			)
			location ('''||p_script_output_file_name||''')
		)
		reject limit unlimited';
	end create_external_table;


	------------------------------------------------------------------------------
	--Purpose: Drop new jobs, programs, and tables so they don't clutter the data dictionary.
	procedure drop_new_objects is
	begin
		--Note how the "M5_TEMP" is double hard-coded.
		--This ensure we will never, ever, drop the wrong SYS object.

		--Drop new jobs.
		for jobs_to_drop in
		(
			select replace(job_name, 'M5_TEMP') job_name
			from user_scheduler_jobs
			where job_name like 'M5_TEMP%'||c_random_number
			order by job_name
		) loop
			dbms_scheduler.drop_job('M5_TEMP'||jobs_to_drop.job_name);
		end loop;

		--Drop new programs.
		for programs_to_drop in
		(
			select replace(program_name, 'M5_TEMP') program_name
			from user_scheduler_programs
			where program_name like 'M5_TEMP%'||c_random_number
			order by program_name
		) loop
			dbms_scheduler.drop_program('M5_TEMP'||programs_to_drop.program_name);
		end loop;

		--Drop new tables.
		for tables_to_drop in
		(
			select replace(table_name, 'M5_TEMP') table_name
			from user_tables
			where table_name like 'M5_TEMP%'||c_random_number
			order by table_name
		) loop
			--Hard-code the M5_TEMP_STD to ensure that we never, ever, ever drop the wrong table.
			execute immediate 'drop table M5_TEMP'||tables_to_drop.table_name||' purge';
		end loop;
	end drop_new_objects;


	------------------------------------------------------------------------------
	--Purpose: Drop old jobs, programs, and tables that may not have been properly dropped before.
	--  This may happen if previous runs did not end cleanly.
	procedure cleanup_old_objects is
	begin
		--Note how the "M5_TEMP" is double hard-coded.
		--This ensure we will never, ever, drop the wrong SYS object.

		--Delete all non-running Method5 temp jobs after 2 days.
		for jobs_to_drop in
		(
			select replace(job_name, 'M5_TEMP') job_name
			from user_scheduler_jobs
			where job_name like 'M5_TEMP%'
				and replace(comments, 'Temporary job created for Method5.  Created on: ') < to_char(systimestamp - interval '2' day, 'YYYY-MM-DD HH24:MI:SS')
				and job_name not in (select job_name from user_scheduler_running_jobs)
			order by job_name
		) loop
			dbms_scheduler.drop_job('M5_TEMP'||jobs_to_drop.job_name);
		end loop;

		--Delete all Method5 temp programs after 2 days.
		for programs_to_drop in
		(
			select replace(program_name, 'M5_TEMP') program_name
			from user_scheduler_programs
			where program_name like 'M5_TEMP%'
				and replace(comments, 'Temporary program created for Method5.  Created on: ') < to_char(systimestamp - interval '2' day, 'YYYY-MM-DD HH24:MI:SS')
			order by program_name
		) loop
			dbms_scheduler.drop_program('M5_TEMP'||programs_to_drop.program_name);
		end loop;

		--Drop old tables after 7 days.
		--The tables don't use any space and are unlikely to ever be noticed
		--so it doesn't hurt to keep them around for a while.
		for tables_to_drop in
		(
			select replace(object_name, 'M5_TEMP') table_name
			from user_objects
			where object_type = 'TABLE'
				and object_name like 'M5_TEMP_STD%'
				and created < systimestamp - interval '7' day
			order by object_name
		) loop
			execute immediate 'drop table M5_TEMP'||tables_to_drop.table_name||' purge';
		end loop;
	end cleanup_old_objects;
begin
	--Create directories if necessary.
	create_ora_dir_if_not_exists;

	if does_tmp_method5_dir_not_exist then
		create_os_directory;
		chmod('700', c_temp_path);
		--Drop some objects now because chmod will be called again later.
		drop_new_objects;
	end if;

	--Create empty output file in case nothing gets written later.  External tables require a file to exist.
	create_file(c_directory, c_output_file_name, null);

	--Create script file, that will write data to standard output.
	create_file(c_directory, c_script_file_name, p_script);

	--Create script redirect file, that executes script and redirects output to the output file.
	--This is necessary because redirection does not work in Scheduler.
	create_file(c_directory, c_redirect_file_name,
		'#!/bin/sh'||chr(10)||
		'chmod 700 '||c_temp_path||c_script_file_name||chr(10)||
		'chmod 600 '||c_temp_path||c_output_file_name||chr(10)||
		c_temp_path||c_script_file_name||' > '||c_temp_path||c_output_file_name||' 2>'||chr(38)||'1'
	);

	--Chmod the redirect file.
	--The CHMOD job is slow, so most chmoding is done inside the redirect script.
	--Unfortunately CHMOD through the scheduler does not support "*", it would throw this error:
	--ORA-27369: job of type EXECUTABLE failed with exit code: 1 chmod: WARNING: can't access /tmp/method5/m5*.out
	chmod('700', c_temp_path||c_redirect_file_name);

	--Run script and redirect output and error to other files.
	--(External table preprocessor script doesn't work in our environments for some reason.)
	begin
		run_script(c_temp_path||c_redirect_file_name);
	exception when v_job_failed then
		null;
	end;

	--Create external tables to read the output.
	create_external_table(c_directory, c_output_file_name);

	--Create table with results.
	--(A view would have some advantages here, but would also require a lot of
	--extra permissions on the underlying tables and directories.)
	execute immediate replace(replace(
	q'!
		create table method5.#TABLE_NAME# nologging pctfree 0 as
		select rownum line_number, cast(output as varchar2(4000)) output from M5_TEMP_OUTPUT_#RANDOM_NUMBER#
	!', '#RANDOM_NUMBER#', c_random_number), '#TABLE_NAME#', p_table_name);

	--Cleanup.
	drop_new_objects;
	cleanup_old_objects;
end m5_run_shell_script;
/
		


----------------------------------------
--End of Method5 remote target install.
----------------------------------------

