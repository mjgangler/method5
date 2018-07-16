insert into method5.m5_database(
	host_name, database_name, instance_name, lifecycle_status, line_of_business, target_version, 
	operating_system, cluster_name, description, point_of_contact, app_connect_string, m5_default_connect_string
)
select
	host_name,
	database_name,
	instance_name,
	lifecycle_status,
	cost_center,
	target_version,
	operating_system,
	cluster_name,
	user_comment,
	contact,
	connect_string,
	connect_string
from
(
	--OEM data slightly transformed to fit into M5_DATABASE.
	select
		target_guid,
		--Make host, database, and instance name always lower case to simplify searching.
		--Remove the domain name from any fully qualified domain names, to simplify searching.
		--(This assumes your organization has unique domain names.)
		lower(regexp_replace(host_name, '\..*', null)) host_name,
		lower(database_name) database_name,
		lower(instance_name) instance_name,
		lifecycle_status,
		cost_center,
		target_version,
		operating_system,
		user_comment,
		contact,
		cluster_name,
		lower(replace(replace(
				--'(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=$host_name)(PORT=1521))(CONNECT_DATA=(SID=$instance_name))) ',
				--service_name may work better for some organizations:
				'(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=$host_name)(PORT=1528))(CONNECT_DATA=(SERVICE_NAME=$instance_name))) ',
			'$instance_name', instance_name)
			,'$host_name', host_name)
		) as connect_string
	from
	(
		--Raw Data from Oracle Enterprise Manager.
		select
			instance.target_guid,
			instance.host_name,
			instance.database_name,
			instance.instance_name, --may be case sensitive!
			properties.lifecycle_status,
			properties.cost_center,
			properties.target_version,
			properties.operating_system,
			properties.user_comment,
			properties.contact,
			rac_topology.cluster_name,
			sysdate refresh_date
		from sysman.mgmt$db_dbninstanceinfo instance
		join sysman.em_global_target_properties properties
			on instance.target_guid = properties.target_guid
		left join
		(
			select distinct cluster_name, db_instance_name
			from sysman.mgmt$rac_topology
		) rac_topology
			on instance.target_name = rac_topology.db_instance_name
		where instance.target_type = 'oracle_database'
          and instance.host_name in ('agii-orapl05')
          and instance.database_name in ('PPRMPD','ADLUK')
		order by instance.host_name, instance.database_name, instance.instance_name
	) oem_data
	order by host_name, database_name, instance_name
);

