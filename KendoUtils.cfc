<cfcomponent displayname="kendoUtils.cfc" output="true">

<cffunction name="getDataForVirtualGrid" access="remote" returnformat="json" output="false" hint="Note: you must use a parameter map on the client side in the Kendo datasource declaration in order to send a proper json object to the server. Passes back a ColdFusion query object.">
	<cfargument name="requestBody" type="string" default="" hint="The posted values from the grid. Typically sent in like so: toString( getHttpRequestData().content )" required="yes">
    <cfargument name="tableName" type="string" default="" hint="The table name in the database. If you are using a view, turn it into a table first. The table must have a primary key." required="yes">
    <cfargument name="tableNameAlias" type="string" default="" hint="The aliased table name in the database." required="false">
    <cfargument name="tablePrimaryKey" type="string" default="" hint="What is the primary key of the table." required="true">
    <cfargument name="selectStatment" type="string" default="" hint="Specify the select statement with the columns, such as 'SELECT UserId, FirstName, LastName'. You can also include aliased names, ie 'SELECT UserId as Id'. Do not include any FROM or WHERE clauses in the selectStatement." required="true">
    <cfargument name="defaultOrderByStatement" type="string" default="" hint="If you want to order the data by something other than the primary key, specify the default order statement, ie: 'ORDER BY UserId'" required="false">
    <cfargument name="logSql" type="boolean" default="true" hint="Logs the sql statement for debugging purposes">
    <cfargument name="logFilePath" type="string" default="" hint="Where do you want to log to be saved?">

	<cfsetting enablecfoutputonly="true" />
    
    <!--- Set params --->
    <cfparam name="take" default="100" type="string">
    <cfparam name="skip" default="0" type="string">
    <cfparam name="page" default="1" type="string">
    <cfparam name="pageSize" default="100" type="string">
    <cfparam name="whereClause" default="" type="string">
    <cfparam name="sortStatement" default="" type="string">
    <cfparam name="logSql" default="true" type="boolean">
    
    <!--- Get the number of records in the entire table, not just the top 100 for display purposes. We will overwrite this later if there are any new filters applied.  --->
    <cfquery name="getTotal" datasource="#dsn#">
    	SELECT count(#tablePrimaryKey#) as numRecords FROM [dbo].[#tableName#]
    </cfquery> 
    <cfset totalNumRecords = getTotal.numRecords>
	
	<!---
	Get the HTTP request body content.
	The content in the request body should be formatted like so: {"take":100,"skip":9300,"page":94,"pageSize":100,"sort":[{"field":"ref2","dir":"desc"}]}
	
	NOTE: We have to use toString() as an intermediary method
	call since the JSON packet comes across as a byte array
	(binary data) which needs to be turned back into a string before
	ColdFusion can parse it as a JSON value.
	--->
	<cfset requestBody = toString( getHttpRequestData().content ) />
	
	<!--- Double-check to make sure it's a JSON value. --->
	<cfif isJSON( requestBody )>
		<!--- Deserialize the json in the request body.  --->
		<cfset incomingJson = deserializeJSON( requestBody )>
		
        <!--- Invoke the createSqlForVirtualGrid method that will send back sql clauses.  --->
        <cfinvoke component="#this#" method="createSqlForVirtualGrid" returnvariable="sqlStruct">
            <cfinvokeargument name="jsonString" value="#requestBody#">
            <cfinvokeargument name="dsn" value="#dsn#">
            <cfinvokeargument name="tableName" value="#tableName#">
        </cfinvoke>
        
        <!--- Read the data from the posted data via the grid. --->
        <cfif structFind(sqlStruct, "take") neq ''>
			<cfset take = structFind(sqlStruct, "take")>
        </cfif>
        <cfif structFind(sqlStruct, "skip") neq ''>
            <cfset skip = structFind(sqlStruct, "skip")>
        </cfif>
        <cfif structFind(sqlStruct, "page") neq ''>
            <cfset page = structFind(sqlStruct, "page")>
        </cfif>
        <cfif structFind(sqlStruct, "pageSize") neq ''>
            <cfset pageSize = structFind(sqlStruct, "pageSize")>
        </cfif>
        <cfif structFind(sqlStruct, "whereClause") neq ''>
            <cfset whereClause = structFind(sqlStruct, "whereClause")>
        </cfif>
        <cfif structFind(sqlStruct, "sortStatement") neq ''>
            <cfset sortStatement = structFind(sqlStruct, "sortStatement")>
        </cfif>
	</cfif><!--- <cfif isJSON( requestBody )> --->
    
	<!--- Build the over order by statement. Make sure that a closing bracket ')' is at the end of the string. --->
    <cfset overOrderStatement = ',ROW_NUMBER() OVER ('>
	<cfif sortStatement neq ''>
    	<cfset overOrderStatement = overOrderStatement & sortStatement & ")">
    <cfelse>
    	<!--- Default order by.  --->
        <cfset overOrderStatement = overOrderStatement & defaultOrderByStatement & ")">
    </cfif>
    <!--- Append it to the sqlStatement --->
    <cfset sqlStatement = sqlStatement & " " & overOrderStatement>
    <!--- Build the alias for the rownumber(). I am defaulting to 'as rowNumber' --->
    <cfset sqlStatement = sqlStatement & " AS RowNumber">
    <!--- Append the real and alias table name --->
    <cfset sqlStatement = sqlStatement & " FROM [" & tableName & "]) " & tableNameAlias>
            
	<!--- Append the additional WHERE clause statement to it if necessary --->
    <cfif whereClause neq ''>
        <cfset sqlStatement = sqlStatement & " " & preserveSingleQuotes(whereClause)>
    </cfif>
    
    <!--- Log the sql when the logSql is set to true (on top of function) ---> 
    <cfif logSql>
        <cffile action="append" addnewline="yes" file="#logFilePath#/virtualGridSql.txt" output="#Chr(13)##Chr(10)#'#myTrim(sqlStatement)#'#Chr(13)##Chr(10)#" fixnewline="yes">
    </cfif>
    
    <!--- Testing carriage. If this is not commented out, the grids will not populate.  
    <cfoutput>#preserveSingleQuotes(whereClause)#</cfoutput>
	--->
    <cfquery name="data" datasource="#dsn#">
    	#preserveSingleQuotes(sqlStatement)#
    </cfquery>
    
    <!--- Write the sql to the console log for debugging. Note: if you write this out- it will break the grid, so only do so in development.
	<cfoutput>
    <script>
		if ( window.console && window.console.log ) {
		  // console is available
		  console.log ('#preserveSingleQuotes(sqlStatement)#');
		}
	</script> 
    </cfoutput>
	 --->
	 
     <cfreturn queryObj>
</cffunction>

<cffunction access="remote" name="createSqlForVirtualGrid" output="yes" returntype="struct" displayname="createSqlForVirtualGrid" hint="When using a virtualized kendo grid, this template will grab the filters sent via json and turn the arguments into various sql clauses and returned as a structure. All that is needed is for the procesing page to grab the dynamic sql and insert it where necessary. Note: you must use a parameter map on the client side in the Kendo datasource declaration in order to send a proper json object to the server. Returns a query statement in a structure.">

    <cfargument name="jsonString" type="any" required="yes" hint="Pass in the json string that was passed in the http body. The string should be captured on the page that the kendo grid is posting to like so: cfset requestBody = toString( getHttpRequestData().content ). After the string is passed in, this function will provide a structure with the following elements: take, skip, page, pageSize, whereClause, sortField, and sortDir."> 
    <cfargument name="dsn" type="string" required="yes" hint="We neeed to determine the column datatype, we need to have the datasource to determine the datatype for columns."> 
    <cfargument name="tableName" type="string" hint="We neeed to determine the column datatype, and need to have the table name to determine the datatype for columns.">
    <!--- Note: the column names will be passed in a struct in the json string.  --->
    
    <cfsetting enablecfoutputonly="true" />
    <!--- Instantiate the column property object. --->
    <cfobject component="common.cfc.db.utilities.ColumnProperty" name="DbColumnProperyObj">

    <!--- Deserialize the json string. ---> 
    <cfset incomingJson = deserializeJson(jsonString, false)>
    
    <!---
    In JSON, the [] denotes an array and {} a structure.
    Note: assuming this is the json string ('{"take":100,"skip":0,"page":1,"pageSize":100,"sort":[{"field":"ref2","dir":"asc"}],"filter":{"logic":"and","filters":[{"field":"jobclass","operator":"eq","value":"fred"},{"field":"jobclass","operator":"neq","value":"ef"},{"logic":"or","filters":[{"field":"descr","operator":"startswith","value":"asd"},{"field":"descr","operator":"contains","value":"asdf"}]}]}}'), to show how complex the json string is; this is how you would get to the last field in the array: 
    <cfoutput>
    #incomingJson['filter']['filters'][3]['filters'][1]['field']# and it's complementary value 
    #incomingJson['filter']['filters'][3]['filters'][2]['field']#
    </cfoutput>
    The filters array contains: index 1 a filters struct with field, operator and value, index 2 same as 1, index 3, another filters struct holding another filters array containing the same struct found in index 1 and 2. 
    But wait... sometimes that changes! If there are multiple filters that have already been selected... guess what? Then the data is all held in a sub filters array. Here, we will loop a bunch of times later in the code to get to these items. 
    --->
    
    <!--- Set some params --->
    <!--- Output params --->
    <cfparam name="take" default="" type="string">
    <cfparam name="skip" default="" type="string">
    <cfparam name="page" default="" type="string">
    <cfparam name="pageSize" default="" type="string">
    <cfparam name="sortField" default="" type="string">
    <cfparam name="sortDir" default="" type="string">
    <cfparam name="sortStatement" default="" type="string">
    
    <!--- Internal params --->
    <cfparam name="finalFilterField" default="" type="string">
    <cfparam name="finalFilterOperator" default="" type="string">
    <cfparam name="finalFilterValue" default="" type="string">
    <cfparam name="sqlClauseCombined" default="" type="string">
    <cfparam name="searchFilter" default="false" type="boolean">

	<!--- Double-check to make sure it's a JSON value. --->
	<cfif not isStruct( incomingJson )>
    	<cfoutput>incomingJson is not a properly formatted structure.</cfoutput>
    <cfelse>
        <!--- 
        <cfdump var="#incomingJson#">
         --->
        
        <!--- Set the vars. --->
        <cfset take = incomingJson.take>
        <cfset skip = incomingJson.skip>
        <cfset page = incomingJson.page>
        <cfset pageSize = incomingJson.pageSize>
        
        <!--- We also need to get at the sort arguments which might be held in an array. 
		Note: 7/7/2017 the kendo grids now support multiple sort options. The new logic will be sent in like so: 
		Single sort: [{field: "bar70id", dir: "asc"}]
		Multiple sorts: sort: [{field: "bar70id", dir: "asc"}, {field: "faspostdatekey", dir: "asc"}]--->
        <cfif structKeyExists(incomingJson, "sort")>
            <cfparam name="sortStatement" default="" type="any">
            <cfloop array="#incomingJson['sort']#" index="i">
                <cfset sortField = i['field']>
                <cfset sortDir = i['dir']>
                <!--- For every element found in the sort array, put in a comma and keep the prior sort statement that was built. --->
                <cfif sortStatement eq ''>
                    <cfset sortStatement = "ORDER BY " & sortField & " " & sortDir>
                <cfelse>
                    <cfset sortStatement = sortStatement & ", " & sortField & " " & sortDir>
                </cfif>
                <cfoutput>sortField: #sortField# sortDir: #sortDir#<br/></cfoutput>
            </cfloop>
        </cfif>
        
        <!--- Dig in the first filters object. If there were only on set of filters, the filter data will be in this part of the object.
        The first structure is easy to work with. But, the oject gets very complex when looking in the filters array. The filers array can have multiple structures and arrays in it. We are going to use the each.cfm custom tag in order to loop thru all of the objects. We are not using CF logic here as the objects may be a struct, or an array, causing us to write a lot more logic. The each.cfm template will supply us with three items: the index (1) key (field, operator, etc), collectionType (array/struct), and value typed in by the user in the filter. --->
        
        <cfif structKeyExists(incomingJson, "filter")>
        	<!--- Set a variable that we will pass back indicating that a 'filter' was made. This variable will determine how the calling template processes the total records count. ---> 
        	<cfset searchFilter = true>
			<!--- Get the values of the items that we know exist--->
			<!--- Get the 'logic' array (and, or etc) --->
            <cfset sqlLogicStatement = incomingJson['filter']['logic']>
            <!--- Get the 'logic' array (and, or etc) --->
            <cfset sqlLogicStatement = incomingJson['filter']['logic']>
            <!--- Get to the filters array. ---> 
            <cfset filtersArray = incomingJson['filter']['filters']>
            <!--- There will be 2 loops thru the filter array. We need to put the logic statement between the two clauses (name = 'gregory' AND lname = 'alexander'). Set a loop counter here.--->
            <cfset filterLoopCount=1>
            <cfloop array="#filtersArray#" index="i">
                <!--- There may be multiple structures in the filters object that cause an error. If there are, ignore them.  --->
                <!--- <cftry> --->
                    <cfset filterField = i['field']>
                    <cfset filterOperator = i['operator']>
                    <cfset filterValue = i['value']>
                    <!--- <cfoutput>filterValue=#filterValue#</cfoutput> --->
                    
					<!--- Determine if the value should be put in single qoutes. --->
                    <cfinvoke component="#DbColumnProperyObj#" method="getDataType" returnvariable="dataType">
                        <cfinvokeargument name="dsn" value="#dsn#">
                        <cfinvokeargument name="table" value="#tableName#">
                        <cfinvokeargument name="column" value="#filterField#">
                    </cfinvoke>
                    <!--- <cfoutput>'#dataType#'</cfoutput> --->
                    <cfif dataType contains 'date'>
                    	<!--- Cast the field --->
                        <cfset filterField = 'cast(' & filterField & ' AS DATE)'>
                    	<!--- Convert the iso date into a readable format for sql --->
                        <cfset filterValue = dateFormat(isoToDateTime(filterValue), 'mm-dd-yyyy')>
                    </cfif>
                          
                    <!--- Note!!! Copy this block below in the exact same spot! Low priority- I'll fix after deadlines? --->
					<!--- Build a sql WHERE statement. --->
                    <cfswitch expression="#filterOperator#">
                        <cfcase value="eq">
                        	<!--- For eq and neq, use a qouted filter value --->
							<cfif dataType contains 'char' or dataType contains 'text' or dataType eq 'decimal' or dataType contains 'date'>
                                <!--- Enclose the value with qoutes. --->
                                <cfset filterValue = "'" & filterValue & "'">
                            </cfif>
							<cfset sqlClause = filterField & " = " & filterValue>
                        </cfcase>
                        <cfcase value="neq">
                        	<!--- For eq and neq, use a qouted filter value --->
							<cfif dataType contains 'char' or dataType contains 'text' or dataType eq 'decimal'>
                                <!--- Enclose the value with qoutes. --->
                                <cfset filterValue = "'" & filterValue & "'">
                            </cfif>
							<cfset sqlClause = filterField & " <> " & filterValue>
                        </cfcase>
                        <!--- The following cases are numeric --->
                        <cfcase value="gt"><cfset sqlClause = filterField & " > " & filterValue></cfcase>
                        <cfcase value="gte"><cfset sqlClause = filterField & " >= " & filterValue></cfcase>
                        <cfcase value="lt"><cfset sqlClause = filterField & " < " & filterValue></cfcase>
                        <cfcase value="lte"><cfset sqlClause = filterField & " <= " & filterValue></cfcase>
                       	<!---  Like statements will not enclose the filterValue with qoutes. --->
                        <cfcase value="startswith"><cfset sqlClause = filterField & " LIKE '" & filterValue & "%'"></cfcase>
                        <cfcase value="contains"><cfset sqlClause = filterField & " LIKE '%" & filterValue & "%'"></cfcase>
                        <cfcase value="doesnotcontain"><cfset sqlClause = filterField & " NOT LIKE '%" & filterValue & "%'"></cfcase>
                        <cfcase value="endswith"><cfset sqlClause = filterField & " LIKE '%" & filterValue & "'"></cfcase>
                        <!--- The following cases do not need to pass a value. --->
                        <cfcase value="isnotnull"><cfset sqlClause = filterField & " IS NOT NULL"></cfcase>
                        <!--- 
						Write out ' datalength(x)=0' ('datalength(agencyrateid)=0' for example).
						This prevents data type errors when using where x = '' on numeric values.
						--->
                        <cfcase value="isempty"><cfset sqlClause = " datalength(" & filterField & ") = 0"></cfcase>
                        <cfcase value="isnotempty"><cfset sqlClause = " datalength(" & filterField & ") > 0"></cfcase>
                    </cfswitch>
                    <!--- Using isnull in a case statement causes the template to fail. --->
                    <cfif filterOperator eq "isnull">
                    	<cfset sqlClause = filterField & " IS NULL">
                    </cfif>
                    <!--- !!! Copy End code --->
                    
                    
                    <!--- 
                    <cfoutput>
                        <cfif filterLoopCount eq 2>
                            #sqlLogicStatement#
                        </cfif> 
                        #sqlClause#
                    </cfoutput> 
                    --->
                    <cfif filterLoopCount eq 1>
                        <cfset sqlClauseCombined = sqlClauseCombined & " WHERE ">
                    <cfelseif filterLoopCount gte 2>
                        <cfset sqlClauseCombined = sqlClauseCombined & " " & uCase(sqlLogicStatement) & " ">
                    </cfif>
                    <cfset sqlClauseCombined = sqlClauseCombined & sqlClause>
                    <!--- Increment the counter. --->
                    <cfset filterLoopCount = filterLoopCount + 1>
                    <!--- <cfcatch type="any"></cfcatch>
                </cftry> --->
            </cfloop><!--- <cfloop array="#filtersArray#" index="i"> --->
             
            <!--- If there are multiple filters made, get the next filters array if they exist. --->
            <cfset subFilterLoopCount=1>
            <cfset prevParentLoopCount=0>
            <cfloop from="1" to="10" index="parentLoop">
                <cftry>
                    <cfif arrayIsDefined(filtersArray[parentLoop]['filters'], 1)>
                        <cfset subFiltersArray = filtersArray[parentLoop]['filters']>
                        <!--- Loop thru it just like we did before. It should be a carbon copy of the previous filters array. ---> 
                        <cfloop array="#subFiltersArray#" index="i">
                            <!--- <cftry> --->
                                <cfset filterField = i['field']>
                                <cfset filterOperator = i['operator']>
                                <cfset filterValue = i['value']>
                                
								<!--- Determine if the value should be put in single qoutes. --->
                                <cfinvoke component="#DbColumnProperyObj#" method="getColumnDataType" returnvariable="dataType">
                                    <cfinvokeargument name="dsn" value="#dsn#">
                                    <cfinvokeargument name="table" value="#tableName#">
                                    <cfinvokeargument name="columnName" value="#filterField#">
                                </cfinvoke>
                                <!--- Wrap the filterValue with qoutes if necessary. ---> 
                                <cfif dataType eq 'varchar'>
                                    <!--- Enclose the value with qoutes. --->
                                    <cfset filterValue = "'" & filterValue & "'">
                                </cfif>
                    
                                
								<!--- Note!!! Copy the block ABOVE in the exact same spot! Low priority- I'll fix after deadlines? --->
								<!--- Build a sql WHERE statement. --->
                                <cfswitch expression="#filterOperator#">
                                    <cfcase value="eq">
                                        <!--- For eq and neq, use a qouted filter value --->
                                        <cfif dataType contains 'char' or dataType contains 'text' or dataType eq 'decimal'>
                                            <!--- Enclose the value with qoutes. --->
                                            <cfset filterValue = "'" & filterValue & "'">
                                        </cfif>
                                        <cfset sqlClause = filterField & " = " & filterValue>
                                    </cfcase>
                                    <cfcase value="neq">
                                        <!--- For eq and neq, use a qouted filter value --->
                                        <cfif dataType contains 'char' or dataType contains 'text' or dataType eq 'decimal'>
                                            <!--- Enclose the value with qoutes. --->
                                            <cfset filterValue = "'" & filterValue & "'">
                                        </cfif>
                                        <cfset sqlClause = filterField & " <> " & filterValue>
                                    </cfcase>
                                    <!--- The following cases are numeric --->
                                    <cfcase value="gt"><cfset sqlClause = filterField & " > " & filterValue></cfcase>
                                    <cfcase value="gte"><cfset sqlClause = filterField & " >= " & filterValue></cfcase>
                                    <cfcase value="lt"><cfset sqlClause = filterField & " < " & filterValue></cfcase>
                                    <cfcase value="lte"><cfset sqlClause = filterField & " <= " & filterValue></cfcase>
                                    <!---  Like statements will not enclose the filterValue with qoutes. --->
                                    <cfcase value="startswith"><cfset sqlClause = filterField & " LIKE '" & filterValue & "%'"></cfcase>
                                    <cfcase value="contains"><cfset sqlClause = filterField & " LIKE '%" & filterValue & "%'"></cfcase>
                                    <cfcase value="doesnotcontain"><cfset sqlClause = filterField & " NOT LIKE '%" & filterValue & "%'"></cfcase>
                                    <cfcase value="endswith"><cfset sqlClause = filterField & " LIKE '%" & filterValue & "'"></cfcase>
                                    <!--- The following cases do not need to pass a value. --->
                                    <cfcase value="isnotnull"><cfset sqlClause = filterField & " IS NOT NULL"></cfcase>
                                    <!--- 
                                    Write out ' datalength(x)=0' ('datalength(agencyrateid)=0' for example).
                                    This prevents data type errors when using where x = '' on numeric values.
                                    --->
                                    <cfcase value="isempty"><cfset sqlClause = " datalength(" & filterField & ") = 0"></cfcase>
                                    <cfcase value="isnotempty"><cfset sqlClause = " datalength(" & filterField & ") > 0"></cfcase>
                                </cfswitch>
                                <!--- Using isnull in a case statement causes the template to fail. --->
                                <cfif filterOperator eq "isnull">
                                    <cfset sqlClause = filterField & " IS NULL">
                                </cfif>
                                <!--- !!! Copy End code --->
                                
                                
                                <!--- 
                                <cfoutput>
                                    <br/>subFilterLoopCount:#subFilterLoopCount# parentLoop:#parentLoop# prevParentLoopCount:#prevParentLoopCount#
                                    <cfif subFilterLoopCount eq 1> 
                                        AND 
                                    <cfelseif parentLoop eq prevParentLoopCount>
                                        #uCase(sqlLogicStatement)#
                                    <cfelse>
                                        AND 
                                    </cfif> 
                                    #sqlClause#
                                </cfoutput> 
                                --->
                                <cfif subFilterLoopCount eq 1>
                                    <!--- Note: the first loop above may or may not be present. If it is, the where statement will be built, if not, add it. ---> 
                                    <cfif find('WHERE', sqlClauseCombined) eq 0>
                                        <cfset sqlClauseCombined = sqlClauseCombined & " WHERE ">
                                    <cfelseif sqlClauseCombined neq ''>
                                        <cfset sqlClauseCombined = sqlClauseCombined & " AND ">
                                    </cfif>
                                <cfelseif parentLoop eq prevParentLoopCount>
                                    <cfset sqlClauseCombined = sqlClauseCombined &  " " & uCase(sqlLogicStatement & " ")>
                                <cfelse>
                                    <cfset sqlClauseCombined = sqlClauseCombined & " AND ">
                                </cfif>
                                <cfset sqlClauseCombined = sqlClauseCombined & sqlClause>
                                <!--- Save the value of the current counter --->
                                <cfset prevParentLoopCount = parentLoop>
                                <!--- Increment our counter. --->
                                <cfset subFilterLoopCount = subFilterLoopCount + 1>
                                <!--- <cfcatch type="any"></cfcatch>
                            </cftry> --->
                        </cfloop><!--- <cfloop array="#subFiltersArray#" index="i"> --->
                    </cfif><!--- <cfif arrayIsDefined(filtersArray[parent]['filters'], 1)> --->
                    <cfcatch type="any"></cfcatch>
                </cftry>
            </cfloop><!--- <cfloop from="1" to="10" index="parentLoop"> --->
        </cfif><!--- <cfif structKeyExists(incomingJson, "filter")> --->
        
        <cfset rowStart = skip><!--- The rowStart is generally the skip var coming thru the json reqest. --->
        <cfset rowEnd = (skip + take)>
        
        <!--- Post processing and cleanup --->
		<!--- If the user did not choose to filter anything, the sqlClauseStatement should be an empty string. If this is the case, build the WHERE clause and use the skip argument sent via the grid. --->
        <cfif sqlClauseCombined eq ''>
            <cfset sqlClauseCombined = "WHERE RowNumber BETWEEN " & rowStart & " AND " & rowEnd>
        </cfif>
        
        <!--- 
        <cfoutput>{take:"#take#", skip:"#skip#", page:"#page#", pageSize:"#pageSize#", whereClause:"#sqlClauseCombined#", sortField:"#sortField#", sortDir:"#sortDir#"}</cfoutput> 
        --->
    </cfif><!--- <cfif isStruct( incomingJson )> --->
    
    <!--- Finally, create a ColdFusion structure object and pass it back. --->
    <cfscript> 
        sqlForVirtualGrid = structNew(); 
        structInsert(sqlForVirtualGrid, "take", take); 
        structInsert(sqlForVirtualGrid, "skip", skip); 
        structInsert(sqlForVirtualGrid, "page", page); 
        structInsert(sqlForVirtualGrid, "pageSize", pageSize); 
		structInsert(sqlForVirtualGrid, "searchFilter", searchFilter); 
        structInsert(sqlForVirtualGrid, "whereClause", sqlClauseCombined); 
        structInsert(sqlForVirtualGrid, "sortStatement", sortStatement); 
		// Include the sql sript for debugging.
		structInsert(sqlForVirtualGrid, "sqlClauseCombined", sqlClauseCombined);  
    </cfscript> 

	<cfreturn sqlForVirtualGrid>
    
</cffunction>

<cffunction access="remote" name="decodeKendoFilterValueForVirtualDropdown" output="yes" returntype="string" displayname="decodeKendoFilterForVirtualDropdown" hint="When using a virtualized kendo grid, this template will grab the filters sent via json and turn the arguments into various sql clauses and returned as a simple string. The string will be formatted like so: 'dropdownName:dropdownValue'. Note: you must use a parameter map on the client side in the Kendo datasource declaration in order to send a proper json object to the server. Passed back a string that is used in a SQL WHERE clause.">

    <cfargument name="jsonString" type="any" required="no" hint="Pass in the json string that was passed in the http body. The string should be captured on the page that the kendo grid is posting to like so: cfset requestBody = toString( getHttpRequestData().content ). After the string is passed in, this function will provide a structure with the following elements: take, skip, page, pageSize, whereClause, sortField, and sortDir." default='{"filter":{"filters":[{"field":"departmentcategoryid","operator":"eq","value":3,"__kendo_devtools_id":8}],"logic":"and"}}'> 
    
    <!--- Notes: this is consumed by the client like so:
	Grab the http request data sent by the client, and use the toString() as an intermediary method call since the JSON packet comes across as a byte array (binary data) which needs to be turned back into a string before ColdFusion can parse it as a JSON value.
	<cfset requestBody = toString( getHttpRequestData().content ) />
    
    Pass the requestBody variable to the decodeKendoFilterForVirtualDropdown in the KendoUtils object to decode the json string.
    <cfinvoke component="#KendoUtils#" method="decodeKendoFilterValueForVirtualDropdown" returnvariable="filterValue">
    	<cfinvokeargument name="jsonString" value="#requestBody#">
    </cfinvoke> 
	
	However, you should also consider using the value mapper on the virtual dropdown widget. See https://docs.telerik.com/kendo-ui/controls/editors/combobox/virtualization#configuration-Enable
	--->
    
    <!--- Preset the filterValue var so that there is no errors when the object does not send a filter structure (this is common when the user is not finished typing something in). --->
    <cfparam name="filterValue" default="" type="string"> 

    <!--- Deserialize the json string. Put this in a try block in case something goes awry, or the string is null. ---> 
    <cftry>
    	<cfset incomingJson = deserializeJson(jsonString, false)>
        <cfcatch type="any">
        	<cfset incomingJson = ''>
        </cfcatch>
    </cftry>

      <!---
    In JSON, the [] denotes an array and {} a structure.
    Note: assuming this is the json string:
	filter[logic]=and&filter[filters][0][field]=departmentcategoryid&filter[filters][0][operator]=eq&filter[filters][0][value]=1&filter[filters][0][__kendo_devtools_id]=8
	We need to extract the 'filter[filters][0][value]=1' value in the string for the cascading dropdowns.
    --->

	<!--- Double-check to make sure it's a JSON value. --->
	<cfif not isStruct( incomingJson )>
    	<cfoutput>incomingJson is not a properly formatted structure.</cfoutput>
    <cfelse>
        <!--- Dig in the first filters object. If there were only on set of filters, the filter data will be in this part of the object.
        The first structure is easy to work with. But, the oject gets very complex when looking in the filters array. The filers array can have multiple structures and arrays in it. We are going to use the each.cfm custom tag in order to loop thru all of the objects. We are not using CF logic here as the objects may be a struct, or an array, causing us to write a lot more logic. The each.cfm template will supply us with three items: the index (1) key (field, operator, etc), collectionType (array/struct), and value typed in by the user in the filter. --->
        <cfif structKeyExists(incomingJson, "filter")>
        	<!--- We need to extract the following: filter[filters][0][field]=departmentcategoryid and: filter[filters][0][value]=1--->
            
        	<!--- Get to the filters array. ---> 
            <cfset filtersArray = incomingJson['filter']['filters']>
            
            <!--- Loop thru the array. --->
            <cfloop array="#filtersArray#" index="i">
                <!--- There may be multiple structures in the filters object that cause an error. If there are, ignore them.  --->
				<!--- Note: to get the field name specified in the control, use cfset filterField = i['field'] --->
                <cfset filterValue = i['value']>
            </cfloop>
    	</cfif><!--- <cfif structKeyExists(incomingJson, "filter")> --->
	</cfif><!--- <cfif not isStruct( incomingJson )> --->

        <!--- Pass back the value which was typed into the form. --->

    <cfreturn filterValue>
    
</cffunction>

<!--- This function converts a javascript iso date into a coldfusion date time object. Grabbed function from https://gist.githubusercontent.com/bennadel/9752692/raw/899fe6fa232cfc64d8505957b9526e61bb117017/code-1.cfm and made minor changes. --->
<cffunction
	name="isoToDateTime"
	access="public"
	returntype="string"
	output="false"
	hint="Converts an ISO 8601 date/time stamp with optional dashes to a ColdFusion date/time stamp passed back as a string.">

	<!--- Define arguments. --->
	<cfargument
		name="Date"
		type="string"
		required="true"
		hint="ISO 8601 date/time stamp."
		/>

	<!---
		When returning the converted date/time stamp,
		allow for optional dashes.
	--->
	<cfreturn ARGUMENTS.Date.ReplaceFirst(
		"^.*?(\d{4})-?(\d{2})-?(\d{2})T([\d:]+).*$",
		"$1-$2-$3 $4"
		) />
</cffunction>

</cfcomponent>