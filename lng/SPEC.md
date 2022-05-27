# LNG

Language which is Not Good

## Obj.

- Lang. which can be compiled into lua line-by-line
- Add support of named tuple and pattern match

## Example

```
# <- This is a line comment

# Nil, Bool, Num(ber), Str(ing) are primitive types in LNG
123.45
"Hello, World!\n" # must use `"`, not `'`
True              # not `true`
False             # not `false`
Nil               # not `nil`

# There is a charactee type, but it's just a number representing the byte.
'a'               # ("a"):byte() in lua, which is 65.

# Table is also a primitive.
# The difference btw lua is
# - LNG use `=>` instead of `=`
# - LNG use `.(...)` insetead of `[...]`
a = { 1, 2, 3,
      key => 42,
      (3 + 5) => 5 }
a.key #=> 42
a.(8) #=> 5
# The above is compiled into lua as below:
local a = { 1, 2, 3,
            key = 42,
            [3 + 5] => 5 }
a.key #=> 42
a[8] #=> 5

# You can make variable using `=`.
# Every variable written with `=` is local except when
# - the scope is global
# - the prefix `$` used to denote global variable explicitly
# Var name rule:
# - ``""\@#$[]{}(),;.? and all whitespaces are reserved; not allowed for ID
# - ~!%^&*-+=|/<>: are 'operator characters' (opchar in below)
# - All other characters are id char (idchar in below)
# - Enclosing opchars & idchars with `` give you an ID (e.g. `abc-def++`)
# - If an ID only consist of opchars, it can be used as operator
# - Some reserved operator is not allowed without ``:
#   = => :: ::: := ::= :::= and & | and => concatenated with & |
# - If an ID only consist of idchars, it can be used without ``
#   except an id starting with `'` (which is considered as character literal)
#   number, and True, False, Nil

`some-id` = 20
hello_world = 30
ThisIsID044 = 50
f = \x = 10
f' = derivative f
`++` = table.merge   #=> then, you can use it as `a ++ b`
`=>` = 42            #=> it cannot be used as `a => b` because it's reserved
a'b'c = 9

$global = 10   #=> _G.global
$hello_world = 20
$`abcdef`      #=> $ must come before ``
$`+` = 5

# Note that if a variable is not in the local scope,
# it will search the global scope.
# Suppose that there is no local variable `boom` and
$boom = 42
# Then,
boom
# is equal to $boom, which is 42

# RHS of `=` has a nested scope. You can make vars and use them.
# EndOfLine is the end of RHS if an expression (not statement
# such as variable binding) appeared.

sum_of_squares_of_3_and_4 =
  square_of_3 = 3 * 3         # First binding
  square_of_4 =               # Second binding
    4 * 4                     # This is an expr, thus 2nd binding finished
  square_of_3 + square_of_4   # This is an expr for outermost binding

# Unnamed tuple can be constructed using  (,,,)
a = (1, 2, 3)  #=> {1, 2, 3} in lua
b = ()         #=> Empty tuple, {} in lua
c = (4,)       #=> Singleton, {4} in lua.
a.(1)          #=> Access 1st element, which is 1

# Named tuple constructor can be constructed using `:=`
Student := (name, major)
john = Student("john", "MAS")
john.tag #=> NamedTupleID of Student in Number type
john.tag == Student #=> True
john.(1) #=> "john"
john.major #=> "MAS"

Dog := (name, age)

# If you want to destruct a tuple, use `?` (pattern match)

john ? Student(n, m) =>  # john = Student(...), n <- john.(1), m <- john.(2)
       print(n)
     | Dog(n, a) =>      # john = Dog(...), n <- john.(1), m <- john.(2)
       print("age" .. numToString(a))
     | Dog =>            # Check john = the constructor Dog
       35
     | (x, y, z) =>      # Unnamed tuple with at least 3 elements
        x
     | 42 =>             # john = 42
       printInt(42)
     | True => Boom()    # john = True
     | x =>              # x <- john
       error("BOOM!")

