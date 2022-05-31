# TSQl Helpers

My collection of useful (or whatever) SQL scripts

*Find a string in a TSQL server.sql*

A specific string is searched for in all functions, triggers, etc. The result is output in a table.

*Create test table with random values.sql*

*Delete and create a new email system on a TSQL server.sql*

The script deletes all mail profiles, mail accounts and operators on the SQL Server.
A new mail account is then created and assigned to the profile.
A new operator is also created.
All existing mail connections of the jobs are redirected to a new account.
The table at the end shows the jobs that still have to be changed manually.

*Print without limitation max characters.sql*

The print command limits the output of a SQL string to a certain number. The function splits sections so that no text is lost.
