-- This is a test suite to test different exception situation and 
-- verify that odi_proc.record_exception_error handles it.
--
-- Run each Step 1 to 5 one by one to verify result.

--
-- Step 1 Setup test suite with tables, temporary test procedure etc.
--

create table test_numbers(varde number);
create unique index ind1_test_numbers on test_numbers(varde);
delete from test_numbers;
delete from exception_error_log
where module in ('divizion_by_zero_test','calculate_circle_area_test','invalid_number_test','dup_val_on_index_test');
commit;

-- Verify divizion by zero
create or replace procedure divizion_by_zero_test as
	l_x      number := 1;
	l_y      number := 0;
	l_result number;
begin

	DBMS_APPLICATION_INFO.set_module(module_name => 'divizion_by_zero_test',
                                   action_name => 'testing divizion by zero.');
	DBMS_APPLICATION_INFO.set_client_info(client_info => 'used for TDD with utPLSQL.');										  

   -- here we test when others exceptions.
	l_result := l_x / l_y;
exception 
when zero_divide then
      record_exception_error();
      raise;
when others then
		record_exception_error();
      raise;
end divizion_by_zero_test;
/

-- Test for value or conversion error
-- We define our own exception for invalid number ORA-06502
create or replace function calculate_circle_area_test
   (
      in_radius_millimeter in varchar2
   ) return number 
is

   invalid_conversion exception;
   PRAGMA EXCEPTION_INIT(invalid_conversion, -6502);

   co_pi constant number := 3.14159;
   l_area_millimeter number;
   l_radius varchar2(100);

begin

	DBMS_APPLICATION_INFO.set_module(module_name => 'calculate_circle_area_test',
                                   action_name => 'calculate circle area in millimeter');
	DBMS_APPLICATION_INFO.set_client_info(client_info => 'used for TDD with utPLSQL.');										  
   l_radius := to_number(in_radius_millimeter);
   l_area_millimeter := (co_pi * abs(l_radius * l_radius));
   return l_area_millimeter;

exception 
   when invalid_conversion then
		record_exception_error();
      raise;
   when others then
      record_exception_error();
      raise;   

end calculate_circle_area_test;
/

-- Test for invalid number
create or replace procedure invalid_number_test is
BEGIN

	DBMS_APPLICATION_INFO.set_module(module_name => 'invalid_number_test',
                                   action_name => 'Try to insert invalid number');
	DBMS_APPLICATION_INFO.set_client_info(client_info => 'used for TDD with utPLSQL.');
   insert into test_numbers (varde) values('aaa');
   commit;

exception when invalid_number then
   record_exception_error();
   raise;

end invalid_number_test;
/

-- Test for dup_val_on_index
create or replace procedure dup_val_on_index_test is
BEGIN

   DBMS_APPLICATION_INFO.set_module(module_name => 'dup_val_on_index_test',
                                   action_name => 'Try to insert row on unique index');
	DBMS_APPLICATION_INFO.set_client_info(client_info => 'used for TDD with utPLSQL.');
   for i in 1..3 LOOP
     insert into test_numbers values(1);
   END LOOP;
   commit;

exception when dup_val_on_index then
   record_exception_error();
   raise;

end dup_val_on_index_test;
/


--************************************************************************************
-- Test package suite. This uses utPLSQL package and the tags defined like --%throws
-- to run a test suite to verify our expected exceptions are logged in exception_error_log
-- and that odi_proc.record_exception_error() works as intended.
--
-- See utPLSQL documentation on how to use the %tags
--************************************************************************************

--
-- Step 2 Setup the test packages with %tags for utPLSQL
--

create or replace package test_package as

   --%suite(Exception handling test suite.)

   --%test(Division by zero)
   --%throws(-01476) 
   procedure test_divizion_by_zero;

   --%test(Invalid conversion)
   --%throws(-06502)
   procedure test_invalid_conversion;

   --%test(Invalid numbers)
   --%throws(invalid_number)
   --%rollback(manual)
   procedure test_invalid_number;

   --%test(Duplicate value on index)
   --%throws(dup_val_on_index)
   --%rollback(manual)
   procedure test_dup_val_on_index;  

end test_package;
/

create or replace package body test_package as
   
   procedure test_divizion_by_zero is
   begin
     divizion_by_zero_test;
   end;

   procedure test_invalid_conversion is
      l_area number;
   begin
      l_area := calculate_circle_area_test(in_radius_millimeter => 'Hello');
   end;

   procedure test_invalid_number is
   BEGIN
      invalid_number_test;
   end;

   procedure test_dup_val_on_index is
   BEGIN
      dup_val_on_index_test;
   end;

end test_package;
/

--
-- Step 3 Run the tests. Should not give any errors!! all tests should pass
--

set serveroutput on
exec ut.run('test_package');

/**
Expected outout from Step 3 shoud be 0 failed.
*/

--
-- Step 4 Verify that we have log rows for all our test cases.
--

-- verify we haave a log row for divizion by zero exception.
with get_last_row as
(
   select max(created_on) as max_timestamp
   from EXCEPTION_ERROR_LOG
   where module = 'divizion_by_zero_test'
     and created_on > trunc(sysdate)
)
select expl.* 
from exception_error_log expl
inner join get_last_row
on expl.created_on = get_last_row.max_timestamp
where expl.module = 'divizion_by_zero_test'
  and expl.error_code = '-1476';

-- verify we have a log row for invalid conversion from string to number.
with get_last_row as
(
   select max(created_on) as max_timestamp
   from EXCEPTION_ERROR_LOG
   where module = 'calculate_circle_area_test'
     and created_on > trunc(sysdate)
)
select expl.* 
from exception_error_log expl
inner join get_last_row
on expl.created_on = get_last_row.max_timestamp
where expl.module = 'calculate_circle_area_test'
  and expl.error_code = '-6502';

-- verify we have a log row entry for invalid_number exception.
with get_last_row as
(
   select max(created_on) as max_timestamp
   from EXCEPTION_ERROR_LOG
   where module = 'invalid_number_test'
     and created_on > trunc(sysdate)
)
select expl.* 
from exception_error_log expl
inner join get_last_row
on expl.created_on = get_last_row.max_timestamp
where expl.module = 'invalid_number_test'
  and expl.error_code = '-1722';

--verify we have a log row entry for dup_val_on_index exception.
with get_last_row as
(
   select max(created_on) as max_timestamp
   from EXCEPTION_ERROR_LOG
   where module = 'dup_val_on_index_test'
     and created_on > trunc(sysdate)
)
select expl.* 
from exception_error_log expl
inner join get_last_row
on expl.created_on = get_last_row.max_timestamp
where expl.module = 'dup_val_on_index_test'
  and expl.error_code = '-1';


--
-- Step 5. Cleanup everything
--

drop package test_package;
drop procedure divizion_by_zero_test;
drop function calculate_circle_area_test;
drop procedure invalid_number_test;
drop procedure dup_val_on_index_test;
drop table test_numbers purge;
delete from exception_error_log
where module in ('divizion_by_zero_test','calculate_circle_area_test','invalid_number_test','dup_val_on_index_test');
commit;