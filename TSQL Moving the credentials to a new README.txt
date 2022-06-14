The script stores all credentials in a (local) database.
In a second step, this data can be read into a new server again.
The credentials from the old server can also be read into the new server
via a linked server connection.

Das Skript speichert alle Anmeldedaten in einer (lokalen) Datenbank.
In einem zweiten Schritt können diese Daten wieder in einen neuen Server eingelesen werden.
Die Anmeldedaten aus dem alten Server können auch über eine
Linked-Serververbindung in den neuen Server eingelesen werden.


Save the credentials in the database:

DECLARE @userDB VARCHAR(200) = 'databaseForTheLogindata' -- Database in which the data is stored
DECLARE @SaveToUserDb BIT = 1                            -- 1-> save the data in the local database  0-> Reading the data from a local database and storing in the server
DECLARE	@PartnerServer sysname = ''                      -- If no value was entered, then the data are stored in the local database
DECLARE @debug bit = 1                                   -- When debug is turned on, no data are written to the server, but only as output text.


Transfer credentials to the new server:

DECLARE @userDB VARCHAR(200) = 'databaseForTheLogindata' -- Database in which the data is stored
DECLARE @SaveToUserDb BIT = 0                            -- 1-> save the data in the local database  0-> Reading the data from a local database and storing in the server
DECLARE	@PartnerServer sysname = 'NameOfTheLinkedServer' -- If no value was entered, then the data are stored in the local database
DECLARE @debug bit = 1                                   -- When debug is turned on, no data are written to the server, but only as output text.
