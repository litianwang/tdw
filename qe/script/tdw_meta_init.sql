--
-- PostgreSQL database cluster dump
--

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

--
-- Roles
--

--NOTE: change the password in production evn 
CREATE ROLE tdw;
ALTER ROLE tdw WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN NOREPLICATION PASSWORD 'md56d713efc51a858219e00d60efacf6031';

--NOTE: change the password in production evn 
CREATE ROLE tdwmeta;
ALTER ROLE tdwmeta WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN NOREPLICATION PASSWORD 'md58d7da909fc522bf51b3f21cb64193b06';

--for pgdata test,add a pg user 'root',with password set to 'tdwroot'
--NOTE: change the password in production evn 
CREATE ROLE root;
ALTER ROLE root WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN NOREPLICATION PASSWORD 'md5c42560909c2dd6122db208225fff54fe';

--
-- Database creation
--

CREATE DATABASE global WITH TEMPLATE = template0 OWNER = tdwmeta;
CREATE DATABASE pbjar WITH TEMPLATE = template0 OWNER = tdwmeta;
CREATE DATABASE seg_1 WITH TEMPLATE = template0 OWNER = tdwmeta;
CREATE DATABASE tdw WITH TEMPLATE = template0 OWNER = tdw;
REVOKE ALL ON DATABASE template1 FROM PUBLIC;
GRANT CONNECT ON DATABASE template1 TO PUBLIC;


\connect global

--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';

SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: dbpriv; Type: TABLE; Schema: public; Owner: tdwmeta; Tablespace: 
--

CREATE TABLE dbpriv (
    alter_priv boolean DEFAULT false NOT NULL,
    create_priv boolean DEFAULT false NOT NULL,
    createview_priv boolean DEFAULT false NOT NULL,
    delete_priv boolean DEFAULT false NOT NULL,
    drop_priv boolean DEFAULT false NOT NULL,
    index_priv boolean DEFAULT false NOT NULL,
    insert_priv boolean DEFAULT false NOT NULL,
    select_priv boolean DEFAULT false NOT NULL,
    showview_priv boolean DEFAULT false NOT NULL,
    update_priv boolean DEFAULT false NOT NULL,
    user_name character varying NOT NULL,
    db_name character varying NOT NULL,
    out_of_date_time timestamp without time zone,
    start_date_time timestamp without time zone DEFAULT now(),
    CONSTRAINT must_lower CHECK (((lower((db_name)::text) = (db_name)::text) AND (lower((user_name)::text) = (user_name)::text)))
);


ALTER TABLE public.dbpriv OWNER TO tdwmeta;

--
-- Name: dbsensitivity; Type: TABLE; Schema: public; Owner: tdwmeta; Tablespace: 
--

CREATE TABLE dbsensitivity (
    db_name character varying NOT NULL,
    sensitivity integer DEFAULT 0,
    create_time timestamp without time zone,
    update_time timestamp without time zone,
    detail character varying,
    CONSTRAINT must_lower CHECK ((lower((db_name)::text) = (db_name)::text))
);


ALTER TABLE public.dbsensitivity OWNER TO tdwmeta;

--
-- Name: router; Type: TABLE; Schema: public; Owner: tdwmeta; Tablespace: 
--

CREATE TABLE router (
    db_name character varying NOT NULL,
    seg_addr character varying NOT NULL,
    secondary_seg_addr character varying,
    is_db_split boolean DEFAULT false,
    hashcode integer NOT NULL,
    describe character varying,
    owner character varying
);


ALTER TABLE public.router OWNER TO tdwmeta;

--
-- Name: seg_split; Type: TABLE; Schema: public; Owner: tdwmeta; Tablespace: 
--

CREATE TABLE seg_split (
    seg_addr character varying NOT NULL,
    seg_accept_range int4range
);


ALTER TABLE public.seg_split OWNER TO tdwmeta;

