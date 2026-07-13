-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create schemas
CREATE SCHEMA IF NOT EXISTS hanadiz;
CREATE SCHEMA IF NOT EXISTS hanadiz_audit;

-- Set search path
ALTER DATABASE hanadiz SET search_path TO hanadiz, public;

-- Create tables (run migrations)