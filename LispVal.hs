module LispVal (LispVal(Atom, List, DottedList, Number, String, Bool, Error, Native)) where


-----------------------------------------------------------
--                    BASIC DATATYPES                    --
-----------------------------------------------------------
{- 
In Lisp, the data types representing code structures are the same as the
data types representing values. This somewhat simplifies the
construction of an interpreter. For other languages, one would use
different datatypes to represent structures that appear in the code
(statements, expressions, declarations, etc.) and the data that their
evaluation produces.
-}
data LispVal = Atom String
  | List [ LispVal ]
  | DottedList [ LispVal ] LispVal
  | Number Integer
  | String String 
  | Bool Bool
  | Error String
  | Native ([LispVal] -> LispVal)


instance Eq LispVal where
  (==) (Atom a)(Atom b) = (a == b)
  (==) (List a)(List b) = (a == b)
  (==) (DottedList as a) (DottedList bs b) = (a == b && as == bs)
  (==) (Number a)(Number b) = (a == b)
  (==) (String a )(String b) = ( a == b)
  (==) (Bool a)(Bool b) = ( a && b || (not a) && (not b))
  (==) _ _ = (False)