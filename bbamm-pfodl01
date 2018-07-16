grant select on sys.v_$instance to method5;
grant select on sys.v_$database to method5;

create or replace view method5.db_name_or_con_name_vw as
select
	case
		--Old version:
		when v$instance.version like '9.%' or v$instance.version like '10.%' or v$instance.version like '11.%' then
			sys_context('userenv', 'db_name')
		--New version but with old architecture:
		when sys_context('userenv', 'cdb_name') is null then
			sys_context('userenv', 'db_name')
		--New version, with multi-tenant, on the CDB$ROOT:
		when sys_context('userenv', 'con_name') = 'CDB$ROOT' then
			v$database.name
		--New version, with multi-tenant, on the PDB:
		else
			sys_context('userenv', 'con_name')
	end database_name,
	v$database.platform_name
from v$database cross join v$instance;
comment on table METHOD5.DB_NAME_OR_CON_NAME_VW is 'Get either the DB_NAME (for traditional architecture) or the CON_NAME (for multi-tenant architecture).  This is surprisingly difficult to do across all versions and over a database link.';
