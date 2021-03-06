{-

A basic interpreter for a purely functional subset of Scheme named SkimScheme.
Part of this interpreter has been derived from the "Write Yourself a Scheme in
48 Hours - An Introduction to Haskell through Example", by Jonathan Tang. It
does not implement a number of Scheme's constructs. Moreover, it uses a
different approach to implement mutable state within the language.

The name "SkimScheme" refers to the stripped down nature of this interpreter.
According to the New Oxford American Dictionary, "skim" can mean:

(as a verb) ... read (something) quickly or cursorily so as to note only
the important points.

(as a noun) ... an act of reading something quickly or superficially. 

"skimmed/skim milk" is milk from which the cream has been removed. 

The name emphasizes that we do not want to cover the entire standard, small as
it may be. Instead, we want to focus on some of the important aspects, taking a
language implementer's point of view, with the goal of using it as a teaching
tool. Many, many, many aspects of Scheme standards are not covered (it does not
even support recursion!).

Written by Fernando Castor
Started at: August 28th 2012
Last update: December 17th 2012

-}

module Main where
import System.Environment
import Control.Monad
import Data.Map as Map
import LispVal
import SSParser
import SSPrettyPrinter

-----------------------------------------------------------
--                      INTERPRETER                      --
-----------------------------------------------------------
eval :: StateT -> StateT ->  LispVal -> StateTransformer LispVal
eval env amb val@(String _) = return val
eval env amb val@(Atom var) = stateLookup env amb var 
eval env amb val@(Number _) = return val
eval env amb val@(Bool _) = return val
eval env amb (List [Atom "quote", val]) = return val
eval env amb (List (Atom "begin":[v])) = eval env amb v
eval env amb (List (Atom "begin": l: ls)) = (eval env amb l) >>= (\(result) -> case result of { (error@(Error _)) -> return error; otherwise -> eval env amb (List (Atom "begin": ls))})
--eval env amb (List (Atom "begin": l: ls)) = eval env amb l >> eval env amb (List (Atom "begin": ls))
eval env amb (List (Atom "begin":[])) = return (List [])
eval env amb lam@(List (Atom "lambda":(List formals):body:[])) = return lam
-- The following line is slightly more complex because we are addressing the
-- case where define is redefined by the user (whatever is the user's reason
-- for doing so. The problem is that redefining define does not have
-- the same semantics as redefining other functions, since define is not
-- stored as a regular function because of its return type.
eval env amb (List (Atom "define": args)) = maybe (define env amb args) (\v -> return v) (Map.lookup "define" (union env amb))

eval env amb (List (Atom "if": test : consequent : alternate : [])) = (eval env amb test) >>= (\(result) -> case result of {(Bool x) -> (if (x) then (eval env amb consequent) else (eval env amb alternate));error@(Error _) -> return error; _ -> eval env amb consequent})

eval env amb (List (Atom "set!": args@(Atom var:value:[]))) = stateLookup env amb var >>= (\x -> case x of {error@(Error _) ->  return error; otherwise -> define env amb args })

eval env amb (List [Atom "create-struct", List (Atom "quote": List val : [])]) = return (createStruct val)

eval env amb (List [Atom "set-attr!", struct, Atom id, val]) = 
  eval env amb struct >>= (\result -> case result of{(Struct struct) -> return (setAttr (Struct struct: Atom id: val:[]));
    otherwise -> (return (Error "not a struct"))})

eval env amb (List [Atom "get-attr", struct, Atom id]) = 
  eval env amb struct >>= (\result -> case result of{(Struct struct) -> return (getAttr (Struct struct: Atom id: []));
    otherwise -> (return (Error "not a struct"))})

eval env amb (List (Atom "let": args: body)) = ST( \s a-> let
                                              (ST m) = ((setLet env amb args) >>= (\x -> (eval env amb (List (Atom "begin": body)))))
                                              (result, state, ambiance) = m s a
                                              in (result,state, a))

eval env amb (List (Atom func : args)) = mapM (eval env amb) args >>= apply env amb func 



eval env amb (Error s)  = return (Error s)
eval env amb form = return (Error ("Could not eval the special form: " ++ (show form)))

createStruct :: [LispVal] -> LispVal
createStruct [] = Struct empty
createStruct ( (Atom (id)) : nextArgs) = case (createStruct nextArgs) of
                                 Struct (args) -> Struct ( insert id (Number 0) args )
                                 error@(Error s) -> error
createStruct _ = Error ("not a valid struct.")

setAttr :: [LispVal] -> LispVal
setAttr (Struct struct : Atom id : val :[]) = case (Map.lookup id struct) of {
                                                                                Nothing -> Error "field does not exist.";
                                                                                otherwise -> Struct (insert id val struct)
                                                                              }
setAttr _ = Error "not a valid struct."

getAttr :: [LispVal] -> LispVal
getAttr (Struct struct : Atom id : []) = case (Map.lookup id struct) of {
                                                                          Nothing -> Error "field does not exist.";
                                                                          Just val -> val
                                                                        }
getAttr _ = Error "not a valid struct."

setLet :: StateT -> StateT -> LispVal -> StateTransformer LispVal
setLet env amb (List ( (List [Atom id, val]) : []) ) = defineVar env amb id val >>= (\x -> ST(\s a -> (x,s,a)))
setLet env amb (List ( (List [Atom id, val]) : xs) ) = defineVar env amb id val >>= (\x -> ST(\s a -> (x,s,a))) >> setLet env amb (List xs)

stateLookup :: StateT -> StateT -> String -> StateTransformer LispVal
stateLookup env amb var = ST $ 
  (\s a -> 
    (maybe (Error "variable does not exist.") 
           id (Map.lookup var (union (union (union a s) env ) amb)), s, a))


-- Because of monad complications, define is a separate function that is not
-- included in the state of the program. This saves  us from having to make
-- every predefined function return a StateTransformer, which would also
-- complicate state management. The same principle applies to set!. We are still
-- not talking about local definitions. That's a completely different
-- beast.
define :: StateT -> StateT -> [LispVal] -> StateTransformer LispVal
define env amb [(Atom id), val] = defineVar env amb id val
define env amb [(List [Atom id]), val] = defineVar env amb id val
-- define env amb [(List l), val]                                       
define env amb args = return (Error "wrong number of arguments")

defineVar env amb id val = 
  ST (\s a -> let (ST f) = (eval env amb val)
                  (result, newState, newAmb) = f s a
              in (result, s, (insert id result newAmb))
     )


-- The maybe function yields a value of type b if the evaluation of 
-- its third argument yields Nothing. In case it yields Just x, maybe
-- applies its second argument f to x and yields (f x) as its result.
-- maybe :: b -> (a -> b) -> Maybe a -> b
apply :: StateT -> StateT -> String -> [LispVal] -> StateTransformer LispVal
apply env amb func args =  
                  case (Map.lookup func (union env amb)) of
                      Just (Native f)  -> return (f args)
                      otherwise -> 
                        (stateLookup env amb func >>= \res -> 
                          case res of 
                            List (Atom "lambda" : List formals : body:l) -> lambda env amb formals body args                              
                            otherwise -> return (Error "not a function.")
                        )
 
-- The lambda function is an auxiliary function responsible for
-- applying user-defined functions, instead of native ones. We use a very stupid 
-- kind of dynamic variable (parameter) scoping that does not even support
-- recursion. This has to be fixed in the project.
lambda :: StateT -> StateT -> [LispVal] -> LispVal -> [LispVal] -> StateTransformer LispVal
lambda env amb formals body args = 
  let dynEnv = Prelude.foldr (\(Atom f, a) m -> Map.insert f a m) (union env amb) (zip formals args)
  in  eval env dynEnv body
  --Pode tá com merda


-- Initial env ambironment of the programs. Maps identifiers to values. 
-- Initially, maps function names to function values, but there's 
-- nothing stopping it from storing general values (e.g., well-known
-- constants, such as pi). The initial env ambironment includes all the 
-- functions that are available for programmers.
environment :: Map String LispVal
environment =   
            insert "number?"        (Native predNumber)
          $ insert "boolean?"       (Native predBoolean)
          $ insert "list?"          (Native predList)
          $ insert "+"              (Native numericSum) 
          $ insert "*"              (Native numericMult) 
          $ insert "-"              (Native numericSub) 
          $ insert "/"              (Native numericDiv) 
          $ insert "lt?"            (Native numericLt) 
          $ insert ">"              (Native numericGt)
          $ insert "modulo"         (Native numericMod)
          $ insert "eqv?"           (Native eqv)  
          $ insert "cons"           (Native cons)           
          $ insert "car"            (Native car)           
          $ insert "cdr"            (Native cdr)
          $ insert "append"         (Native append)
          $ insert "string-append"  (Native stringAppend)
          $ insert "or"             (Native orFunction)
          $ insert "not"            (Native notFunction)
          $ insert "null?"          (Native nullFunction)
            empty

type StateT = Map String LispVal

-- StateTransformer is a data type that embodies computations
-- that transform the state of the interpreter (add new (String, LispVal)
-- pairs to the state variable). The ST constructor receives a function
-- because a StateTransformer gets the previous state of the interpreter 
-- and, based on that state, performs a computation that might yield a modified
-- state (a modification of the previous one). 
data StateTransformer t = ST (StateT -> StateT -> (t, StateT, StateT))

instance Monad StateTransformer where
  return x = ST (\s a -> (x, s, a))
  (>>=) (ST m) f = ST (\s a-> let (v, newS, newA) = m s a
                                  (ST resF) = f v
                             in  resF newS newA
                      )
    
-----------------------------------------------------------
--          HARDWIRED PREDEFINED LISP FUNCTIONS          --
-----------------------------------------------------------

-- Includes some auxiliary functions. Does not include functions that modify
-- state. These functions, such as define and set!, must run within the
-- StateTransformer monad. 

nullFunction :: [ LispVal ] -> LispVal
nullFunction [List []] = Bool True
nullFunction _ = Bool False

car :: [LispVal] -> LispVal
car [List (a:as)] = a
car [DottedList (a:as) _] = a
car ls = Error "invalid list."

cdr :: [LispVal] -> LispVal
cdr (List (a:as) : ls) = List as
cdr (DottedList (a:[]) c : ls) = c
cdr (DottedList (a:as) c : ls) = DottedList as c
cdr ls = Error "invalid list."

orFunction :: [LispVal] -> LispVal
orFunction [Bool a, Bool b] = Bool $ a || b
orFunction _ = Error "invalid arguments."

notFunction :: [LispVal] -> LispVal
notFunction [Bool a] = Bool $ not a
notFunction _ = Bool False

eqv :: [LispVal] -> LispVal
eqv [a , b] = Bool (a == b)
eqv _ = Error "wrong number of arguments."

cons :: [LispVal]-> LispVal
cons [a, List b] = List (a:b)
cons _ = Error "invalid arguments."

append :: [LispVal] -> LispVal
append [List a, List b] = List(a++b)
append _ = Error "invalid arguments."

stringAppend :: [LispVal] -> LispVal
stringAppend [String a, String b] = String (a ++ b)
stringAppend _ = Error "invalid arguments."

predNumber :: [LispVal] -> LispVal
predNumber (Number _ : []) = Bool True
predNumber (a:[]) = Bool False
predNumber ls = Error "wrong number of arguments."

predBoolean :: [LispVal] -> LispVal
predBoolean (Bool _ : []) = Bool True
predBoolean (a:[]) = Bool False
predBoolean ls = Error "wrong number of arguments."

predList :: [LispVal] -> LispVal
predList (List _ : []) = Bool True
predList (a:[]) = Bool False
predList ls = Error "wrong number of arguments."

numericSum :: [LispVal] -> LispVal
numericSum [] = Number 0
numericSum l = numericBinOp (+) l

numericMult :: [LispVal] -> LispVal
numericMult [] = Number 1
numericMult l = numericBinOp (*) l

numericDiv :: [LispVal] -> LispVal
numericDiv args@([Number x, Number y]) = if ( y == 0)
                                    then Error "division by zero"
                                    else numericBinOp div args
numericDiv _ = Error "Wrong number of arguments."

numericLt :: [LispVal] -> LispVal
numericLt args@([Number x, Number y]) = Bool $ x < y
numericLt _ = Error "Wrong number of arguments."

numericGt :: [LispVal] -> LispVal
numericGt args@([Number x, Number y]) = Bool $ x > y
numericGt _ = Error "Wrong number of arguments."

numericMod :: [LispVal] -> LispVal
numericMod args@([Number x, Number y]) = if ( y == 0)
                                    then Error "undefined for 0"
                                    else numericBinOp mod args
numericMod _ = Error "Wrong number of arguments."

numericSub :: [LispVal] -> LispVal
numericSub [] = Error "wrong number of arguments."
-- The following case handles negative number literals.
numericSub [x] = if onlyNumbers [x]
                 then (\num -> (Number (- num))) (unpackNum x)
                 else Error "not a number."
numericSub l = numericBinOp (-) l

-- We have not implemented division. Also, notice that we have not 
-- addressed floating-point numbers.

numericBinOp :: (Integer -> Integer -> Integer) -> [LispVal] -> LispVal
numericBinOp op args = if onlyNumbers args 
                       then Number $ foldl1 op $ Prelude.map unpackNum args 
                       else Error "not a number."
                       
onlyNumbers :: [LispVal] -> Bool
onlyNumbers [] = True
onlyNumbers (Number n:ns) = onlyNumbers ns
onlyNumbers ns = False             
                       
unpackNum :: LispVal -> Integer
unpackNum (Number n) = n
--- unpackNum a = ... -- Should never happen!!!!

-----------------------------------------------------------
--                     main FUNCTION                     --
-----------------------------------------------------------

showResult :: (LispVal, StateT, StateT) -> String
showResult (val, defs, amb) = show val ++ "\n" ++ show (toList amb) ++ "\n"

getResult :: StateTransformer LispVal -> (LispVal, StateT, StateT)
getResult (ST f) = f empty empty -- we start with an empty state. 

main :: IO ()
main = do args <- getArgs
          putStr $ showResult $ getResult $ eval environment environment $ readExpr $ concat $ args 
          
