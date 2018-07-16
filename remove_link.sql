--Remove all user links:
begin
	for users in
	(
		select distinct owner
		from dba_db_links
		where db_link like 'M5_IMANTST%'
			and owner not in ('SYS')
		order by owner
	) loop
		method5.method5_admin.drop_m5_db_links_for_user(users.owner);
	end loop;
end;
/
