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
          and instance.host_name like ('alny')
        order by instance.host_name, instance.database_name, instance.instance_name
