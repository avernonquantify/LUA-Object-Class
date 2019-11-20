-- Example Use of class.lua


class = require ('class')
inspect = require ('inspect')

local Magic = class:newClass( class:attributes ({info = Table()}) )

local Animal = class:newClass( 
      class:attributes ({info = Number()}),
      class:initMethod (function (obj, ...) print ('new Animal') obj.info = 7 end),
      class:addMethod ('base',function (obj, ...) print ('base method') end),
      class:overload ('+', function (obja, objb) print ('you added', obja, objb) end)
   ) 

local Feline = class:newClass(Animal, 
      class:attributes ({x = Number(), y = Animal()}),
      class:initMethod (function (obj, ...) print ('new Feline')  end)
   ) 

local Canine = class:newClass(Animal, 
      class:initMethod (function (obj, ...) print ('new Canine')  end)
   ) 

local Dog = class:newClass(Canine, 
      class:initMethod (function (obj, ...) print ('new Dog')  end),
      class:addMethod ('base',function (obj, ...) print ('top method for a dog')  end)
   ) 

local Cat = class:newClass(Feline, 
      class:initMethod (function (obj, ...) print ('new Cat') end),
      class:addMethod ('base',function (obj, ...) print ('top method for a cat') end)
   ) 

print ('going to build a Dog\n\n')
local a = Dog()
print ('going to build a Cat\n\n')
local b = Cat()

a:base ()
b:base ()

local c = Animal ()
d = c + c

print (c.info)

-- the next line will throw an exception as type Animal (which c is) attribute info is a Number
-- c.info = {}
-- the next line will throw an exception as type Animal (which c is) does not have an attribute test
-- c.test = 4

c:base ()
