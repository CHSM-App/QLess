/*
  QLess — ONE-TIME: start tracking migrations on an EXISTING database (dev, staging, prod)
  ---------------------------------------------------------------------------
  An existing QLess database already has everything in 000_baseline.sql (the
  baseline was generated from one). This marks 000 as applied so that
  `npm run migrate:up` only runs what comes after it.

  Run ONCE per existing database:
    npm run db -- scripts/bootstrap-migrations.sql
    npm run migrate:status      -> 000 applied, the rest pending
    npm run migrate:up

  NEVER run this on an empty database — there, `npm run migrate:up` builds
  everything from 000.
*/

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'schema_migrations')
CREATE TABLE schema_migrations (
    version     NVARCHAR(10)  NOT NULL PRIMARY KEY,
    name        NVARCHAR(200) NOT NULL,
    applied_at  DATETIME2     NOT NULL DEFAULT GETUTCDATE(),
    applied_by  NVARCHAR(100) NOT NULL DEFAULT SYSTEM_USER
);
GO

IF NOT EXISTS (SELECT 1 FROM schema_migrations WHERE version = '000')
    INSERT INTO schema_migrations (version, name) VALUES ('000', 'baseline');
GO

SELECT * FROM schema_migrations ORDER BY version;
GO
