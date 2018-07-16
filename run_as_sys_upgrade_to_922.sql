create or replace procedure sys.get_method5_hashes
--Purpose: Method5 administrators need access to the password hashes.
--But the table SYS.USER$ is hidden in 12c, we only want to expose this one hash.
--
--TODO 1: http://www.red-database-security.com/wp/best_of_oracle_security_2015.pdf
--	The 12c hash is incredibly insecure.  Is it safe to remove the "H:" hash?
--TODO 2: Is there a way to derive the 10g hash from the 12c H: hash?
--	Without that, 12c local does not support remote 10g or 11g with case insensitive passwords.
(
	p_12c_hash in out varchar2,
	p_11g_hash_without_des in out varchar2,
	p_11g_hash_with_des in out varchar2,
	p_10g_hash in out varchar2
) is
begin
	--10 and 11g.
	$if dbms_db_version.ver_le_11_2 $then
		select
			spare4,
			spare4 hash_without_des,
			spare4||';'||password hash_with_des,
			password
		into p_12c_hash, p_11g_hash_without_des, p_11g_hash_with_des, p_10g_hash
		from sys.user$
		where name = 'METHOD5';
	--12c.
	$else
		select
			spare4,
			regexp_substr(spare4, 'S:.{60}'),
			regexp_substr(spare4, 'S:.{60}')||';'||password hash_with_des,
			password
		into p_12c_hash, p_11g_hash_without_des, p_11g_hash_with_des, p_10g_hash
		from sys.user$
		where name = 'METHOD5';
	$end
end;
/
