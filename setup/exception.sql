--drop table exception_error_log purge;

CREATE TABLE exception_error_log
(
   ERROR_CODE      INTEGER
 ,  module          VARCHAR2(128)
 ,  action          VARCHAR2(128)
 ,  error_message   VARCHAR2 (4000)
 ,  backtrace       CLOB
 ,  callstack       CLOB
 ,  errorstack      CLOB
 --,  developer_trace CLOB
 ,  lang            VARCHAR2(128)
 ,  server_host     VARCHAR2(4000)
 ,  session_id      VARCHAR2(128)
 ,  terminal        VARCHAR2(128)
 ,  nls_client      VARCHAR2(128)
 ,  created_on      TIMESTAMP (6) WITH LOCAL TIME ZONE
 ,  created_by      VARCHAR2 (30)
 ,  proxy_user      VARCHAR2(128)
);


create or replace procedure record_exception_error
/**

   Created by: Ulf Hellstrom, EpicoTech AB
   Date:       2024-07-08
   Version:    1.0
   Updated by:
   History:    Release 1.0 2024-07-08 First release using TDD with complement testcases.
   TODO:       N/A
   Description:

   The provided PL/SQL procedure is intended to use to log exceptions in own developed code
   for easier debugging and probability to create testcases for code.

   The provided PL/SQL procedure, record_exception_error, uses autonomous transactions to log exceptions to persistant
   storage into a logging table in PL/SQL code.

   Key Functionality:

   Using autonomous transaction log the backtrace , the error into exception_error_log.
   Procedure and table is public so it can be called from any other schema that has been granted
   the privilige to create procedure, function and packages.

   For best practices always use record_exception_error() together with dbms_application_info().
   This will record both module and action in exception_error_log making it easier to find
   and analyze the error for a given program unit.

   Example on usage:

   begin
      dbms_application_info.set_module('<module name>');
      dbms_application_info.set_action('action description');
      ..
      <your code here>
      ..
   when others then
      record_exception_error();
      raise
   end;

   See provided test-suite using utPLSQL for examples on how to use record_exception_error (gitlab backend repo)
   The code block will log the error and raise the error to stdout (could be logfile if background job or output in developer tool or sqlplus,sqlcl).
*/
is

   pragma autonomous_transaction;

	l_code   pls_integer := sqlcode;
	l_mesg   varchar2(32767) := sqlerrm;
	l_module varchar2(128);
	l_action varchar2(128);

begin

	dbms_application_info.read_module(l_module,l_action);

	insert into exception_error_log (
		error_code,
		module,
		action,
		error_message,
		backtrace,
		callstack,
		errorstack,
		lang,
		server_host,
		session_id,
		terminal,
		nls_client,
		created_on,
		created_by,
      proxy_user
	) values (
		l_code,
		nvl(l_module,'No Module defined.'),
		nvl(l_action,'No action defined'),
		l_mesg,
		sys.dbms_utility.format_error_backtrace,
		sys.dbms_utility.format_call_stack,
		sys.dbms_utility.format_error_stack,
      sys_context('USERENV','LANGUAGE'),
		sys_context('USERENV','SERVER_HOST'),
		sys_context('USERENV','SESSIONID'),
		sys_context('USERENV','TERMINAL'),
		sys_context('USERENV','NLS_DATE_FORMAT'),
		systimestamp,
		sys_context('USERENV','SESSION_USER'),
      sys_context('USERENV','PROXY_USER')
	);
	commit;
end;
/

-- Make API Public.
grant execute on record_exception_error to public;
create or replace public synonym record_exception_error for record_exception_error;
create or replace public synonym exception_error_log for exception_error_log;
