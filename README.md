# Lucky Lang  
  
This interpreter is VERY-VERY poorly written AND it even gets detected as a virus by windows, so the quality is self evident...  
If you, for some reason still want to give it a try, heres the spec:  
  
LuckyLang is Case - Sensitive and New-Line - Sensitive, in fact it relies on new lines to mark the end of a statement  

#### A statement begins with a:  
  
"def" -> DEFINE; "syscall" -> Internal call (println); "call" -> function call; "do" -> While Loop
  
#### and ends with a:  
  
"New-Line" -> call, syscall and def statements; "end \[expr\]" -> just "end" when def function or "end \[expression\] when do"  
  
#### Variables are valid for their current scope:  
  
GLOBAL (outside of functions) -> func1 -> func2 (can use all vars from global and func1)  
  
#### weird, I know, but it gets even better:  
#### Types (which don't really exist in this language) are not defined by name, but by symbol:  
  
"*" -> Number; "$" -> String; "&" -> Boolean; "#" -> Function
  
#### This means to declare a boolean variable with the name MyVar I would do the following:  
```
def &MyVar false
```  
#### When declaring a while-loop the exit-condition is written after the end-statement
#### When declating a function-block the interpreter expects an end-statement at the end of it, so be sure to put one there
  
#### Now, that you effectively know everything this language can do, you can build your own (probably non-functional) programm with it   
#### To do, that, first define the Main-Entry point, by defining a function with the Name "Main" and a singuolar parameter "args" of type String (note: there are technically parameters for functions, but I don't remember if the interpreter actually supports them in call statements)
#### A Hello World script would look like this:  
```
def $helloWorld "Hello World"
 
def #Main $args
  syscall println helloWorld
end
```  
#### At least it would look like that, if the interpreter did its job... The current version seems to have some problems regarding the syscall println statement, so yeah...  
### Again this interpreter is absolute grabage  
#### Not my proudest project