insert into seg_split values('jdbc:postgresql://127.0.0.1:5432/seg_1','[0,10000)');

--
-- Name: tblpriv; Type: TABLE; Schema: public; Owner: tdwmeta; Tablespace: 
--

CREATE TABLE tblpriv (
    alter_priv boolean DEFAULT false NOT NULL,
    create_priv boolean DEFAULT false NOT NULL,
    delete_priv boolean DEFAULT false NOT NULL,
    drop_priv boolean DEFAULT false NOT NULL,
    index_priv boolean DEFAULT false NOT NULL,
    insert_priv boolean DEFAULT false NOT NULL,
    select_priv boolean DEFAULT false NOT NULL,
    update_priv boolean DEFAULT false NOT NULL,
    user_name character varying NOT NULL,
    db_name character varying NOT NULL,
    tbl_name character varying NOT NULL,
    out_of_date_time timestamp without time zone,
    start_date_time timestamp without time zone DEFAULT now(),
    CONSTRAINT must_lower CHECK ((((lower((db_name)::text) = (db_name)::text) AND (lower((user_name)::text) = (user_name)::text)) AND (lower((tbl_name)::text) = (tbl_name)::text)))
);


ALTER TABLE public.tblpriv OWNER TO tdwmeta;

--
-- Name: tblsensitivity; Type: TABLE; Schema: public; Owner: tdwmeta; Tablespace: 
--

CREATE TABLE tblsensitivity (
    db_name character varying NOT NULL,
    tbl_name character varying NOT NULL,
    sensitivity integer,
    create_time timestamp without time zone,
    update_time timestamp without time zone,
    detail character varying,
    CONSTRAINT must_lower CHECK (((lower((tbl_name)::text) = (tbl_name)::text) AND (lower((db_name)::text) = (db_name)::text)))
);


ALTER TABLE public.tblsensitivity OWNER TO tdwmeta;

--
-- Name: tdw_badpbfile_skip_log; Type: TABLE; Schema: public; Owner: tdwmeta; Tablespace: 
--

CREATE TABLE tdw_badpbfile_skip_log (
    queryid character varying NOT NULL,
    mrid character varying NOT NULL,
    badfilenum bigint,
    logtime timestamp without time zone DEFAULT now()
);


ALTER TABLE public.tdw_badpbfile_skip_log OWNER TO tdwmeta;

--
-- Name: tdw_db_router; Type: VIEW; Schema: public; Owner: tdwmeta
--

CREATE VIEW tdw_db_router AS
    SELECT "substring"((router.seg_addr)::text, 'jdbc:postgresql://#"_{10,16}#":_{4,5}/%'::text, '#'::text) AS host, "substring"((router.seg_addr)::text, 'jdbc:postgresql://%:#"_{4,5}#"/%'::text, '#'::text) AS port, "substring"((router.seg_addr)::text, 'jdbc:postgresql://%/#"%#"'::text, '#'::text) AS meta_db_name, router.db_name AS tdw_db_name, router.hashcode FROM router;


ALTER TABLE public.tdw_db_router OWNER TO tdwmeta;

--
-- Name: tdwrole; Type: TABLE; Schema: public; Owner: tdwmeta; Tablespace: 
--

CREATE TABLE tdwrole (
    alter_priv boolean DEFAULT false NOT NULL,
    create_priv boolean DEFAULT false NOT NULL,
    createview_priv boolean DEFAULT false NOT NULL,
    dba_priv boolean DEFAULT false NOT NULL,
    delete_priv boolean DEFAULT false NOT NULL,
    drop_priv boolean DEFAULT false NOT NULL,
    index_priv boolean DEFAULT false NOT NULL,
    insert_priv boolean DEFAULT false NOT NULL,
    select_priv boolean DEFAULT false NOT NULL,
    showview_priv boolean DEFAULT false NOT NULL,
    update_priv boolean DEFAULT false NOT NULL,
    map_num bigint DEFAULT 300 NOT NULL,
    reduce_num bigint DEFAULT 300 NOT NULL,
    create_time timestamp without time zone DEFAULT now() NOT NULL,
    role_name character varying NOT NULL,
    product_name character varying,
    home_dir character varying,
    out_of_date_time timestamp without time zone,
    CONSTRAINT must_lower CHECK ((lower((role_name)::text) = (role_name)::text))
);


