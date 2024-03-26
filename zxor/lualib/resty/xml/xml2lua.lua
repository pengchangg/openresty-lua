--- Module providing a non-validating XML stream parser in Lua. 
--  
--  Features:
--  =========
--  
--      * Tokenises well-formed XML (relatively robustly)
--      * Flexible handler based event API (see below)
--      * Parses all XML Infoset elements - ie.
--          - Tags
--          - Text
--          - Comments
--          - CDATA
--          - XML Decl
--          - Processing Instructions
--          - DOCTYPE declarations
--      * Provides limited well-formedness checking 
--        (checks for basic syntax & balanced tags only)
--      * Flexible whitespace handling (selectable)
--      * Entity Handling (selectable)
--  
--  Limitations:
--  ============
--  
--      * Non-validating
--      * No charset handling 
--      * No namespace support 
--      * Shallow well-formedness checking only (fails
--        to detect most semantic errors)
--  
--  API:
--  ====
--
--  The parser provides a partially object-oriented API with 
--  functionality split into tokeniser and handler components.
--  
--  The handler instance is passed to the tokeniser and receives
--  callbacks for each XML element processed (if a suitable handler
--  function is defined). The API is conceptually similar to the 
--  SAX API but implemented differently.
--
--  XML data is passed to the parser instance through the 'parse'
--  method (Note: must be passed a single string currently)
--
--  License:
--  ========
--
--      This code is freely distributable under the terms of the [MIT license](LICENSE).
--
--
--@author Paul Chakravarti (paulc@passtheaardvark.com)
--@author Manoel Campos da Silva Filho
local xml2lua = {}
local XmlParser = require 'resty.xml.xmlparser'

local type = type
local pairs = pairs

---Instantiates a XmlParser object to parse a XML string
--@param handler Handler module to be used to convert the XML string
--to another formats. See the available handlers at the handler directory.
-- Usually you get an instance to a handler module using, for instance:
-- local handler = require("xmlhandler/tree").
--@return a XmlParser object used to parse the XML
--@see XmlParser
function xml2lua.parser(handler)    
    if handler == xml2lua then
		return nil,"You must call xml2lua.parse(handler) instead of xml2lua:parse(handler)"
    end

    local options = { 
            --Indicates if whitespaces should be striped or not
            stripWS = 1, 
            expandEntities = 1,
            errorHandler = function(errMsg, pos) 
				return string.format("%s [char=%d]\n", errMsg or "Parse Error", pos)
            end
          }

    return XmlParser.new(handler, options)
end

---Gets an _attr element from a table that represents the attributes of an XML tag,
--and generates a XML String representing the attibutes to be inserted
--into the openning tag of the XML
--
--@param attrTable table from where the _attr field will be got
--@return a XML String representation of the tag attributes
local function attrToXml(attrTable)
  local s = ""
  attrTable = attrTable or {}
  
  for k, v in pairs(attrTable) do
      s = s .. " " .. k .. "=" .. '"' .. v .. '"'
  end
  return s
end

---Gets the first key of a given table
local function getFirstKey(tb)
   if type(tb) == "table" then
      for k, _ in pairs(tb) do
          return k
      end
      return nil
   end

   return tb
end

---Converts a Lua table to a XML String representation.
--@param tb Table to be converted to XML
--@param tableName Name of the table variable given to this function,
--                 to be used as the root tag. If a value is not provided
--                 no root tag will be created.
--@param level Only used internally, when the function is called recursively to print indentation
--
--@return a String representing the table content in XML
function xml2lua.toXml(tb, tableName, level)
  level = level or 1
  local firstLevel = level
  local spaces = string.rep(' ', level*2)
  tableName = tableName or ''
  local xmltb = (tableName ~= '' and level == 1) and {'<'..tableName..'>'} or {}

  for k, v in pairs(tb) do
      if type(v) == 'table' then
         -- If the key is a number, the given table is an array and the value is an element inside that array.
         -- In this case, the name of the array is used as tag name for each element.
         -- So, we are parsing an array of objects, not an array of primitives.
         if type(k) == 'number' then
            local attrs = attrToXml(v._attr)
            v._attr = nil
            table.insert(xmltb, 
                spaces..'<'..tableName..attrs..'>\n'..xml2lua.toXml(v, tableName, level+1)..
                '\n'..spaces..'</'..tableName..'>') 
         else 
            level = level + 1
            -- If the type of the first key of the value inside the table
            -- is a number, it means we have a HashMap-like structcture,
            -- in this case with keys as strings and values as arrays.
            if type(getFirstKey(v)) == 'number' then 
               table.insert(xmltb, xml2lua.toXml(v, k, level))
            else
               -- Otherwise, the "HashMap" values are objects 
               local attrs = attrToXml(v._attr)
               v._attr = nil
               table.insert(xmltb, 
                   spaces..'<'..k..attrs..'>\n'.. xml2lua.toXml(v, k, level+1)..
                   '\n'..spaces..'</'..k..'>')
            end
         end
      else
         -- When values are primitives:
         -- If the type of the key is number, the value is an element from an array.
         -- In this case, uses the array name as the tag name.
         if type(k) == 'number' then
            k = tableName
         end
         table.insert(xmltb, spaces..'<'..k..'>'..tostring(v)..'</'..k..'>')
      end
  end

  if tableName ~= '' and firstLevel == 1 then
      table.insert(xmltb, '</'..tableName..'>\n')
  end

  return table.concat(xmltb, '\n')
end

return xml2lua
