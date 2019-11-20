local class = {
   _VERSION = 'class.lua 1.0.0',
     _URL = '',
     _DESCRIPTION = [[
      ============================================================================
      class_creator is an object creates a sudo class using metatables
      
      usage Classname = class:newClass (
                           class:attributes ( ... ),
                           class:initMethod ( func ),
                           class:addMethod ( name, func ) or class:addPrivateMethod ( name, func ) ......
                        )
      class:initMethod ( func ) -- adds the class init method, only can have one per class
      class:addMethod ( name, func) adds a method to that class of name. 
         Methods are inheretied by subclassed
      class:addPrivateMethod ( name, func ) adds a private mthod to that class of name.
         Private methods can only be called by the class, and are not inhereited by subclasses

      Public methods cannot be converted to private methods by a child class
      Private methods can be converted to public via a child class

      class:attributes ( ... )

      Where attributes are a list of tables, { name = className () }
         name is the attribute name
         className is the attribute type, Function - function, Number - number, String - string, Table - table,
         or an already created class.
   
      The attributes are type tested and stored in an objects metatable - the metatable is the class type itself.

      ============================================================================
      ]],
     _LICENSE = [[
      MIT LICENSE

      Copyright (c) 2019 David Porter

      Permission is hereby granted, free of charge, to any person obtaining a
      copy of this software and associated documentation files (the
      "Software"), to deal in the Software without restriction, including
      without limitation the rights to use, copy, modify, merge, publish,
      distribute, sublicense, and/or sell copies of the Software, and to
      permit persons to whom the Software is furnished to do so, subject to
      the following conditions:

      The above copyright notice and this permission notice shall be included
      in all copies or substantial portions of the Software.

      THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
      OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
      MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
      IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
      CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
      TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
      SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
      ]],
      _MODULENAME = ...,
      _LOGGING = false
}

-- stores classTypes
local classTypes
-- stores class building blocks initmethod, methods etc
local classBuildingBlocks

-- reference to type names
local types = {func =type (function () end), table = type ({}), init = 'init', methods = 'methods', special = 'special', number = type (9), string = type (''), bool = type (true), attributeStore = '_attributeStore'}

-- load up the inspect tool
local inspect = require ('inspect')

-- operators that a class can overload
local overloadOperators = {
   { v = '+', r = '__add'}, 
   { v = '-', r = '__sub'}, 
   { v = '*', r = '__mul'}, 
   { v = '/', r = '__div'}, 
   { v = '%', r = '__mod'}, 
   { v = '-', r = '__unm'}, 
   { v = '..', r = '__concat'}, 
   { v = '=', r = '__eq'}, 
   { v = '<', r = '__lt'}, 
   { v = '<=', r = '__le'}
}