ALTER TABLE public.tdwrole OWNER TO tdwmeta;

--
-- Name: tdwuser; Type: TABLE; Schema: public; Owner: tdwmeta; Tablespace: 
--

CREATE TABLE tdwuser (
    alter_priv boolean DEFAULT false NOT NULL,
    create_priv boolean DEFAULT false NOT NULL,
    createview_priv boolean DEFAULT false NOT NULL,
    dba_priv boolean DEFAULT false NOT NULL,
    delete_priv boolean DEFAULT false NOT NULL,
    drop_priv boolean DEFAULT false NOT NULL,
    index_priv boolean DEFAULT false NOT NULL,
    insert_priv boolean DEFAULT false NOT NULL,
    select_priv boolean DEFAULT false NOT NULL,
    showview_priv boolean DEFAULT false NOT NULL,
    update_priv boolean DEFAULT false NOT NULL,
    create_time timestamp without time zone DEFAULT now() NOT NULL,
    expire_time timestamp without time zone,
    timetolive bigint DEFAULT (-1) NOT NULL,
    user_name character varying NOT NULL,
    group_name character varying DEFAULT 'default'::character varying NOT NULL,
    passwd character varying NOT NULL,
    out_of_date_time timestamp without time zone,
    CONSTRAINT must_lower CHECK ((lower((user_name)::text) = (user_name)::text))
);


ALTER TABLE public.tdwuser OWNER TO tdwmeta;

--
-- Name: tdwuserrole; Type: TABLE; Schema: public; Owner: tdwmeta; Tablespace: 
--

CREATE TABLE tdwuserrole (
    user_name character varying NOT NULL,
    role_name character varying NOT NULL,
    user_level character varying,
    CONSTRAINT must_lower CHECK (((lower((user_name)::text) = (user_name)::text) AND (lower((role_name)::text) = (role_name)::text)))
);


ALTER TABLE public.tdwuserrole OWNER TO tdwmeta;

--
-- Name: usergroup; Type: TABLE; Schema: public; Owner: tdwmeta; Tablespace: 
--

CREATE TABLE usergroup (
    group_name character varying NOT NULL,
    creator character varying NOT NULL
);


ALTER TABLE public.usergroup OWNER TO tdwmeta;

--
-- Name: dbpriv_user_name_db_name_key; Type: CONSTRAINT; Schema: public; Owner: tdwmeta; Tablespace: 
--

ALTER TABLE ONLY dbpriv
    ADD CONSTRAINT dbpriv_user_name_db_name_key UNIQUE (user_name, db_name);

--
-- Name: dbsensitivity_pkey; Type: CONSTRAINT; Schema: public; Owner: tdwmeta; Tablespace: 
--
ALTER TABLE ONLY dbsensitivity
    ADD CONSTRAINT dbsensitivity_pkey PRIMARY KEY (db_name);

--
-- Name: dw_badfile_skip_log_pkey; Type: CONSTRAINT; Schema: public; Owner: tdwmeta; Tablespace: 
--
ALTER TABLE ONLY tdw_badpbfile_skip_log
    ADD CONSTRAINT dw_badfile_skip_log_pkey PRIMARY KEY (queryid, mrid);


--
-- Name: router_pkey; Type: CONSTRAINT; Schema: public; Owner: tdwmeta; Tablespace: 
--

ALTER TABLE ONLY router
    ADD CONSTRAINT router_pkey PRIMARY KEY (db_name);

--
-- Name: seg_split_pkey; Type: CONSTRAINT; Schema: public; Owner: tdwmeta; Tablespace: 
--

