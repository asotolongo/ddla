CREATE SCHEMA ddla;



CREATE TABLE ddla.ddl_logs (i serial , command character varying (50), obj character varying (128) , obj_type character varying (50), time_ddl timestamp, username  character varying (64) ,
ip character varying (30),  query text);

CREATE OR REPLACE FUNCTION ddla.f_trigger_ddla()
  RETURNS event_trigger AS
$BODY$
DECLARE
event_row record;
BEGIN
if lower(TG_EVENT)='ddl_command_end' then
	FOR event_row IN SELECT *
	FROM pg_event_trigger_ddl_commands() loop
	INSERT INTO  ddla.ddl_logs (command , obj , obj_type , time_ddl , username  ,ip, query)
	 VALUES (event_row.command_tag::character varying (50),event_row.object_identity:: character varying (128), event_row.object_type::character varying (50), current_timestamp::timestamp  , 
	  current_user::character varying (64), inet_client_addr(), current_query());
	END LOOP;
end if;	
	

if lower(TG_EVENT)='sql_drop' then	
      FOR event_row IN SELECT distinct * FROM pg_event_trigger_dropped_objects() loop
	if event_row.original then 
	INSERT INTO  ddla.ddl_logs (command , obj , obj_type , time_ddl , username  ,ip, query)
	 VALUES (tg_tag::character varying (50),event_row.object_identity:: character varying (128), event_row.object_type::character varying (50), current_timestamp::timestamp  , 
	  current_user::character varying (64), inet_client_addr(), current_query());
	end if;

	END LOOP;

end if;

END $BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



CREATE EVENT TRIGGER
notificador_ddl ON ddl_command_end
EXECUTE PROCEDURE ddla.f_trigger_ddla();

CREATE EVENT TRIGGER
drop_ddl ON sql_drop
EXECUTE PROCEDURE ddla.f_trigger_ddla();



create or replace function ddla.reset_logs() returns boolean as 
$$
TRUNCATE ddla.ddl_logs ;
select true;
$$
language sql;


create or replace function ddla.reset_id_seq_logs() returns boolean as 
$$
select ddla.reset_logs();
select setval('ddla.ddl_logs_i_seq', 1, false);
select true;
$$
language sql;


create or replace function ddla.get_ddl_cmd_by_user (p_username character varying(64)) returns 
table (cmd character varying(50), objs text, objs_types text, ts_ddl timestamp, ip_add character varying, qry text) as
$$
declare
begin
return query select command, string_agg(obj,','),string_agg(obj_type,','), time_ddl, ip, query from  ddla.ddl_logs  where username = $1 group by command, time_ddl, ip, query order by time_ddl;
end;
$$
language plpgsql;


create or replace function ddla.get_ddl_cmd_by_ts (p_ts_start timestamp,p_ts_end timestamp) returns 
table (cmd character varying(50), objs text, objs_types text, ts_ddl timestamp, usrname character varying (64),  ip_add character varying, qry text) as
$$
declare
begin
return query select command, string_agg(obj,','),string_agg(obj_type,','), time_ddl, username,  ip, query from  ddla.ddl_logs  where time_ddl>=$1 and time_ddl<=$2   group by command, time_ddl,username, ip, query order by time_ddl;
end;
$$
language plpgsql;




create or replace function ddla.get_ddl_cmd_by_cmd (p_cmd character varying (50)) returns 
table (objs text, objs_types text, ts_ddl timestamp, usrname character varying (64),  ip_add character varying, qry text) as
$$
declare
begin
return query select  string_agg(obj,','),string_agg(obj_type,','), time_ddl, username,  ip, query from  ddla.ddl_logs  where lower(command)=lower($1)   group by  time_ddl,username, ip, query order by time_ddl;
end;
$$
language plpgsql;

CREATE OR REPLACE  FUNCTION ddla.get_ddl_cmd_by_object_type(IN p_obj character varying)
  RETURNS TABLE(objs character varying, cmmd character varying, ts_ddl timestamp without time zone, usrname character varying, ip_add character varying, qry text) AS
$BODY$
declare
begin
return query select  obj,command, time_ddl, username,  ip, query from  ddla.ddl_logs  where lower(obj_type)=lower($1)    order by time_ddl;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
 ;

create or replace function ddla.get_ddl_cmd_stats () returns 
table (cmd text, calls integer) as
$$
declare
begin
return query with sub as (
select  distinct command::text, query from ddla.ddl_logs  )
select command, count(*)::int from sub group by command;
end;
$$
language plpgsql;

select ddla.reset_id_seq_logs();

