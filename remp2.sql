select 'scp method5_install_v5 '||host_name||':/home/oracle '
       from test_table_19jun18 o
       where line_of_business not in ('tico','trw','emb','msp')
        and target_version not like ('10.%')
        and lifecycle_status not in ('Production')
       and not exists
      (select 1 from method5.m5_database i
      where i.host_name = o.host_name)
    order by host_name
