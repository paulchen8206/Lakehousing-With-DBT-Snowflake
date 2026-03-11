-- Run this script as ACCOUNTADMIN first, then adjust for least privilege.

use role accountadmin;

create database if not exists LAKEHOUSE;
create schema if not exists LAKEHOUSE.RAW;
create schema if not exists LAKEHOUSE.STAGING;
create schema if not exists LAKEHOUSE.BRONZE;
create schema if not exists LAKEHOUSE.SILVER;
create schema if not exists LAKEHOUSE.GOLD;

create warehouse if not exists COMPUTE_WH
  warehouse_size = 'XSMALL'
  auto_suspend = 60
  auto_resume = true
  initially_suspended = true;

create or replace storage integration s3_lakehouse_int
  type = external_stage
  storage_provider = s3
  enabled = true
  storage_aws_role_arn = 'arn:aws:iam::<aws-account-id>:role/<snowflake-access-role>'
  storage_allowed_locations = ('s3://<your-bucket>/');

create or replace file format json_ff
  type = json
  strip_outer_array = true;

create or replace stage raw_s3_stage
  url = 's3://<your-bucket>/'
  storage_integration = s3_lakehouse_int
  file_format = json_ff;

create or replace external table LAKEHOUSE.RAW.orders_ext (
  v variant as (value)
)
with location = @raw_s3_stage/orders/
auto_refresh = false
file_format = (type = json);

create or replace external table LAKEHOUSE.RAW.customers_ext (
  v variant as (value)
)
with location = @raw_s3_stage/customers/
auto_refresh = false
file_format = (type = json);

-- Grant role used by dbt.
create role if not exists TRANSFORMER;
grant usage on warehouse COMPUTE_WH to role TRANSFORMER;
grant usage on database LAKEHOUSE to role TRANSFORMER;
grant usage on all schemas in database LAKEHOUSE to role TRANSFORMER;
grant select on future tables in schema LAKEHOUSE.RAW to role TRANSFORMER;
grant select on future views in schema LAKEHOUSE.RAW to role TRANSFORMER;
grant create table, create view on schema LAKEHOUSE.STAGING to role TRANSFORMER;
grant create table, create view on schema LAKEHOUSE.BRONZE to role TRANSFORMER;
grant create table, create view on schema LAKEHOUSE.SILVER to role TRANSFORMER;
grant create table, create view on schema LAKEHOUSE.GOLD to role TRANSFORMER;
