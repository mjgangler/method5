
----------------------------------------
--Reset Method5 password on one remote database.
--
--Do NOT save this output.  It contains password hashes that should be kept
--secret and need to be regenerated each time.
----------------------------------------
declare
	v_profile_name varchar2(128);
	v_password_reuse_max_before  varchar2(100);
	v_password_reuse_time_before varchar2(100);
	v_sec_case_sensitive_logon varchar2(100);
begin
	--Save profile values before the changes.
	select
		profile,
		max(case when resource_name = 'PASSWORD_REUSE_MAX' then limit else null end),
		max(case when resource_name = 'PASSWORD_REUSE_TIME' then limit else null end)
	into v_profile_name, v_password_reuse_max_before, v_password_reuse_time_before
	from dba_profiles
	where profile in
	(
		select profile
		from dba_users
		where username = 'METHOD5'
	)
	group by profile;

	--Find out if the good hash can be used.
	select upper(value)
	into v_sec_case_sensitive_logon
	from v$parameter
	where name = 'sec_case_sensitive_logon';

	--Change the profile resources to UNLIMITED.
	--The enables password changes even if it's a re-use.
	execute immediate 'alter profile '||v_profile_name||' limit password_reuse_max
unlimited';
	execute immediate 'alter profile '||v_profile_name||' limit password_reuse_time
 unlimited';

	--Unlock the account.
	execute immediate 'alter user method5 account unlock';

	--Change the hash for 10g and 11g.
	$if dbms_db_version.ver_le_11_2 $then
		if v_sec_case_sensitive_logon = 'TRUE' then
			execute immediate q'!alter user method5 identified by values 'S:842746CB0E2F598DEEF8BE4394D0AC8EA059CDF708E8478D4E10B4BED08E'!';
		else
			if '' is null then
				raise_application_error(-20000, 'The 10g hash is not available.  You must se
t '||
					'the target database sec_case_sensitive_logon to TRUE for this to work.');
			else
				execute immediate q'!alter user method5 identified by values ''!';
			end if;
		end if;
	--Change the hash for 12c.
	$else
		execute immediate q'!alter user method5 identified by values 'S:842746CB0E2F598DEEF8BE4394D0AC8EA059CDF708E8478D4E10B4BED08E;T:FE1867E3CD0C8AAEF643468F629DC5BB5100F0CF84A98BBD8CFF5E35F9DF04C4C2978D96346686C2D584F1462C8876DF15116FA789ED5463A7C090A4BBA490391FF067048F101A212F4B01BC8B4232F4'!';
	$end

	--Change the profile back to their original values.
	execute immediate 'alter profile '||v_profile_name||' limit password_reuse_max'||v_password_reuse_max_before;
	execute immediate 'alter profile '||v_profile_name||' limit password_reuse_time'||v_password_reuse_time_before;

	exception when others then
		--Change the profiles back to their original values.
		execute immediate 'alter profile '||v_profile_name||' limit password_reuse_max'||v_password_reuse_max_before;
		execute immediate 'alter profile '||v_profile_name||' limit password_reuse_time '||v_password_reuse_time_before;

		raise_application_error(-20000, 'Error resetting password: '||dbms_utility.format_error_stack||dbms_utility.format_error_backtrace);
end;
/