# If you have some condition for pattern id, use `&`
john ?
 | Student(n, m) & m == "CS" => ...
 ...

# If pattern is not given, the first pattern will be `True` and the second
# one will be `_` (takes everything). Thus it can be used is if-else

3 + 2 > 5 ?=> print("3 + 2 > 5")
          |=> print("3 + 2 <= 5")

john ? Student(n, m) => n    # If john is Student
     |               => Nil  # Otherwise

# Function can be constructed using `\ <ARGS> = <BODY>`,
# and invoke it as `<FN>(<ARGS>)`

inc1 = \x = x + 1
inc1(10) #= 11

add = \x, y = x + y
add(3, 4) #= 7

# If a function takes a single argument, you don't need a parentheses
inc1 10 #= 11

# You can make nested function

curried_add = \x = \y = x + y
add(3)(4) #= which is same as `add 3 4` and the result is 7

# Instead of use `\`, you can bind a function by put a function call format
# in LHS of `=` statement.

add(x, y) = x + y
curried_add(x)(y) = x + y # or curried_add x y = x + y

# If some argument are missing, Nil will replace them.
add 3 # it's equal to add(3, Nil)

# The example code using above features:

# Make a tree
Node := (left, v, right)
Leaf := v

depthOfTree node = node?
  | Leaf _ => 1
  | Node(l, _, r) =>
    ld = depthOfTree l
    rd = depthOfTree r
    1 + (ld > rd ?=> ld |=> rd)

# If id name only consists of opchars, it can be used as an binary operator.
# and, if id consists of opchars and the last character is `_`,
# it can be used as an unary operator.

`++`(x, y) = x * x + y * y
five = sqrt(3 ++ 4)  #= 5

`~_` num = num ? (real, imag) =>
  (real, -imag)
~(1, 1) #=(1, -1)

# If you don't want a operator form, use ``.
`++`(3, 4) # is equal ot 3 ++ 4
`~_` 5 # is equal to ~5

# Unary operator does not have an operator precedence,
# it is applied from right to left
+ * - x #= `+`(`*`(`-`(x)))
# Note that if there is non-operator on the LHS of operator,
# It does not consieder as an unary operator
a + * - f #= a + (`*`(`-`(f))), because there is `a` on the leftside of `+`

# The precedence of binary operator can be set by user:
@* `+` 10   # Set the precedence of `+` as 10 and right associative
@* `**` -20 # Set the precedence of `**` as 20 and left associative
# positive/negative = right/left associative
# absolute value = precedence (higher one will be associated first)

# Note that operator precedences and operator bindings are not related.
# For example,

@* `+` -10
@* `*` -12

`+`(x, y) = x + y
`*` = `+`

3 + 4 * 5 #=> `*` associates first, even if they are same value.

# Also, operator precedences has effect from the annotation until
# the precedence is set to another value.

# If you want to include other file, use
@"filename"
# It work as `#include` in C, but do nothing if the file is already included

# if, while, for, break, return in lua are provided in limited way:

@if(C1, B1, C2, B2, ..., Belse)
  #=> equal to ` if C1 then B1 elseif C2 then B2 ... else Belse end`
@while(COND, B) #=> equal to `while COND do B end`
@for(VAR,FROM,TO,INC,B) #=> equal to `for VAR=FROM,TO,INC do B end`
@foreach(VARS,ITER,B) #=> equal to `for VARS in ITER do B end`
@break          #=> equal to `break`
@return(VAL)    #=> equal to `return VAL`
@call(FN,ARGS)  #=> equal to `FN(ARGS)` without any process on `FN`

# Builtin is not defined yet.

# `;` can be used for EOL, and `@` at end of line to use continuation of line

# [] used for list.

`[]` := ()
`:` := (elem, next)
@* `:` 5

[1, 2, 3] # equals to 1 : (2 : (3 : []))
```