ALTER TABLE ONLY seg_split
    ADD CONSTRAINT seg_split_pkey PRIMARY KEY (seg_addr);

--
-- Name: tblpriv_user_name_db_name_tbl_name_key; Type: CONSTRAINT; Schema: public; Owner: tdwmeta; Tablespace: 
--

ALTER TABLE ONLY tblpriv
    ADD CONSTRAINT tblpriv_user_name_db_name_tbl_name_key UNIQUE (user_name, db_name, tbl_name);

--
-- Name: tblsensitivity_pkey1; Type: CONSTRAINT; Schema: public; Owner: tdwmeta; Tablespace: 
--
ALTER TABLE ONLY tblsensitivity
    ADD CONSTRAINT tblsensitivity_pkey1 PRIMARY KEY (tbl_name, db_name);

--
-- Name: tdwrole_pkey; Type: CONSTRAINT; Schema: public; Owner: tdwmeta; Tablespace: 
--

ALTER TABLE ONLY tdwrole
    ADD CONSTRAINT tdwrole_pkey PRIMARY KEY (role_name);


--
-- Name: tdwuser_pkey; Type: CONSTRAINT; Schema: public; Owner: tdwmeta; Tablespace: 
--

ALTER TABLE ONLY tdwuser
    ADD CONSTRAINT tdwuser_pkey PRIMARY KEY (user_name);


--
-- Name: usergroup_pkey; Type: CONSTRAINT; Schema: public; Owner: tdwmeta; Tablespace: 
--

ALTER TABLE ONLY usergroup
    ADD CONSTRAINT usergroup_pkey PRIMARY KEY (group_name);

--
-- Name: tdwuserrole_role_name_fkey; Type: FK CONSTRAINT; Schema: public; Owner: tdwmeta
--

ALTER TABLE ONLY tdwuserrole
    ADD CONSTRAINT tdwuserrole_role_name_fkey FOREIGN KEY (role_name) REFERENCES tdwrole(role_name) ON DELETE CASCADE;


--
-- Name: tdwuserrole_user_name_fkey; Type: FK CONSTRAINT; Schema: public; Owner: tdwmeta
--

ALTER TABLE ONLY tdwuserrole
    ADD CONSTRAINT tdwuserrole_user_name_fkey FOREIGN KEY (user_name) REFERENCES tdwuser(user_name) ON DELETE CASCADE;


REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

\connect pbjar

--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: pb_proto_jar; Type: TABLE; Schema: public; Owner: tdwmeta; Tablespace: 
--

CREATE TABLE pb_proto_jar (
    db_name character varying NOT NULL,
    tbl_name character varying NOT NULL,
    proto_name character varying,
    proto_file bytea,
    jar_name character varying,
    jar_file bytea,
    user_name character varying,
    modified_time timestamp without time zone NOT NULL,
	protobuf_version character varying default '2.3.0'::character varying
);


ALTER TABLE public.pb_proto_jar OWNER TO tdwmeta;

--
-- Name: pb_proto_jar_pkey; Type: CONSTRAINT; Schema: public; Owner: tdwmeta; Tablespace: 
--

ALTER TABLE ONLY pb_proto_jar
    ADD CONSTRAINT pb_proto_jar_pkey PRIMARY KEY (db_name, tbl_name, modified_time);


REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

\connect seg_1

--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: bucket_cols; Type: TABLE; Schema: public; Owner: tdwmeta; Tablespace: 
--

CREATE TABLE bucket_cols (
    tbl_id bigint NOT NULL,
    bucket_col_name character varying NOT NULL,
    col_index integer NOT NULL
);


ALTER TABLE public.bucket_cols OWNER TO tdwmeta;

--
-- Name: columns; Type: TABLE; Schema: public; Owner: tdwmeta; Tablespace: 
--

