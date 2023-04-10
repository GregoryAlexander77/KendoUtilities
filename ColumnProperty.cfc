<cfcomponent name="ColumnProperty" displayname="ColumnPropery" hint="Gets the properties for a given table and column" output="no">

<cffunction name="getColumnProperty" returntype="query">

	<cfargument name="dsn" type="string" required="yes">
	<cfargument name="table" type="string" required="yes">
    <cfargument name="column" type="string" required="yes">
    
    <cfquery name="data" datasource="#dsn#">
        SELECT 
            c.name 'ColumnName',
            t.Name 'DataType',
            c.max_length 'MaxLength',
            c.precision,
            c.scale,
            c.is_nullable,
            ISNULL(i.is_primary_key, 0) 'PrimaryKey',
            c.default_object_id as ColumnDefault,
			c.is_computed as IsComputed
        FROM    
            sys.columns c
        INNER JOIN 
            sys.types t ON c.user_type_id = t.user_type_id
        LEFT OUTER JOIN 
            sys.index_columns ic ON ic.object_id = c.object_id AND ic.column_id = c.column_id
        LEFT OUTER JOIN 
            sys.indexes i ON ic.object_id = i.object_id AND ic.index_id = i.index_id
        WHERE 0=0
            AND c.object_id = OBJECT_ID(<cfqueryparam value="#table#" cfsqltype="cf_sql_varchar">)
            AND c.name = (<cfqueryparam value="#column#" cfsqltype="cf_sql_varchar">)
    </cfquery>
    
    <cfreturn data>
</cffunction>

<cffunction name="getSimpleDataType" returntype="string">
	<!--- The Kendo grids only use 4 types in the datasource declaration: string, date, number, and boolean. Convert the real datatype into these forms. --->

	<cfargument name="dsn" type="string" required="yes">
	<cfargument name="table" type="string" required="yes">
    <cfargument name="column" type="string" required="yes">
    
    <cfinvoke component="#this#" method="getDataType" returnvariable="dbDataType">
    	<cfinvokeargument name="dsn" value="#dsn#">
        <cfinvokeargument name="table" value="#table#">
        <cfinvokeargument name="column" value="#column#">
    </cfinvoke>
    
    <cfif dbDataType contains 'int' or dbDataType eq 'decimal' or dbDataType eq 'money' or dbDataType eq 'numeric' or dbDataType eq 'float' or dbDataType eq 'real'>
    	<cfset simpleDataType = 'number'>
	<cfelseif dbDataType contains 'date' or dbDataType eq 'timestamp'>
    	<cfset simpleDataType = 'date'>
	<cfelseif dbDataType eq 'bit'>
    	<cfset simpleDataType = 'boolean'>
    <cfelse>
    	<cfset simpleDataType = 'string'>
    </cfif>
    
    <cfreturn simpleDataType>
</cffunction>

<cffunction name="getDefaultColumnProperty" returnType="query">
	<cfargument name="dsn" type="string" required="yes">
	<cfargument name="table" type="string" required="no" default="">
    <cfargument name="column" type="string" required="no" default="">
    
    <!--- This is a slighly different query, but it provides the default column value.--->
    <cfquery name="data" datasource="#dsn#">
		SELECT COLUMN_DEFAULT
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = <cfqueryparam value="#table#" cfsqltype="cf_sql_varchar">
        AND COLUMN_NAME = <cfqueryparam value="#column#" cfsqltype="cf_sql_varchar">
    </cfquery>
    <cfreturn data>
</cffunction>

<cffunction name="isPrimaryKey" returntype="boolean">
	<cfargument name="dsn" type="string" required="yes">
	<cfargument name="table" type="string" required="yes">
    <cfargument name="column" type="string" required="yes">
    <cfscript>
		if (isBoolean(getColumnProperty('#dsn#','#table#','#column#').PrimaryKey)){
			returnVal = getColumnProperty('#dsn#','#table#','#column#').PrimaryKey;
		} else {
			returnVal = false;
		}
		return returnVal;	
	</cfscript>
</cffunction>

<cffunction name="getMaxLength" returntype="string">
	<cfargument name="dsn" type="string" required="yes">
	<cfargument name="table" type="string" required="yes">
    <cfargument name="column" type="string" required="yes">
    <cfscript>
		return getColumnProperty('#dsn#','#table#','#column#').MaxLength;	
	</cfscript>
</cffunction>

<cffunction name="getDataType" returntype="string">
	<cfargument name="dsn" type="string" required="yes">
	<cfargument name="table" type="string" required="yes">
    <cfargument name="column" type="string" required="yes">
    <cfscript>
		return getColumnProperty('#dsn#','#table#','#column#').DataType;	
	</cfscript>
</cffunction>

<cffunction name="getIsNullable" returntype="string">
	<cfargument name="dsn" type="string" required="yes">
	<cfargument name="table" type="string" required="yes">
    <cfargument name="column" type="string" required="yes">
    <cfscript>
		return getColumnProperty('#dsn#','#table#','#column#').is_nullable;	
	</cfscript>
</cffunction>

<cffunction name="getDefaultColumnValue" returntype="string">
	<cfargument name="dsn" type="string" required="yes">
	<cfargument name="table" type="string" required="yes">
    <cfargument name="column" type="string" required="yes">
    <cfscript>
		return getDefaultColumnProperty('#dsn#','#table#','#column#').COLUMN_DEFAULT;	
	</cfscript>
</cffunction>

<!--- <cfscript>
	// writeDump(getColumnProperty('PayrollSubledgerDev', Batch', 'batchId'));
	// Used like so: writeOutput(getDefaultColumnValue('PayrollSubledgerDev','Batch', 'BatchId'));
</cfscript> --->

</cfcomponent> 
