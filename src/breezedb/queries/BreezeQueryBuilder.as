/*
 * MIT License
 *
 * Copyright (c) 2017 Digital Strawberry LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 */

package breezedb.queries
{
	import breezedb.BreezeDb;
	import breezedb.IBreezeDatabase;
	import breezedb.collections.Collection;

	import flash.globalization.DateTimeFormatter;

	/**
	 * Class providing API to run queries on associated database and table.
	 */
	public class BreezeQueryBuilder extends BreezeQueryRunner
	{
		private static var sLongDateFormatter:DateTimeFormatter = null;
		private static var sShortDateFormatter:DateTimeFormatter = null;

		private var _tableName:String;

		private var _update:String = null;
		private var _select:Array = [];
		private var _insert:Array = [];
		private var _insertColumns:String = null;
		private var _where:Array = [[]];
		private var _orderBy:Array = [];
		private var _groupBy:Array = [];
		private var _having:Array = [[]];
		private var _distinct:Boolean = false;
		private var _offset:int = -1;
		private var _limit:int = -1;
		private var _chunkLimit:uint;
		private var _chunkQueryReference:BreezeQueryReference;

		private var _parametersIndex:uint = 0;
		
		public function BreezeQueryBuilder(db:IBreezeDatabase, tableName:String)
		{
			super(db);
			_tableName = tableName;
			_queryType = QUERY_SELECT;
		}


		public function first(callback:* = null):BreezeQueryRunner
		{
			_selectFirstOnly = true;

			limit(1);

			executeIfNeeded(callback);

			return this;
		}
		
		
		public function count(callback:* = null):BreezeQueryRunner
		{
			_aggregate = "total";

			select("COUNT(*) as total");
			executeIfNeeded(callback);

			return this;
		}


		public function max(column:String, callback:* = null):BreezeQueryRunner
		{
			validateColumnName(column);

			_aggregate = "max";

			select("MAX(" + column + ") as max");
			executeIfNeeded(callback);

			return this;
		}


		public function min(column:String, callback:* = null):BreezeQueryRunner
		{
			validateColumnName(column);

			_aggregate = "min";

			select("MIN(" + column + ") as min");
			executeIfNeeded(callback);

			return this;
		}


		public function sum(column:String, callback:* = null):BreezeQueryRunner
		{
			validateColumnName(column);

			_aggregate = "sum";

			select("SUM(" + column + ") as sum");
			executeIfNeeded(callback);

			return this;
		}


		public function avg(column:String, callback:* = null):BreezeQueryRunner
		{
			validateColumnName(column);

			_aggregate = "avg";

			select("AVG(" + column + ") as avg");
			executeIfNeeded(callback);

			return this;
		}
		
		
		public function select(...args):BreezeQueryBuilder
		{
			for(var i:int = 0; i < args.length; i++)
			{
				_select[_select.length] = args[i];
			}

			return this;
		}


		public function distinct(column:String):BreezeQueryBuilder
		{
			_distinct = true;

			select(column);

			return this;
		}
		
		
		public function chunk(limit:uint, callback:* = null):BreezeQueryRunner
		{
			_chunkLimit = limit;
			_callbackProxy = onChunkCompleted;
			_originalCallback = callback;

			_offset = (_offset == -1) ? 0 : (_offset + limit);
			_limit = limit;

			executeIfNeeded(callback);

			return this;
		}


		public function where(param1:*, param2:* = null, param3:* = null):BreezeQueryBuilder
		{
			// Raw where statement, e.g. where("id > 2")
			if(param1 is String && param2 === null && param3 === null)
			{
				whereRaw(param1);
			}
			// Simple equal statement, e.g. where("id", 15)
			else if(param1 is String && param3 === null)
			{
				where(param1, "=", param2);
			}
			// Simple statement with operator, e.g. where("id", "!=", 15)
			else if(param1 is String && param2 is String && param3 !== null)
			{
				whereRaw(param1 + " " + param2 + " " + inputToParameter(param3));
			}
			// Array of statements, e.g. where([["id", 15], ["name", "!=", "Kevin"])
			else if(param1 is Array && param2 === null && param3 === null)
			{
				for each(var statement:* in param1)
				{
					if(!(statement is Array))
					{
						throw new Error("Where must be an Array of Arrays.");
					}

					if(statement.length == 3)
					{
						where(statement[0], statement[1], statement[2]);
					}
					else if(statement.length == 2)
					{
						where(statement[0], "=", statement[1]);
					}
					else
					{
						throw new Error("Invalid where parameters.");
					}

				}
			}
			// Invalid input
			else
			{
				throw new ArgumentError("Invalid where parameters.");
			}

			return this;
		}


		public function orWhere(param1:*, param2:* = null, param3:* = null):BreezeQueryBuilder
		{
			_where[_where.length] = [];
			where(param1, param2, param3);

			return this;
		}


		public function whereBetween(column:String, greaterThan:Number, lessThan:Number):BreezeQueryBuilder
		{
			validateColumnName(column);

			whereRaw(column + " BETWEEN " + inputToParameter(greaterThan) + " AND " + inputToParameter(lessThan));

			return this;
		}


		public function whereNotBetween(column:String, greaterThan:Number, lessThan:Number):BreezeQueryBuilder
		{
			validateColumnName(column);

			whereRaw(column + " NOT BETWEEN " + inputToParameter(greaterThan) + " AND " + inputToParameter(lessThan));

			return this;
		}


		public function whereNull(column:String):BreezeQueryBuilder
		{
			validateColumnName(column);

			whereRaw(column + " IS NULL");

			return this;
		}


		public function whereNotNull(column:String):BreezeQueryBuilder
		{
			validateColumnName(column);

			whereRaw(column + " IS NOT NULL");

			return this;
		}


		public function whereIn(column:String, values:Array):BreezeQueryBuilder
		{
			validateColumnName(column);

			whereRaw(column + " IN (" + arrayToParameters(values).join(",") + ")");

			return this;
		}


		public function whereNotIn(column:String, values:Array):BreezeQueryBuilder
		{
			validateColumnName(column);

			whereRaw(column + " NOT IN (" + arrayToParameters(values).join(",") + ")");

			return this;
		}


		public function whereDay(dateColumn:String, param2:* = null, param3:* = null):BreezeQueryBuilder
		{
			validateColumnName(dateColumn);

			param2 = formatDayOrMonth(param2, "date");
			param3 = formatDayOrMonth(param3, "date");

			where("strftime('%d', " + dateColumn + ")", param2, param3);

			return this;
		}


		public function whereMonth(dateColumn:String, param2:* = null, param3:* = null):BreezeQueryBuilder
		{
			validateColumnName(dateColumn);

			param2 = formatDayOrMonth(param2, "month");
			param3 = formatDayOrMonth(param3, "month");

			where("strftime('%m', " + dateColumn + ")", param2, param3);

			return this;
		}


		public function whereYear(dateColumn:String, param2:* = null, param3:* = null):BreezeQueryBuilder
		{
			validateColumnName(dateColumn);

			param2 = formatDayOrMonth(param2, "fullYear");
			param3 = formatDayOrMonth(param3, "fullYear");

			where("strftime('%Y', " + dateColumn + ")", param2, param3);

			return this;
		}


		public function whereDate(dateColumn:String, param2:* = null, param3:* = null):BreezeQueryBuilder
		{
			validateColumnName(dateColumn);

			if(param2 is Date)
			{
				param2 = getShortStringFromDate(param2);
			}

			if(param3 is Date)
			{
				param3 = getShortStringFromDate(param3);
			}

			where("date(" + dateColumn + ")", param2, param3);

			return this;
		}


		public function whereColumn(param1:*, param2:String = null, param3:String = null):BreezeQueryBuilder
		{
			if(!(param1 is Array || param1 is String))
			{
				throw new ArgumentError("Parameter param1 must be either an Array or String.");
			}

			// Simple equal statement, e.g. whereColumn("views", "downloads)
			if(param1 is String && param3 === null)
			{
				whereColumn(param1, "=", param2);
			}
			// Simple statement with operator, e.g. whereColumn("views", ">", "downloads")
			else if(param1 is String && param2 !== null && param3 !== null)
			{
				validateColumnName(param1);
				validateColumnName(param3);

				whereRaw(param1 + " " + param2 + " " + param3);
			}
			// Array of statements, e.g. whereColumn([["views", "downloads"], ["likes", ">", "downloads"])
			else if(param1 is Array && param2 === null && param3 === null)
			{
				for each(var statement:* in param1)
				{
					if(!(statement is Array))
					{
						throw new Error("Where must be an Array of Arrays.");
					}

					if(statement.length == 3)
					{
						whereColumn(statement[0], statement[1], statement[2]);
					}
					else if(statement.length == 2)
					{
						whereColumn(statement[0], "=", statement[1]);
					}
					else
					{
						throw new Error("Invalid whereColumn parameters.");
					}

				}
			}
			// Invalid input
			else
			{
				throw new ArgumentError("Invalid whereColumn parameters.");
			}

			return this;
		}


		public function orderBy(...args):BreezeQueryBuilder
		{
			if(args.length % 2 != 0)
			{
				throw new ArgumentError("Invalid orderBy parameters.");
			}

			var length:uint = args.length;
			for(var i:int = 0; i < length; i+=2)
			{
				_orderBy[_orderBy.length] = args[i] + " " + args[i + 1];
			}
			return this;
		}


		public function groupBy(...args):BreezeQueryBuilder
		{
			var length:uint = args.length;
			for(var i:int = 0; i < length; ++i)
			{
				_groupBy[_groupBy.length] = args[i];
			}
			return this;
		}


		public function having(param1:*, param2:* = null, param3:* = null):BreezeQueryBuilder
		{
			// Raw having statement, e.g. having("count > 2")
			if(param1 is String && param2 === null && param3 === null)
			{
				havingRaw(param1);
			}
			// Simple equal statement, e.g. having("count", 15)
			else if(param1 is String && param3 === null)
			{
				having(param1, "=", param2);
			}
			// Simple statement with operator, e.g. having("count", "!=", 15)
			else if(param1 is String && param2 is String && param3 !== null)
			{
				havingRaw(param1 + " " + param2 + " " + inputToParameter(param3));
			}
			// Array of statements, e.g. having([["count", 15], ["team", "!=", "Alpha"])
			else if(param1 is Array && param2 === null && param3 === null)
			{
				for each(var statement:* in param1)
				{
					if(!(statement is Array))
					{
						throw new Error("Having must be an Array of Arrays.");
					}

					if(statement.length == 3)
					{
						having(statement[0], statement[1], statement[2]);
					}
					else if(statement.length == 2)
					{
						having(statement[0], "=", statement[1]);
					}
					else
					{
						throw new Error("Invalid having parameters.");
					}

				}
			}
			// Invalid input
			else
			{
				throw new ArgumentError("Invalid having parameters.");
			}

			return this;
		}


		public function orHaving(param1:*, param2:* = null, param3:* = null):BreezeQueryBuilder
		{
			_having[_having.length] = [];
			having(param1, param2, param3);

			return this;
		}


		public function limit(value:int):BreezeQueryBuilder
		{
			_limit = value;
			return this;
		}


		public function offset(value:int):BreezeQueryBuilder
		{
			_offset = value;
			return this;
		}


		public function insert(value:*, callback:* = null):BreezeQueryBuilder
		{
			if(value == null)
			{
				throw new ArgumentError("Parameter value cannot be null.");
			}

			_queryType = QUERY_INSERT;

			if(!(value is Array))
			{
				value = [value];
			}

			if(value is Array && value.length > 0)
			{
				if(_insertColumns == null)
				{
					setInsertColumns(value[0]);
				}

				for each(var row:Object in value)
				{
					addInsertObjects(row);
				}
			}
			else
			{
				throw new ArgumentError("Insert value must be a key-value object or Array of key-value objects.");
			}

			executeIfNeeded(callback);

			return this;
		}


		public function insertGetId(value:Object, callback:* = null):BreezeQueryBuilder
		{
			if(value == null)
			{
				throw new ArgumentError("Parameter value cannot be null.");
			}

			_queryType = QUERY_INSERT_GET_ID;

			setInsertColumns(value);
			addInsertObjects(value);
			
			executeIfNeeded(callback);

			return this;
		}


		public function update(value:Object, callback:* = null):BreezeQueryBuilder
		{
			if(value == null)
			{
				throw new ArgumentError("Parameter value cannot be null.");
			}

			_queryType = QUERY_UPDATE;

			_update = "";
			addUpdateValues(value);

			executeIfNeeded(callback);

			return this;
		}


		public function remove(callback:* = null):BreezeQueryBuilder
		{
			_queryType = QUERY_DELETE;

			executeIfNeeded(callback);

			return this;
		}


		public function increment(column:String, param1:* = null, param2:* = null, callback:* = null):BreezeQueryBuilder
		{
			incrementOrDecrement(column, param1, param2, callback, "+");

			return this;
		}


		public function decrement(column:String, param1:* = null, param2:* = null, callback:* = null):BreezeQueryBuilder
		{
			incrementOrDecrement(column, param1, param2, callback, "-");

			return this;
		}


		public function fetch(callback:* = null):BreezeQueryRunner
		{
			executeIfNeeded(callback);
			return this;
		}


		/**
		 * @inheritDoc
		 */
		override public function get queryString():String
		{
			_queryString = "";

			var parts:Vector.<String> = new <String>[];

			// SELECT
			if(_queryType == QUERY_SELECT)
			{
				addQueryPart(parts, "SELECT");

				// DISTINCT
				if(_distinct)
				{
					addQueryPart(parts, "DISTINCT");
				}

				if (_select.length == 0 || _select[0] == "*")
				{
					addQueryPart(parts, "*");
				}
				else
				{
					addQueryPart(parts, _select.join(", "));
				}

				// FROM
				addFromPart(parts);
			}
			// DELETE
			else if(_queryType == QUERY_DELETE)
			{
				addQueryPart(parts, "DELETE");

				// FROM
				addFromPart(parts);
			}
			// INSERT, INSERT_GET_ID
			else if(_queryType == QUERY_INSERT || _queryType == QUERY_INSERT_GET_ID)
			{
				// Multiple inserts must be split into single query each
				var tmpInsert:Array = [];
				for each(var insert:String in _insert)
				{
					tmpInsert[tmpInsert.length] = "INSERT INTO " + _tableName + " " + _insertColumns + " VALUES " + insert;
				}
				addQueryPart(parts, tmpInsert.join(";"));
			}
			// UPDATE
			else if(_queryType == QUERY_UPDATE)
			{
				addQueryPart(parts, "UPDATE " + _tableName + " SET " + _update);
			}

			// WHERE
			if(_where.length > 0 && _where[0].length > 0)
			{
				addQueryPart(parts, "WHERE");

				var tmpOrWhere:Array = [];
				for each(var whereArray:Array in _where)
				{
					tmpOrWhere[tmpOrWhere.length] = "(" + whereArray.join(" AND ") + ")";
				}

				addQueryPart(parts, tmpOrWhere.join(" OR "));
			}

			// GROUP BY
			if(_groupBy.length > 0)
			{
				addQueryPart(parts, "GROUP BY");
				addQueryPart(parts, _groupBy.join(", "));
			}

			// HAVING
			if(_having.length > 0 && _having[0].length > 0)
			{
				addQueryPart(parts, "HAVING");

				var tmpOrHaving:Array = [];
				for each(var havingArray:Array in _having)
				{
					tmpOrHaving[tmpOrHaving.length] = "(" + havingArray.join(" AND ") + ")";
				}

				addQueryPart(parts, tmpOrHaving.join(" OR "));
			}

			// ORDER BY
			if(_orderBy.length > 0)
			{
				addQueryPart(parts, "ORDER BY");
				addQueryPart(parts, _orderBy.join(", "));
			}

			// LIMIT
			if(_limit != -1)
			{
				addQueryPart(parts, "LIMIT " + _limit);
			}

			// OFFSET
			if(_offset != -1)
			{
				addQueryPart(parts, "OFFSET " + _offset);
			}

			_queryString = parts.join(" ");

			return super.queryString;
		}


		/**
		 *
		 *
		 * Private API
		 *
		 *
		 */


		private function whereRaw(query:String):BreezeQueryBuilder
		{
			var lastWhere:Array = _where[_where.length - 1];
			lastWhere[lastWhere.length] = query;

			return this;
		}


		private function havingRaw(query:String):BreezeQueryBuilder
		{
			var lastHaving:Array = _having[_having.length - 1];
			lastHaving[lastHaving.length] = query;

			return this;
		}
		
		
		private function addInsertObjects(row:Object):void
		{
			var values:String = "(";
			var i:int = 0;
			for each(var value:Object in row)
			{
				if(i++ > 0)
				{
					values += ", ";
				}
				values += inputToParameter(value);
			}

			if(i == 0)
			{
				throw new ArgumentError("Cannot insert row with no columns specified.");
			}

			values += ")";

			_insert[_insert.length] = values;
		}


		private function setInsertColumns(value:Object):void
		{
			_insertColumns = "(";
			var i:int = 0;
			for(var key:String in value)
			{
				if(i++ > 0)
				{
					_insertColumns += ", ";
				}
				_insertColumns += key;
			}
			_insertColumns += ")";
		}


		/**
		 * Formats the given value to a two-digit String,
		 * used for SQL comparison of months and days.
		 */
		private function formatDayOrMonth(param2:*, dateValue:String):*
		{
			if(param2 is Date)
			{
				param2 = param2[dateValue];

				// Month value starts from 0 so it must be incremented to match the SQL value
				if(dateValue == "month")
				{
					param2++;
				}
			}

			if(param2 is Number)
			{
				if(param2 < 0)
				{
					throw new ArgumentError("Negative value cannot be used for comparison.");
				}

				// Add leading zero if needed
				param2 = ((param2 < 10) ? "0" : "") + int(param2);
			}

			return param2;
		}
		
		
		private function inputToParameter(value:*):String
		{
			var name:String = ":param_" + _parametersIndex++;
			if(value is Date)
			{
				value = getLongStringFromDate(value as Date);
			}
			if(_queryParams == null)
			{
				_queryParams = {};
			}
			_queryParams[name] = value;
			return name;
		}


		private function arrayToParameters(values:Array):Array
		{
			var result:Array = [];
			for each(var value:* in values)
			{
				result[result.length] = inputToParameter(value);
			}

			return result;
		}


		private function executeIfNeeded(callback:*):void
		{
			_queryString = queryString;

			if(callback !== BreezeDb.DELAY)
			{
				if(!(callback is Function))
				{
					throw new ArgumentError("Parameter callback must be a Function or BreezeDb.DELAY constant.");
				}

				exec(callback);
			}
		}


		private function addQueryPart(parts:Vector.<String>, part:String):void
		{
			parts[parts.length] = part;
		}


		private function addFromPart(parts:Vector.<String>):void
		{
			parts[parts.length] = "FROM " + _tableName;
		}


		private function addUpdateValues(value:Object, separateFirst:Boolean = false):void
		{
			var i:int = 0;
			for(var key:String in value)
			{
				if(i++ > 0 || separateFirst)
				{
					_update += ", ";
				}
				_update += key + " = " + inputToParameter(value[key]);
			}
		}


		/**
		 * Internal implementation for <code>increment</code> and <code>decrement</code> methods.
		 */
		private function incrementOrDecrement(column:String, param1:*, param2:*, callback:*, operator:String):void
		{
			validateColumnName(column);

			_queryType = QUERY_UPDATE;

			if(callback === null)
			{
				if(param1 is Function || param1 === BreezeDb.DELAY)
				{
					callback = param1;
				}
				else if(param2 is Function || param2 === BreezeDb.DELAY)
				{
					callback = param2;
				}
			}

			// Increment amount
			var amount:Number = 1;
			if(param1 is Number)
			{
				amount = param1;
			}

			_update = column + " = " + column + " " + operator + " " + amount;

			if(!(param1 is Number) && param1 !== null && param1 !== callback)
			{
				addUpdateValues(param1, true);
			}

			if(!(param2 is Number) && param2 !== null && param2 !== callback)
			{
				addUpdateValues(param2, true);
			}

			executeIfNeeded(callback);
		}


		private function onChunkCompleted(error:Error, results:Collection):void
		{
			// Track subsequent chunk queries so that the callback is not called when there are no more results
			var initialChunk:Boolean = false;

			// Save the reference to the initial chunk query so we can see whether it was cancelled or not
			if(_chunkQueryReference == null)
			{
				initialChunk = true;
				_chunkQueryReference = _queryReference;
			}

			var numResults:uint = results.length;
			var terminate:Boolean = numResults == 0 || _originalCallback === null || _chunkQueryReference.isCancelled;

			// Trigger the original callback if we need to
			// If there are no results, the callback will be triggered only for the initial chunk call
			if(!_chunkQueryReference.isCancelled && _originalCallback != null && (numResults > 0 || initialChunk))
			{
				var params:Array = [error, results].slice(0, _originalCallback.length);

				// Check if the original callback tells us to stop making further chunk queries
				var canTerminate:Boolean = _originalCallback.apply(_originalCallback, params) === false;
				terminate = terminate || canTerminate;
			}

			if(terminate)
			{
				_chunkQueryReference = null;
				return;
			}

			_queryReference = null;
			chunk(_chunkLimit, _originalCallback);
		}


		private function validateColumnName(columnName:String):void
		{
			if(columnName == null)
			{
				throw new ArgumentError("Column name cannot be null.");
			}

			if(columnName.indexOf(";") >= 0)
			{
				throw new ArgumentError("Invalid column name: " + columnName);
			}
		}


		private function getShortStringFromDate(date:Date):String
		{
			return shortDateFormatter.format(date);
		}


		private function getLongStringFromDate(date:Date):String
		{
			return longDateFormatter.format(date);
		}


		private static function get shortDateFormatter():DateTimeFormatter
		{
			if(sShortDateFormatter == null)
			{
				sShortDateFormatter = new DateTimeFormatter("en-US");
				sShortDateFormatter.setDateTimePattern("yyyy-MM-dd");
			}
			return sShortDateFormatter;
		}


		private static function get longDateFormatter():DateTimeFormatter
		{
			if(sLongDateFormatter == null)
			{
				sLongDateFormatter = new DateTimeFormatter("en-US");
				sLongDateFormatter.setDateTimePattern("yyyy-MM-dd HH:mm:ss");
			}
			return sLongDateFormatter;
		}
	}
	
}