CREATE TABLE columns (
    column_index bigint NOT NULL,
    tbl_id bigint NOT NULL,
    column_len bigint DEFAULT 0,
    column_name character varying NOT NULL,
    type_name character varying NOT NULL,
    comment character varying
);


ALTER TABLE public.columns OWNER TO tdwmeta;

--
-- Name: dbs; Type: TABLE; Schema: public; Owner: tdwmeta; Tablespace: 
--

CREATE TABLE dbs (
    name character varying NOT NULL,
    hdfs_schema character varying,
    description character varying,
    owner character varying
);


ALTER TABLE public.dbs OWNER TO tdwmeta;


--
-- Name: partitions; Type: TABLE; Schema: public; Owner: tdwmeta; Tablespace: 
--

CREATE TABLE partitions (
    level integer DEFAULT 0,
    tbl_id bigint NOT NULL,
    create_time timestamp without time zone DEFAULT now(),
    part_name character varying NOT NULL,
    part_values character varying[]
);


ALTER TABLE public.partitions OWNER TO tdwmeta;

--
-- Name: sort_cols; Type: TABLE; Schema: public; Owner: tdwmeta; Tablespace: 
--

CREATE TABLE sort_cols (
    tbl_id bigint NOT NULL,
    sort_column_name character varying NOT NULL,
    sort_order integer NOT NULL,
    col_index integer NOT NULL
);


ALTER TABLE public.sort_cols OWNER TO tdwmeta;

--
-- Name: table_params; Type: TABLE; Schema: public; Owner: tdwmeta; Tablespace: 
--

CREATE TABLE table_params (
    tbl_id bigint NOT NULL,
    param_type character varying NOT NULL,
    param_key character varying NOT NULL,
    param_value character varying NOT NULL
);


ALTER TABLE public.table_params OWNER TO tdwmeta;

--
-- Name: tbls; Type: TABLE; Schema: public; Owner: tdwmeta; Tablespace: 
--

CREATE TABLE tbls (
    tbl_id bigint NOT NULL,
    create_time timestamp without time zone DEFAULT now() NOT NULL,
    is_compressed boolean DEFAULT false NOT NULL,
    retention bigint DEFAULT 0,
    tbl_type character varying NOT NULL,
    db_name character varying NOT NULL,
    tbl_name character varying NOT NULL,
    tbl_owner character varying,
    tbl_format character varying,
    pri_part_type character varying,
    sub_part_type character varying,
    pri_part_key character varying,
    sub_part_key character varying,
    input_format character varying,
    output_format character varying,
    serde_name character varying,
    serde_lib character varying,
    tbl_location character varying,
    tbl_comment character varying
);


ALTER TABLE public.tbls OWNER TO tdwmeta;

--
-- Name: tdwview; Type: TABLE; Schema: public; Owner: tdwmeta; Tablespace: 
--

CREATE TABLE tdwview (
    tbl_id bigint NOT NULL,
    view_original_text character varying NOT NULL,
    view_expanded_text character varying NOT NULL,
    vtables character varying NOT NULL
);


ALTER TABLE public.tdwview OWNER TO tdwmeta;

--
-- Name: bucket_cols_tbl_id_col_index_key; Type: CONSTRAINT; Schema: public; Owner: tdwmeta; Tablespace: 
--

ALTER TABLE ONLY bucket_cols
    ADD CONSTRAINT bucket_cols_tbl_id_col_index_key UNIQUE (tbl_id, col_index);


--
-- Name: columns_tbl_id_column_name_key; Type: CONSTRAINT; Schema: public; Owner: tdwmeta; Tablespace: 
--

ALTER TABLE ONLY columns
    ADD CONSTRAINT columns_tbl_id_column_name_key UNIQUE (tbl_id, column_name);


--
-- Name: dbs_pkey; Type: CONSTRAINT; Schema: public; Owner: tdwmeta; Tablespace: 
--

ALTER TABLE ONLY dbs
    ADD CONSTRAINT dbs_pkey PRIMARY KEY (name);