--- called when an object of class c is created
local function getNewObject (class_tbl, c, ...)
   local obj = {}

   -- set the objects metatable to the class table, wher methods will be found
   setmetatable (obj, c)

   -- initilise from the base class up
   local inits, methods
   local parent = class:getParentClass (c)

   -- construct methods
   local methodBuilder = function (klass, privateCheck)
                           -- if privateCheck is set then only non private methods will be added
                           privateCheck = privateCheck or false
                           if klass._methods then
                              local next = next
                              local k, v
                              for k, v in next, klass._methods, nil do
                                 if not obj [k] then -- if method does not exist
                                    if not (privateCheck and v.private) then -- and sublass has it and its not private
                                       obj [k] = v.method -- it is my valid method
                                    end
                                 elseif not v.private and obj._methods [k].private then -- it already exists and a subclass already had it public, you can't now make it private
                                    error ('attempt make method ' .. k .. ' private, when in a parent class this method is public', 3)
                                 end
                              end
                           end
                        end


   -- get your own methods first, they may be overloading other methods
   methodBuilder (class_tbl)

   -- look for inits, methods in parent classes
   if c._inheritanceStructure then
      local x
      for x = 1, #c._inheritanceStructure do
         if c._inheritanceStructure [x].init then
            inits = inits or {}
            inits [#inits + 1] = c._inheritanceStructure [x].init
         end
         -- add the paretn methods next, if the method already exists you keep yours. If private you do not take the method.
         methodBuilder (c._inheritanceStructure [x], true)
      end
   end

   -- initilise all parent class inits in order
   if inits then
      local x 
      for x = #inits, 1, -1 do
         inits[x] (obj, ...)
      end
   end

   -- initilise your own init, if available
   if class_tbl.init then
      class_tbl.init (obj,...)
   end

   return obj
end

-- converts a number to number with english follow on eg 1st 2nd 3rd 4th etc
local function appendTextOnNumber (n)
   n = tonumber (n)
    local p  = 10^0
   n = math.floor(n * p) / p
   local v = n
   if n ~= 0 then
      local values = {'st','nd','rd'}
      n = n - math.floor (n/100) * 100
      local teens = n > 10 and n < 20
      n = n - math.floor (n/10) * 10
      if n == 0 or n > #values or teens then
         return v  .. 'th'
      else
         return v  .. values [n]
      end
   else
      return v
   end
end

--- this function gets an attribute/method for key k from object t of class c
local function getAttribute (t, k, c)
   -- get the attribute or method
   local v = rawget ( c, k )
   -- if it's an internal class store i.e. begins with a _ or a method then return it 
   if k:sub(1, 1) == '_' or type ( v ) == types.func then
      return v
   end
   -- it is an attribute so go get it from the attribute store 
   v = rawget (c, types.attributeStore)
   if v then
      v = rawget (v, tostring ( t ))
      if v then
         v = rawget (v, k)
      end
   end

   return v
end

--- this function stores an attribute in the class attribute store
local function storeAttribute (t, k, c, v)
   local attributes = rawget (c, types.attributeStore)
   attributes = attributes or {}
   local forWhatObj = attributes [tostring ( t )] or {}
   rawset (forWhatObj, k ,v)
   rawset (attributes, tostring ( t ), forWhatObj)
   rawset (c, types.attributeStore, attributes)
end

--- this function is called when an object attempts to set a new value
--- t is the table where the new value is to be set, k is the attribute name, v is the value and c the class table
--- the function performs type checking of the value v and raises exception if this is not correct
local function newAttributeSet (t, k, c, v)
   if c._attributes and c._attributes [k] then
      if type (c._attributes [k]) == types.string then
         if v == nil or type ( v ) == c._attributes [k] then
            storeAttribute (t, k, c, v)
         else
            error ('attribute ' .. k .. ' incorrect base type, expected ' .. c._attributes [k] .. ' not ' .. type ( v ), 3)
         end
      elseif c._attributes [k] == getmetatable ( v ) then
         storeAttribute (t, k, c, v)
      else
         error ('attribute ' .. k .. ' incorrect class type', 3)
      end
   else
      error ('attempt to set attribute ' .. k .. ', no such attribute for class', 3)
   end
end

-- this is the class logger function. If logging is true it constructs the message, if false it does not
-- ... paramter list are converted to strings and constructed p1 ... pN
local function classLogger ( ... )
   if class._LOGGING then
      local args = { ... }
      local message = 'classLogger: '
      local x
      for x = 1, #args do
         message = message .. tostring ( args [x] )
      end
      -- by default print is used, you can change this to what ever you want
      print (message)
   end
end

-- returns true if a table, false if empty table, nil if not a table 
local function tableIsEmpty (tbl)
   if type (tbl) ~= types.table then
      return nil
   else
      local next = next
      return next (tbl) ~= nil
   end
end

-- this function tests that a paramter is a method and store it in classBuildingBlocks
-- where is the store, currently init or methods, func is the method, name is the menthod name
local function buildingBlockBuilder (where, func, name, private)
   private = private or false
   -- base error messages
   local baseError = 'attempt to build class with '
   -- test to see if func is a function
   if func then
      if type (func) == types.func then
         classBuildingBlocks = classBuildingBlocks or {}
         -- only one init declaration permited per class construct
         if where == types.init and not classBuildingBlocks [types.init] then
            classBuildingBlocks [types.init] = func
            classLogger ('successfully found init method for class')
         elseif where == types.methods or where == types.special then
            classBuildingBlocks [where] = classBuildingBlocks [where] or {}
            -- test to see func name exists and is a string
            if name == tostring ( name ) then
               local methods = classBuildingBlocks [where]
               if not methods [name] then
                  -- succesfully addedd a new method
                  methods [name] = {method = func, private = private}
                  classLogger ('successfully found ', name, ' method for class')
               else
                  -- you've duplcated a method name
                  error (baseError .. 'duplicate ' .. name .. ' method' , 3)
               end
            else
               -- the method name is not a valid string
               error (baseError .. 'method, but method name ' .. tostring (name) .. ' is not valid' , 3)
            end
         else
            -- added a second call to initMethod
            error (baseError .. 'additional init method', 3)
         end
      else
         -- func was not a valid function
         error (baseError ..  type (func) .. ' "' .. func .. '"; this is not a ' .. types.func, 3)
      end
   else
      -- no method passed
      error (baseError ..  'empty ' .. where ..' method', 3)
   end
end

-- this function sets the attributes, it expects a table of format { arg1 = argType(), ..., argN = argNType () }
function class:attributes ( argTable )
   local argTableState = tableIsEmpty ( argTable )
   local errorMessage, validatedAttributes
   if classBuildingBlocks and classBuildingBlocks.attributes then
      errorMessage = 'attributtes for class already defined'
   else
      if argTableState ~= nil and argTableState then 
         local next = next
         local k, v
         for k, v in next, argTable, nil do
            errorMessage = 'argument ' .. k .. ' is not a known type: format must be argument = argType()'
            if type (v) == types.table then
               if v._isABaseType ~= nil then -- it is a type
                  errorMessage = nil
                  validatedAttributes = validatedAttributes or {}
                  if v._isABaseType then -- it is a base type
                     validatedAttributes [k] = v.bT
                  else -- it is a complex type
                     validatedAttributes [k] = getmetatable (v)
                  end
               else
                  break
               end
            else
               break
            end
         end
      else
         errorMessage = 'invalid argument table supplied: format must be { arg1 = argType(), ..., argN = argNType () }'
      end
   end
   if errorMessage then
      error (errorMessage, 2)
   else
      classBuildingBlocks = classBuildingBlocks or {}
      classBuildingBlocks.attributes = validatedAttributes
   end
end

-- this function get the base class i.e. root of a klass, nil if none
function class:getBaseClass (klass)
   if klass then
      if klass._base then 
         return class:getBaseClass (klass._base)
      else
         return klass
      end
   end
end

-- this funtion gets a classes parent class or nil if none
function class:getParentClass (klass)
   if klass and klass._base then
      return klass._base
   end
end

-- this function sets the init method for a class, can only be called once per class creation
function class:initMethod (func)
   classLogger ('attempt to form init method')
   buildingBlockBuilder (types.init, func)
end

-- this function sets a method by name into a class. All decendants of that class can call it.
function class:addMethod (name, func)
   classLogger ('attempt to form method ', name)
   buildingBlockBuilder (types.methods, func, name)
end

-- this function sets a method by name into a class. Method is private so can only be called by an object of that class.
function class:addPrivateMethod (name, func)
   classLogger ('attempt to form private method ', name)
   buildingBlockBuilder (types.methods, func, name, true)
end

-- this function allows an operator to be overloaded by a class
function class:overload (name, func)
   if name and type (name) == types.string then
      local x
      local overloaded = false
      for x = 1, #overloadOperators do
         local test = overloadOperators [x]
         if test.v == name then
            classLogger ('attempt to overload operator ', name)
            buildingBlockBuilder (types.special, func, test.r, true)
            overloaded = true
            break
         end
      end
      if not overloaded then
         error ('attempt to overload unknown operator ' .. name, 2)
      end
   else
      error ('attempt to overload with no value', 2)
   end
end

-- this is the newClass creator
function class:newClass (base, init)
   classLogger ('attempt to create new class - begin')
   local c = {}    -- a new class instance
   if not init and type(base) == types.func then -- this is a root class
      init = base
      base = nil
   elseif type (base) == types.table then -- this inherets from a another class
      -- our new class is a shallow copy of the base class!
      --for i,v in pairs(base) do
      --   c[i] = v
      --end
      c._base = base
   end

   -- mark as a complex type
   c._isABaseType = false

   -- the class will be the metatable for all its objects, it also stores attributes for class objects
   c.__index = function (t, k) return getAttribute (t, k, c) end

   -- get the inheretence structure for the class
   local inheritanceStructure
   local parent = class:getParentClass (c)
   while parent do
      inheritanceStructure = inheritanceStructure or {}
      inheritanceStructure [#inheritanceStructure + 1] = parent
      -- check for attributes i may inheret
      if parent._attributes then
         local next = next
         local k, v
         for k, v in next, parent._attributes, nil do
            classBuildingBlocks = classBuildingBlocks or {}
            classBuildingBlocks.attributes = classBuildingBlocks.attributes or {}
            -- if the attribute has been inheretred previously take the child as the parameter
            if not classBuildingBlocks.attributes [k] then
               classBuildingBlocks.attributes [k] = v
            end
         end
      end

      parent = class:getParentClass ( parent )
   end
   -- store any inheritance structure for the class
   c._inheritanceStructure = inheritanceStructure

   -- when a new value in a source object t is to be set
   c.__newindex = function (t, k, v)
                     newAttributeSet (t, k , c, v)
                  end

   -- expose a constructor which can be called by <classname>(<args>)
   local mt = {}

   mt.__call = function (class_tbl, ...) return getNewObject (class_tbl, c, ...) end
                  
   -- set up super
   c.super = class:getParentClass (c)

   -- load the methods/attributes
   if classBuildingBlocks then
      c.init = classBuildingBlocks [types.init]
      if classBuildingBlocks [types.methods] then
         local next = next
         local k, v
         c._methods = {}
         for k, v in next, classBuildingBlocks [types.methods], nil do
            c._methods [k] = v
            c [k] = c._methods [k].method
         end
      end
      if classBuildingBlocks [types.special] then
         local next = next
         local k, v
         for k, v in next, classBuildingBlocks [types.special], nil do
            rawset (c, k, v.method)
         end
      end
      if classBuildingBlocks.attributes then
         c._attributes = classBuildingBlocks.attributes
      end
   end

   -- function to test calss type: usage var:is_a (classType), returns true/false
   c.is_a = function(self, klass)
               local m = getmetatable(self)
               while m do 
                  if m == klass then return true end
                  m = m._base
               end
               return false
            end

   -- function to dump and entire class, requires the inspect to be loaded: usage var:inspect ()
   c.inspect = function (self)
                  if inspect then 
                     return (inspect (self))
                  else
                     return '>inspect not loaded<' 
                  end
               end

   setmetatable(c, mt)

   -- se the classBuildingBlocks up for next class
   classBuildingBlocks = nil

   classLogger ('attempt to create new class - end')

   return c

end

-- base classes, these return a true for a value b then bT is the LUA type
_G.String = function ( )
               return {_isABaseType = true, bT = types.string}
            end

_G.Number = function ( )
               return {_isABaseType =true, bT = types.number}
            end

_G.Table = function ( )
               return {_isABaseType =true, bT = types.table}
            end

_G.Bool = function ( )
               return {_isABaseType =true, bT = types.bool}
            end   

_G.Function = function ()
                  return {_isABaseType = true, bT = types.func} 
            end       

return class
