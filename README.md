# T SQL Helpers

My collection of useful (or whatever) SQL scripts

__*Find a string in a TSQL server.sql*__

A specific string is searched for in all functions, triggers, etc. The result is output in a table.

__*Create test table with random values.sql*__

__*Delete and create a new email system on a TSQL server.sql*__

The script deletes all mail profiles, mail accounts and operators on the SQL Server.
A new mail account is then created and assigned to the profile.
A new operator is also created.
All existing mail connections of the jobs are redirected to a new account.
The table at the end shows the jobs that still have to be changed manually.

__*Print without limitation max characters.sql*__

The print command limits the output of a SQL string to a certain number. The function splits sections so that no text is lost.

 __*TSQL Moving the credentials to a new SQL Server.sql*__

The script stores all credentials in a (local) database. In a second step, this data can be read into a new server again. The credentials from the old server can also be read into the new server via a linked server connection.

__*TSQL job controller with feedback.sql*__

The procedure checks whether another process has already called it (@Jobname);
if an instance of the procedure is already running, the current instance waits for the current one to complete.
A timeout can be set. You can also specify whether the process is restarted after the waiting time has elapsed.

__*A quick data comparison for specific table fields on different servers.sql*__

It is often necessary to make a statement about the data equality for certain fields of a table in distributed databases.
The fields can be determined in the small script and the various table links are also given.
It is important that linked servers are also available on the executing server.

[__*TSQL comparison via primary key.sql*__](https://github.com/Werferstein/My-collection-of-useful-or-whatever-SQL-scripts/blob/main/comparison%20via%20primary%20key.sql)

Comparing two tables using the primary key and displaying possible differences in the tables.
The primary columns are read from the schema and correctly linked to the target table,
if no blacklist for fields was specified, all remaining fields are compared.