--
-- Name: partitions_tbl_id_level_part_name_key; Type: CONSTRAINT; Schema: public; Owner: tdwmeta; Tablespace: 
--

ALTER TABLE ONLY partitions
    ADD CONSTRAINT partitions_tbl_id_level_part_name_key UNIQUE (tbl_id, level, part_name);


--
-- Name: sort_cols_tbl_id_col_index_key; Type: CONSTRAINT; Schema: public; Owner: tdwmeta; Tablespace: 
--

ALTER TABLE ONLY sort_cols
    ADD CONSTRAINT sort_cols_tbl_id_col_index_key UNIQUE (tbl_id, col_index);


--
-- Name: table_params_tbl_id_param_type_param_key_key; Type: CONSTRAINT; Schema: public; Owner: tdwmeta; Tablespace: 
--

ALTER TABLE ONLY table_params
    ADD CONSTRAINT table_params_tbl_id_param_type_param_key_key UNIQUE (tbl_id, param_type, param_key);


--
-- Name: tbls_pkey; Type: CONSTRAINT; Schema: public; Owner: tdwmeta; Tablespace: 
--

ALTER TABLE ONLY tbls
    ADD CONSTRAINT tbls_pkey PRIMARY KEY (tbl_id);


--
-- Name: tbls_tbl_name_db_name_key; Type: CONSTRAINT; Schema: public; Owner: tdwmeta; Tablespace: 
--

ALTER TABLE ONLY tbls
    ADD CONSTRAINT tbls_tbl_name_db_name_key UNIQUE (tbl_name, db_name);



--
-- Name: bucket_cols_tbl_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: tdwmeta
--

ALTER TABLE ONLY bucket_cols
    ADD CONSTRAINT bucket_cols_tbl_id_fkey FOREIGN KEY (tbl_id) REFERENCES tbls(tbl_id) ON DELETE CASCADE;


--
-- Name: columns_tbl_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: tdwmeta
--

ALTER TABLE ONLY columns
    ADD CONSTRAINT columns_tbl_id_fkey FOREIGN KEY (tbl_id) REFERENCES tbls(tbl_id) ON DELETE CASCADE;


--
-- Name: partitions_tbl_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: tdwmeta
--

ALTER TABLE ONLY partitions
    ADD CONSTRAINT partitions_tbl_id_fkey FOREIGN KEY (tbl_id) REFERENCES tbls(tbl_id) ON DELETE CASCADE;


--
-- Name: sort_cols_tbl_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: tdwmeta
--

ALTER TABLE ONLY sort_cols
    ADD CONSTRAINT sort_cols_tbl_id_fkey FOREIGN KEY (tbl_id) REFERENCES tbls(tbl_id) ON DELETE CASCADE;


--
-- Name: table_params_tbl_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: tdwmeta
--

ALTER TABLE ONLY table_params
    ADD CONSTRAINT table_params_tbl_id_fkey FOREIGN KEY (tbl_id) REFERENCES tbls(tbl_id) ON DELETE CASCADE;


--
-- Name: tbls_db_name_fkey; Type: FK CONSTRAINT; Schema: public; Owner: tdwmeta
--

ALTER TABLE ONLY tbls
    ADD CONSTRAINT tbls_db_name_fkey FOREIGN KEY (db_name) REFERENCES dbs(name) ON DELETE CASCADE;


--
-- Name: tdwview_tbl_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: tdwmeta
--

ALTER TABLE ONLY tdwview
    ADD CONSTRAINT tdwview_tbl_id_fkey FOREIGN KEY (tbl_id) REFERENCES tbls(tbl_id) ON DELETE CASCADE;

REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

\connect template1

--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

COMMENT ON DATABASE template1 IS 'default template for new databases';


--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';



REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--


\connect tdw

--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

CREATE SCHEMA tdw;


ALTER SCHEMA tdw OWNER TO tdw;

alter role tdw in database tdw set search_path='tdw';

