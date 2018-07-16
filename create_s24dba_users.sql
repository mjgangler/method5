select * from table(m5(q'[create tablespace s24_users]'));

select * from table(m5(q'[CREATE PROFILE S24DBA_PROFILE LIMIT CPU_PER_SESSION UNLIMITED
CPU_PER_CALL UNLIMITED
CONNECT_TIME UNLIMITED
IDLE_TIME UNLIMITED
SESSIONS_PER_USER UNLIMITED
LOGICAL_READS_PER_SESSION UNLIMITED
LOGICAL_READS_PER_CALL UNLIMITED
PRIVATE_SGA UNLIMITED
COMPOSITE_LIMIT UNLIMITED
PASSWORD_LIFE_TIME UNLIMITED
PASSWORD_GRACE_TIME UNLIMITED
PASSWORD_REUSE_MAX UNLIMITED
PASSWORD_REUSE_TIME UNLIMITED
PASSWORD_LOCK_TIME DEFAULT
FAILED_LOGIN_ATTEMPTS UNLIMITED
PASSWORD_VERIFY_FUNCTION DEFAULT]'));

select * from table(m5(q'[create temporary tablespace temp]'));

select * from table(m5(q'[create user aghalke       identified by S24_Dba_Temp default tablespace s24_users temporary tablespace TEMP profile s24dba_profile]'));
select * from table(m5(q'[create user avejendia       identified by S24_Dba_Temp default tablespace s24_users temporary tablespace TEMP profile s24dba_profile]'));
select * from table(m5(q'[create user apallikonda   identified by S24_Dba_Temp default tablespace s24_users temporary tablespace TEMP profile s24dba_profile]'));
select * from table(m5(q'[create user cjohnston identified by S24_Dba_Temp default tablespace s24_users temporary tablespace TEMP profile s24dba_profile]'));
select * from table(m5(q'[create user dciulinaru    identified by S24_Dba_Temp default tablespace s24_users temporary tablespace TEMP profile s24dba_profile]'));
select * from table(m5(q'[create user ptutika          identified by S24_Dba_Temp default tablespace s24_users temporary tablespace TEMP profile s24dba_profile]'));
select * from table(m5(q'[create user nbuddhanna  identified by S24_Dba_Temp default tablespace s24_users temporary tablespace TEMP profile s24dba_profile]'));
select * from table(m5(q'[create user pkrauss      identified by S24_Dba_Temp default tablespace s24_users temporary tablespace TEMP profile s24dba_profile]'));
select * from table(m5(q'[create user rsiedlak      identified by S24_Dba_Temp default tablespace s24_users temporary tablespace TEMP profile s24dba_profile]'));
select * from table(m5(q'[create user spunukollu       identified by S24_Dba_Temp default tablespace s24_users temporary tablespace TEMP profile s24dba_profile]'));
select * from table(m5(q'[create user spasupuleti    identified by S24_Dba_Temp default tablespace s24_users temporary tablespace TEMP profile s24dba_profile]'));
select * from table(m5(q'[create user snamoju      identified by S24_Dba_Temp default tablespace s24_users temporary tablespace TEMP profile s24dba_profile]'));
select * from table(m5(q'[create user vkumar      identified by S24_Dba_Temp default tablespace s24_users temporary tablespace TEMP profile s24dba_profile]'));
select * from table(m5(q'[create user psaxena     identified by S24_Dba_Temp default tablespace s24_users temporary tablespace TEMP profile s24dba_profile]'));
select * from table(m5(q'[create user svenkatesan    identified by S24_Dba_Temp default tablespace s24_users temporary tablespace TEMP profile s24dba_profile]'));
select * from table(m5(q'[create user mgangler     identified by S24_Dba_Temp default tablespace s24_users temporary tablespace TEMP profile s24dba_profile]'));

select * from table(m5(q'[CREATE ROLE s24dba_ROLE]'));

select * from table(m5(q'[GRANT dba to s24dba_role with admin option]'));
select * from table(m5(q'[grant select any dictionary to s24dba_role]'));
select * from table(m5(q'[grant unlimited tablespace to s24dba_role]'));

select * from table(m5(q'[GRANT s24dba_role TO aghalke with admin option ]'));
select * from table(m5(q'[GRANT s24dba_role TO avejendia with admin option ]'));
select * from table(m5(q'[GRANT s24dba_role TO apallikonda with admin option ]'));
select * from table(m5(q'[GRANT s24dba_role TO cjohnston with admin option ]'));
select * from table(m5(q'[GRANT s24dba_role TO dciulinaru with admin option ]'));
select * from table(m5(q'[GRANT s24dba_role TO ptutika with admin option ]'));
select * from table(m5(q'[GRANT s24dba_role TO nbuddhanna with admin option ]'));
select * from table(m5(q'[GRANT s24dba_role TO pkrauss with admin option ]'));
select * from table(m5(q'[GRANT s24dba_role TO rsiedlak with admin option ]'));
select * from table(m5(q'[GRANT s24dba_role TO spunukollu with admin option ]'));
select * from table(m5(q'[GRANT s24dba_role TO spasupuleti with admin option ]'));
select * from table(m5(q'[GRANT s24dba_role TO snamoju with admin option ]'));
select * from table(m5(q'[GRANT s24dba_role TO vkumar with admin option ]'));
select * from table(m5(q'[GRANT s24dba_role TO psaxena with admin option ]'));
select * from table(m5(q'[GRANT s24dba_role TO svenkatesan with admin option ]'));
select * from table(m5(q'[GRANT s24dba_role TO mgangler with admin option ]'));


select * from table(m5(q'[GRANT unlimited tablespace TO aghalke with admin option ]'));
select * from table(m5(q'[GRANT unlimited tablespace TO avejendia with admin option ]'));
select * from table(m5(q'[GRANT unlimited tablespace TO apallikonda with admin option ]'));
select * from table(m5(q'[GRANT unlimited tablespace TO cjohnston with admin option ]'));
select * from table(m5(q'[GRANT unlimited tablespace TO dciulinaru with admin option ]'));
select * from table(m5(q'[GRANT unlimited tablespace TO ptutika with admin option ]'));
select * from table(m5(q'[GRANT unlimited tablespace TO nbuddhanna with admin option ]'));
select * from table(m5(q'[GRANT unlimited tablespace TO pkrauss with admin option ]'));
select * from table(m5(q'[GRANT unlimited tablespace TO rsiedlak with admin option ]'));
select * from table(m5(q'[GRANT unlimited tablespace TO spunukollu with admin option ]'));
select * from table(m5(q'[GRANT unlimited tablespace TO spasupuleti with admin option ]'));
select * from table(m5(q'[GRANT unlimited tablespace TO snamoju with admin option ]'));
select * from table(m5(q'[GRANT unlimited tablespace TO vkumar with admin option ]'));
select * from table(m5(q'[GRANT unlimited tablespace TO psaxena with admin option ]'));
select * from table(m5(q'[GRANT unlimited tablespace to svenkatesan with admin option ]'));
select * from table(m5(q'[GRANT unlimited tablespace TO mgangler with admin option ]'));

select * from table(m5(q'[GRANT select any dictionary TO aghalke with admin option ]'));
select * from table(m5(q'[GRANT select any dictionary TO avejendia with admin option ]'));
select * from table(m5(q'[GRANT select any dictionary TO apallikonda with admin option ]'));
select * from table(m5(q'[GRANT select any dictionary TO cjohnston with admin option ]'));
select * from table(m5(q'[GRANT select any dictionary TO dciulinaru with admin option ]'));
select * from table(m5(q'[GRANT select any dictionary TO ptutika with admin option ]'));
select * from table(m5(q'[GRANT select any dictionary TO nbuddhanna with admin option ]'));
select * from table(m5(q'[GRANT select any dictionary TO pkrauss with admin option ]'));
select * from table(m5(q'[GRANT select any dictionary TO rsiedlak with admin option ]'));
select * from table(m5(q'[GRANT select any dictionary TO spunukollu with admin option ]'));
select * from table(m5(q'[GRANT select any dictionary TO spasupuleti with admin option ]'));
select * from table(m5(q'[GRANT select any dictionary TO snamoju with admin option ]'));
select * from table(m5(q'[GRANT select any dictionary TO vkumar with admin option ]'));
select * from table(m5(q'[GRANT select any dictionary TO psaxena with admin option ]'));
select * from table(m5(q'[GRANT select any dictionary to svenkatesan with admin option ]'));
select * from table(m5(q'[GRANT select any dictionary TO mgangler with admin option ]'));

