"METHOD5.METHOD5_ADMIN.GENERATE_REMOTE_INSTALL_SCRIPT()"
----------------------------------------
--Install Method5 on remote target.
--Run this script as SYS using SQL*Plus.
--Do NOT save this output - it contains password hashes and should be regenerated each time.
----------------------------------------
		

--Check the user.  This script will only work as SYS.
whenever sqlerror exit;
begin
	if user <> 'SYS' then
		raise_application_error(-20000,
'This step must be run as SYS.'||chr(13)||chr(10)||
'Logon as SYS and re-run.');
	end if;
end;
/
whenever sqlerror continue;
		

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
			if v_sec_case_sensitive_logon = 'TRUE' then
				execute immediate q'!create user method5 profile ZENOSS_PROFILE identified by values 'S:A6DBF0915ACE655242E0AD00F6580CE97242FCBF3B8CFDFB8DA64BA2ECC1'!';
			else
				if '' is null then
					raise_application_error(-20000, 'The 10g hash is not available.  You must set '||
						'the target database sec_case_sensitive_logon to TRUE for this to work.');
				else
					execute immediate q'!create user method5 profile ZENOSS_PROFILE identified by values ''!';
				end if;
			end if;
		--Change the hash for 12c.
		$else
			execute immediate q'!create user method5 profile ZENOSS_PROFILE identified by values 'S:A6DBF0915ACE655242E0AD00F6580CE97242FCBF3B8CFDFB8DA64BA2ECC1;T:9D4CA392DA8C65F9ABE7DD5EBF688F455EB4D5D8C05674C88C286DFC697D1C0DD5D50C6D6A7B3B6463E97102B31367EEA28BFD3EEAFE4B9EF20F7DE716097F0A5B6FCF220ED75F8ADA543D17E7BD4BAB'!';
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
--old version of the DoD STIG (secure techn..."
