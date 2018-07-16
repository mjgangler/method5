begin
	m5_proc(
	p_targets => 'Production',
	p_code => q'[

select  'Datafiles:     '                                               as c0
        ,round((sum(d.bytes)/1024/1024),4)                              as c1
        ,round((sum(d.bytes)/1024/1024/1024),4)                         as c2
from    v$datafile d
union all
select  'Tempfiles:     '                                               as c0
        ,round((sum(d.bytes)/1024/1024),4)                              as c1
        ,round((sum(d.bytes)/1024/1024/1024),4)                         as c2
from    v$tempfile d
union all
select  'Controlfiles:  '                                               as c0
        ,round(((BLOCK_SIZE*FILE_SIZE_BLKS)/1024/1024),4)               as c1
        ,round(((BLOCK_SIZE*FILE_SIZE_BLKS)/1024/1024/1024),4)          as c2
from v$controlfile
union all
select  'Redologs:'                                                     as c0
        ,round((sum(BYTES)/1024/1024),4)                                as c1
        ,round((sum(BYTES)/1024/1024/1024),4)                           as c2
from    gv$log
union all
select  'Standby Redologs:'                                             as c0
        ,round((sum(BYTES)/1024/1024),4)                                as c1
        ,round((sum(BYTES)/1024/1024/1024),4)                           as c2
from    gv$standby_log;
]'
);
end;