set search_path='tdw';


--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


CREATE TABLE tdw_query_info_new (
    mrnum integer,
    finishtime timestamp without time zone,
    queryid character varying(128) NOT NULL,
    querystring character varying DEFAULT NULL::character varying,
    starttime timestamp without time zone DEFAULT now() NOT NULL,
    username character varying(128) DEFAULT NULL::character varying,
    ip character varying(256) DEFAULT NULL::character varying,
    taskid character varying(256) DEFAULT NULL::character varying
);

ALTER TABLE ONLY tdw_query_info_new
    ADD CONSTRAINT tdw_query_info_new_pkey PRIMARY KEY (queryid);

ALTER TABLE tdw.tdw_query_info_new OWNER TO tdw;


CREATE TABLE tdw_ddl_query_info (
    starttime timestamp without time zone DEFAULT now() NOT NULL,
    finishtime timestamp without time zone,
    queryid character varying NOT NULL,
    querystring character varying,
    username character varying,
    dbname character varying,
    ip character varying,
    queryresult boolean,
    taskid character varying
);

--
-- Name: tdw_ddl_query_info_new2_queryid_idx; Type: INDEX; Schema: tdw; Owner: tdw; Tablespace: 
--

CREATE INDEX tdw_ddl_query_info_new2_queryid_idx ON tdw_ddl_query_info USING btree (queryid);


--
-- Name: tdw_ddl_query_info_new2_starttime_idx; Type: INDEX; Schema: tdw; Owner: tdw; Tablespace: 
--

CREATE INDEX tdw_ddl_query_info_new2_starttime_idx ON tdw_ddl_query_info USING btree (starttime);


--
-- Name: tdw_ddl_query_info_new2_taskid_idx; Type: INDEX; Schema: tdw; Owner: tdw; Tablespace: 
--

CREATE INDEX tdw_ddl_query_info_new2_taskid_idx ON tdw_ddl_query_info USING btree (taskid);


ALTER TABLE tdw.tdw_ddl_query_info OWNER TO tdw;


CREATE TABLE tdw_insert_info (
    queryid character varying,
    desttable character varying,
    successnum bigint,
    rejectnum bigint,
    ismultiinsert boolean,
    inserttime timestamp without time zone DEFAULT now()
);


ALTER TABLE tdw.tdw_insert_info OWNER TO tdw;

CREATE TABLE tdw_move_info (
    log_time timestamp without time zone DEFAULT now() NOT NULL,
    queryid character varying(128) NOT NULL,
    srcdir character varying(4000) NOT NULL,
    destdir character varying(4000) NOT NULL,
    dbname character varying(100),
    tbname character varying(100),
    taskid character varying(256)
);

ALTER TABLE tdw.tdw_move_info OWNER TO tdw;

CREATE TABLE tdw_query_stat_new (
    mapnum integer,
    reducenum integer,
    currmrfinishtime timestamp without time zone,
    currmrid character varying(128) DEFAULT NULL::character varying NOT NULL,
    currmrindex integer NOT NULL,
    currmrstarttime timestamp without time zone DEFAULT now() NOT NULL,
    queryid character varying(128) DEFAULT NULL::character varying NOT NULL,
    jtip character varying
);


ALTER TABLE tdw.tdw_query_stat_new OWNER TO tdw;

--
-- Name: tdw_query_stat_new_currmrid_idx; Type: INDEX; Schema: tdw; Owner: tdw; Tablespace: 
--

CREATE INDEX tdw_query_stat_new_currmrid_idx ON tdw_query_stat_new USING btree (currmrid);


--
-- Name: tdw_query_stat_new_currmrstarttime_idx; Type: INDEX; Schema: tdw; Owner: tdw; Tablespace: 
--

CREATE INDEX tdw_query_stat_new_currmrstarttime_idx ON tdw_query_stat_new USING btree (currmrstarttime);


--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database cluster dump complete
--

