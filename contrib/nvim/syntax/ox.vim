if exists("b:current_syntax")
  finish
endif

syn keyword oxTodo      TODO FIXME XXX contained
syn match   oxComment   "//.*$" contains=oxTodo,@Spell
syn region  oxComment   start="/\*" end="\*/" contains=oxTodo,@Spell

syn keyword oxKeyword   fn let var class struct import return if elif else
syn keyword oxKeyword   for in while break continue match pub lazy

syn keyword oxType      int float bool str void
syn keyword oxType      List Map Option Result Deque DefaultDict

syn keyword oxBool      true false
syn keyword oxConst     None Some Ok Err

syn match  oxNumber     "\<\d\+\.\d\+\>"
syn match  oxNumber     "\<\d\+\>"
syn match  oxNumber     "\<0[xX][0-9a-fA-F]\+\>"

syn region oxString     start=+"+ skip=+\\\\\|\\"+ end=+"+

syn keyword oxOperator  and or not is in
syn match  oxOperator   "+\|-\|\*\|\/\|%\|==\|!=\|<\|>\|<=\|>=\|&&\|||\|!\|="

syn match  oxFunction   "\<\w\+\s*("he=e-1 contains=oxIdentifier
syn match  oxIdentifier "\<\w\+\>" contained

hi def link oxTodo      Todo
hi def link oxComment   Comment
hi def link oxKeyword   Keyword
hi def link oxType      Type
hi def link oxBool      Boolean
hi def link oxConst     Constant
hi def link oxNumber    Number
hi def link oxString    String
hi def link oxOperator  Operator
hi def link oxFunction  Function

let b:current_syntax = "ox"
