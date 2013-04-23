/****************************************************
  This T-SQL template by Troy Ketsdever, http://www.42and5.com,	troyk@42and5.com
	is licensed under the Creative Commons Attribution-ShareAlike 3.0 Unported 
	License. To view a copy of this license, 
	visit http://creativecommons.org/licenses/by-sa/3.0/.

  User may modify and/or distribute this work for commercial or
	non-commercial use, provided that the original attribution above 
	is included, and that the work is made publicly available under 
	these same terms.
****************************************************/

/***************************************************
  Find scalar functions that reference any db object (table, view, another function)
	and then return all of the objects that reference those functions.
	Depending on the way they are used (i.e., within a resultset vs. as a single call to obtain
	  a particular value), it may make sense to refactor the referencing object
***************************************************/

WITH FunctionsThatUseObjects
AS
(
	SELECT this.[object_id], SCHEMA_NAME(this.schema_id) [schema], this.name
	FROM 
	(	SELECT sed_in.referencing_id
			, COALESCE(sed_in.referenced_id,
					(SELECT ao_in.object_id
					FROM sys.all_objects ao_in
					WHERE name = sed_in.referenced_entity_name
					  AND schema_id = SCHEMA_ID('dbo'))
			) [referenced_id] 
		FROM sys.sql_expression_dependencies sed_in
		WHERE sed_in.referenced_minor_id = 0
	) dep
	INNER JOIN sys.all_objects this
		ON dep.referencing_id = this.[object_id]
	INNER JOIN sys.all_objects uses
		ON dep.referenced_id = uses.[object_id]
	WHERE this.type = 'FN'
	  AND uses.type IN ('FN', 'IF', 'TF', 'U', 'V')
)
SELECT  DISTINCT dep.referencing_id, SCHEMA_NAME(objRef.schema_id) + N'.' + objRef.[name], objRef.type, objRef.type_desc, 
		f.[schema] + N'.' + f.name [Uses Function]
FROM 	(	SELECT sed_in.referencing_id
		, COALESCE(sed_in.referenced_id,
				(SELECT ao_in.object_id
				FROM sys.all_objects ao_in
				WHERE name = sed_in.referenced_entity_name
				  AND schema_id = SCHEMA_ID('dbo'))
		) [referenced_id] 
	FROM sys.sql_expression_dependencies sed_in
	WHERE sed_in.referenced_minor_id = 0
) dep
INNER JOIN sys.all_objects objRef
	ON dep.referencing_id = objRef.[object_id]
INNER JOIN FunctionsThatUseObjects f
	ON dep.referenced_id = f.[object_id]	
-- Stored Procs, Scalar, Inline Table-valued, and Table-valued Functions, CLR Stored Proc
WHERE objRef.type IN ('P', 'V')
  AND dep.referencing_id != dep.referenced_id
;