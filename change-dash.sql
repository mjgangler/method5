update test_table
    set host_name = replace(host_name,
    '-','_')
   where host_name like '%-%'
