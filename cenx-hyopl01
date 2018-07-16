create or replace procedure sys.m5_run_shell_script(p_script in clob, p_table_name in varchar2) is
--------------------------------------------------------------------------------
--Purpose: Execute a shell script and store results in a table.
--Parameters:
--	p_script - A shell script that starts with a shebang and will be
--		run by the Oracle software owner.
--	p_table_name - The table to store the results.
--Side-Effects: Creates the table P_TABLE_NAME in the Method5 schema, with results.
--Requires:
--	Must be run as SYS because only SYS jobs are run as the Oracle owner.
--	Only works on Unix and Linux.
--	Oracle software owner must be able to read and write to /tmp/
--Notes:
--	The scheduler overhead always adds a few seconds to the run time.
--
--Copyright (C) 2017 Jon Heller, Ventech Solutions, and CMS.  This program is licensed under the LGPLv3.
--Version 1.0.3
--Read this page if you're curious about this program or concerned about security implications:
--https://github.com/method5/method5/blob/master/security.md

	--This unique string prevents operating system duplicates.
	c_unique_string varchar2(100) := to_char(sysdate, 'YYYY_MM_DD_HH24_MI_SS_')||rawtohex(sys_guid());
	--This random number prevents Oracle duplicates.
	c_random_number varchar2(100) := to_char(trunc(dbms_random.value*100000000));

	c_script_file_name constant varchar2(100) := 'm5_script_'||c_unique_string||'.sh';
	c_redirect_file_name constant varchar2(100) := 'm5_redirect_'||c_unique_string||'.sh';
	c_output_file_name constant varchar2(100) := 'm5_output_'||c_unique_string||'.out';

	c_temp_path constant varchar2(100) := '/tmp/method5/';
	c_directory constant varchar2(100) := 'M5_TMP_DIR';
	c_bin_directory constant varchar2(100) := '/bin/';

	v_job_failed exception;
	pragma exception_init(v_job_failed, -27369);

	pragma autonomous_transaction;


	------------------------------------------------------------------------------
	procedure create_file(p_directory varchar2, p_file_name varchar2, p_text clob) is
		v_file_type utl_file.file_type;
	begin
		v_file_type := utl_file.fopen(p_directory, p_file_name, 'W', 32767);
		utl_file.put(v_file_type, p_text);
		utl_file.fclose(v_file_type);
	end create_file;


	------------------------------------------------------------------------------
	--Purpose: Check if the directory /tmp/method5 exists.
	function does_tmp_method5_dir_not_exist return boolean is
		v_file_type utl_file.file_type;
		v_invalid_file_operation exception;
		pragma exception_init(v_invalid_file_operation, -29283);
	begin
		--Try to create a test file on the directory.
		--If it fails, then the directory does not exist.
		create_file(
			p_directory => c_directory,
			p_file_name => 'test_if_method5_directory_exists.txt',
			p_text      => 'This file only exists to quickly check the existence of a file.'
		);

		--The directory exists if we got this far.
		return false;
	exception when v_invalid_file_operation then
		return true;
	end does_tmp_method5_dir_not_exist;


	------------------------------------------------------------------------------
	--Purpose: Create the Method5 operating system directory.
	procedure create_os_directory is
	begin
		--Create program.
		dbms_scheduler.create_program (
			program_name        => 'M5_TEMP_MKDIR_PROGRAM_'||c_random_number,
			program_type        => 'EXECUTABLE',
			program_action      => c_bin_directory||'mkdir',
			number_of_arguments => 1,
			comments            => 'Temporary program created for Method5.  Created on: '||to_char(systimestamp, 'YYYY-MM-DD HH24:MI:SS')
		);

		--Create program arguments.
		dbms_scheduler.define_program_argument(
			program_name      => 'M5_TEMP_MKDIR_PROGRAM_'||c_random_number,
			argument_position => 1,
			argument_name     => 'M5_TEMP_MKDIR_ARGUMENT_1',
			argument_type     => 'VARCHAR2'
		);

		dbms_scheduler.enable('M5_TEMP_MKDIR_PROGRAM_'||c_random_number);

		--Create job.
		dbms_scheduler.create_job (
			job_name     => 'M5_TEMP_MKDIR_JOB_'||c_random_number,
			program_name => 'M5_TEMP_MKDIR_PROGRAM_'||c_random_number,
			comments     => 'Temporary job created for Method5.  Created on: '||to_char(systimestamp, 'YYYY-MM-DD HH24:MI:SS')
		);

		--Create job argument values.
		dbms_scheduler.set_job_argument_value(
			job_name       => 'M5_TEMP_MKDIR_JOB_'||c_random_number,
			argument_name  => 'M5_TEMP_MKDIR_ARGUMENT_1',
			argument_value => '/tmp/method5/'
		);

		--Run job synchronously.  This works even if JOB_QUEUE_PROCESSES=0.
		begin
			dbms_scheduler.run_job('M5_TEMP_MKDIR_JOB_'||c_random_number);
		exception when others then
			--Ignore errors if the file exists.
			if sqlerrm like '%File exists%' then
				null;
			else
				raise;
			end if;
		end;

	end create_os_directory;


	------------------------------------------------------------------------------
	--Purpose: Create the Oracle directory, if it does not exist.
	procedure create_ora_dir_if_not_exists is
		v_count number;
	begin
		--Check for existing directory.
		select count(*)
		into v_count
		from all_directories
		where directory_name = c_directory
			and directory_path = c_temp_path;

		--Create if it doesn't exist.
		if v_count = 0 then
			execute immediate 'create or replace directory '||c_directory||' as '''||c_temp_path||'''';
		end if;
	end create_ora_dir_if_not_exists;


	------------------------------------------------------------------------------
	--Parameters:
	--	p_mode: The chmod mode, for example: u+x
	--	p_file: The full path to a single file.  Cannot include multiple files
	--		or any globbing.  E.g., no "*" in the file name.
	procedure chmod(p_mode varchar2, p_file varchar2) is
	begin
		--Create program.
		dbms_scheduler.create_program (
			program_name        => 'M5_TEMP_CHMOD_PROGRAM_'||c_random_number,
			program_type        => 'EXECUTABLE',
			program_action      => c_bin_directory||'chmod',
			number_of_arguments => 2,
			comments            => 'Temporary program created for Method5.  Created on: '||to_char(systimestamp, 'YYYY-MM-DD HH24:MI:SS')
		);

		--Create program arguments.
		dbms_scheduler.define_program_argument(
			program_name      => 'M5_TEMP_CHMOD_PROGRAM_'||c_random_number,
			argument_position => 1,
			argument_name     => 'M5_TEMP_CHMOD_ARGUMENT_1',
			argument_type     => 'VARCHAR2'
		);
		dbms_scheduler.define_program_argument(
			program_name      => 'M5_TEMP_CHMOD_PROGRAM_'||c_random_number,
			argument_position => 2,
			argument_name     => 'M5_TEMP_CHMOD_ARGUMENT_2',
			argument_type     => 'VARCHAR2'
		);

		dbms_scheduler.enable('M5_TEMP_CHMOD_PROGRAM_'||c_random_number);

		--Create job.
		dbms_scheduler.create_job (
			job_name     => 'M5_TEMP_CHMOD_JOB_'||c_random_number,
			program_name => 'M5_TEMP_CHMOD_PROGRAM_'||c_random_number,
			comments     => 'Temporary job created for Method5.  Created on: '||to_char(systimestamp, 'YYYY-MM-DD HH24:MI:SS')
		);

		--Create job argument values.
		dbms_scheduler.set_job_argument_value(
			job_name       => 'M5_TEMP_CHMOD_JOB_'||c_random_number,
			argument_name  => 'M5_TEMP_CHMOD_ARGUMENT_1',
			argument_value => p_mode
		);
		dbms_scheduler.set_job_argument_value(
			job_name       => 'M5_TEMP_CHMOD_JOB_'||c_random_number,
			argument_name  => 'M5_TEMP_CHMOD_ARGUMENT_2',
			argument_value => p_file
		);

		--Run job synchronously.  This works even if JOB_QUEUE_PROCESSES=0.
		dbms_scheduler.run_job('M5_TEMP_CHMOD_JOB_'||c_random_number);
	end chmod;


	------------------------------------------------------------------------------
	procedure run_script(p_full_path_to_file varchar2) is
	begin
		--Create program.
		dbms_scheduler.create_program (
			program_name   => 'M5_TEMP_RUN_PROGRAM_'||c_random_number,
			program_type   => 'EXECUTABLE',
			program_action => p_full_path_to_file,
			enabled        => true,
			comments       => 'Temporary program created for Method5.  Created on: '||to_char(systimestamp, 'YYYY-MM-DD HH24:MI:SS')
		);

		--Create job.
		dbms_scheduler.create_job (
			job_name     => 'M5_TEMP_RUN_JOB_'||c_random_number,
			program_name => 'M5_TEMP_RUN_PROGRAM_'||c_random_number,
			comments     => 'Temporary job created for Method5.  Created on: '||to_char(systimestamp, 'YYYY-MM-DD HH24:MI:SS')
		);

		--Run job synchronously.  This works even if JOB_QUEUE_PROCESSES=0.
		dbms_scheduler.run_job('M5_TEMP_RUN_JOB_'||c_random_number);
	end run_script;


	------------------------------------------------------------------------------
	procedure create_external_table(p_directory varchar2, p_script_output_file_name varchar2) is
	begin
		execute immediate '
		create table sys.m5_temp_output_'||c_random_number||'(output varchar2(4000))
		organization external
		(
			type oracle_loader default directory '||p_directory||'
			access parameters
			(
				records delimited by newline
				fields terminated by ''only_one_line_never_terminate_fields''
				missing field values are null
			)
			location ('''||p_script_output_file_name||''')
		)
		reject limit unlimited';
	end create_external_table;


	------------------------------------------------------------------------------
	--Purpose: Drop new jobs, programs, and tables so they don't clutter the data dictionary.
	procedure drop_new_objects is
	begin
		--Note how the "M5_TEMP" is double hard-coded.
		--This ensure we will never, ever, drop the wrong SYS object.

		--Drop new jobs.
		for jobs_to_drop in
		(
			select replace(job_name, 'M5_TEMP') job_name
			from user_scheduler_jobs
			where job_name like 'M5_TEMP%'||c_random_number
			order by job_name
		) loop
			dbms_scheduler.drop_job('M5_TEMP'||jobs_to_drop.job_name);
		end loop;

		--Drop new programs.
		for programs_to_drop in
		(
			select replace(program_name, 'M5_TEMP') program_name
			from user_scheduler_programs
			where program_name like 'M5_TEMP%'||c_random_number
			order by program_name
		) loop
			dbms_scheduler.drop_program('M5_TEMP'||programs_to_drop.program_name);
		end loop;

		--Drop new tables.
		for tables_to_drop in
		(
			select replace(table_name, 'M5_TEMP') table_name
			from user_tables
			where table_name like 'M5_TEMP%'||c_random_number
			order by table_name
		) loop
			--Hard-code the M5_TEMP_STD to ensure that we never, ever, ever drop the wrong table.
			execute immediate 'drop table M5_TEMP'||tables_to_drop.table_name||' purge';
		end loop;
	end drop_new_objects;


	------------------------------------------------------------------------------
	--Purpose: Drop old jobs, programs, and tables that may not have been properly dropped before.
	--  This may happen if previous runs did not end cleanly.
	procedure cleanup_old_objects is
	begin
		--Note how the "M5_TEMP" is double hard-coded.
		--This ensure we will never, ever, drop the wrong SYS object.

		--Delete all non-running Method5 temp jobs after 2 days.
		for jobs_to_drop in
		(
			select replace(job_name, 'M5_TEMP') job_name
			from user_scheduler_jobs
			where job_name like 'M5_TEMP%'
				and replace(comments, 'Temporary job created for Method5.  Created on: ') < to_char(systimestamp - interval '2' day, 'YYYY-MM-DD HH24:MI:SS')
				and job_name not in (select job_name from user_scheduler_running_jobs)
			order by job_name
		) loop
			dbms_scheduler.drop_job('M5_TEMP'||jobs_to_drop.job_name);
		end loop;

		--Delete all Method5 temp programs after 2 days.
		for programs_to_drop in
		(
			select replace(program_name, 'M5_TEMP') program_name
			from user_scheduler_programs
			where program_name like 'M5_TEMP%'
				and replace(comments, 'Temporary program created for Method5.  Created on: ') < to_char(systimestamp - interval '2' day, 'YYYY-MM-DD HH24:MI:SS')
			order by program_name
		) loop
			dbms_scheduler.drop_program('M5_TEMP'||programs_to_drop.program_name);
		end loop;

		--Drop old tables after 7 days.
		--The tables don't use any space and are unlikely to ever be noticed
		--so it doesn't hurt to keep them around for a while.
		for tables_to_drop in
		(
			select replace(object_name, 'M5_TEMP') table_name
			from user_objects
			where object_type = 'TABLE'
				and object_name like 'M5_TEMP_STD%'
				and created < systimestamp - interval '7' day
			order by object_name
		) loop
			execute immediate 'drop table M5_TEMP'||tables_to_drop.table_name||' purge';
		end loop;
	end cleanup_old_objects;
begin
	--Create directories if necessary.
	create_ora_dir_if_not_exists;

	if does_tmp_method5_dir_not_exist then
		create_os_directory;
		chmod('700', c_temp_path);
		--Drop some objects now because chmod will be called again later.
		drop_new_objects;
	end if;

	--Create empty output file in case nothing gets written later.  External tables require a file to exist.
	create_file(c_directory, c_output_file_name, null);

	--Create script file, that will write data to standard output.
	create_file(c_directory, c_script_file_name, p_script);

	--Create script redirect file, that executes script and redirects output to the output file.
	--This is necessary because redirection does not work in Scheduler.
	create_file(c_directory, c_redirect_file_name,
		'#!/bin/sh'||chr(10)||
		'chmod 700 '||c_temp_path||c_script_file_name||chr(10)||
		'chmod 600 '||c_temp_path||c_output_file_name||chr(10)||
		c_temp_path||c_script_file_name||' > '||c_temp_path||c_output_file_name||' 2>'||chr(38)||'1'
	);

	--Chmod the redirect file.
	--The CHMOD job is slow, so most chmoding is done inside the redirect script.
	--Unfortunately CHMOD through the scheduler does not support "*", it would throw this error:
	--ORA-27369: job of type EXECUTABLE failed with exit code: 1 chmod: WARNING: can't access /tmp/method5/m5*.out
	chmod('700', c_temp_path||c_redirect_file_name);

	--Run script and redirect output and error to other files.
	--(External table preprocessor script doesn't work in our environments for some reason.)
	begin
		run_script(c_temp_path||c_redirect_file_name);
	exception when v_job_failed then
		null;
	end;

	--Create external tables to read the output.
	create_external_table(c_directory, c_output_file_name);

	--Create table with results.
	--(A view would have some advantages here, but would also require a lot of
	--extra permissions on the underlying tables and directories.)
	execute immediate replace(replace(
	q'!
		create table method5.#TABLE_NAME# nologging pctfree 0 as
		select rownum line_number, cast(output as varchar2(4000)) output from M5_TEMP_OUTPUT_#RANDOM_NUMBER#
	!', '#RANDOM_NUMBER#', c_random_number), '#TABLE_NAME#', p_table_name);

	--Cleanup.
	drop_new_objects;
	cleanup_old_objects;
end m5_run_shell_script;
/
