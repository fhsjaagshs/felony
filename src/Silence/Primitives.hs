{-# LANGUAGE OverloadedStrings, FlexibleContexts #-}
module Silence.Primitives
(
  primitives,
  primitiveConstants
)
where
  
import Silence.Syntax
import Silence.Expression

import Control.Monad.IO.Class
import Control.Monad.State.Strict

import Data.Maybe
import Data.Ratio
import qualified Data.HashMap.Strict as H
import qualified Data.ByteString.Char8 as B

{- TODO
* Real world features
  * randomness
  * file descrptors - see system programming
    * files
    * consoles
    * sockets (allows for networking!)
  * concurrency - see system programming
  * system programming - primitive procedure that takes a list of args and a system call number
  * c interface
* get-env & put-env
-}

primitiveConstants :: Scope
primitiveConstants = H.fromList []

-- |Primitive procedures that cannot be implemented in lisp. Most of them
-- behave just like procedures defined in lisp, but are defined in Haskell.
-- There are some procedures which inhibit parameter evaluation. These procedures
-- (such as @lambda@) evaluate parameters internally according to their own logic.
primitives :: Scope
primitives = H.fromList [
  mkProc "." True 2 composeE, -- function composition, result of 2nd proc gets passed to 1st proc.
  mkProc "=" True 2 eqlE,
  mkProc ">" True 2 $ compE (>),
  mkProc ">=" True 2 $ compE (>=),
  mkProc "<" True 2 $ compE (<),
  mkProc "<=" True 2 $ compE (<=),
  mkProc "+" True 2 $ mathBinaryE (+),
  mkProc "-" True 2 $ mathBinaryE (-),
  mkProc "*" True 2 $ mathBinaryE (*),
  mkProc "/" True 2 $ mathBinaryE (/),
  mkProc "log" True 2 $ mathBinaryE $ wrapBinFrac logBase,
  mkProc "exp" True 1 $ mathUnaryE $ wrapFrac exp,
  mkProc "sin" True 1 $ mathUnaryE $ wrapFrac sin,
  mkProc "cos" True 1 $ mathUnaryE $ wrapFrac cos,
  mkProc "tan" True 1 $ mathUnaryE $ wrapFrac tan,
  mkProc "asin" True 1 $ mathUnaryE $ wrapFrac asin,
  mkProc "acos" True 1 $ mathUnaryE $ wrapFrac acos,
  mkProc "atan" True 1 $ mathUnaryE $ wrapFrac atan,
  mkProc "to-str" True 1 toStrE,
  mkProc "to-atom" True 1 toAtomE,
  mkProc "cons" True 2 consE,
  mkProc "car" True 1 carE,
  mkProc "cdr" True 1 cdrE,
  mkProc "numerator" True 1 numeratorE,
  mkProc "denominator" True 1 denominatorE,
  mkProc "print" True 1 printE, -- print a string
  mkProc "proc?" True 1 isProcE,
  mkProc "number?" True 1 isNumberE,
  mkProc "string?" True 1 isStringE,
  mkProc "atom?" True 1 isAtomE,
  mkProc "null?" True 1 isNullE,
  mkProc "list?" True 1 isListE,
  mkProc "pair?" True 1 isPairE,
  mkProc "read" True 1 readE, -- parse a string of code
  mkProc "let!" True 2 letBangE,
  mkProc "let-parent!" True 2 letParentBangE,
  mkProc "if" False 3 ifE,
  mkProc "quote" False 1 (const $ return . head), -- inhibit evaluation
  mkProc "lambda" False 2 $ lambdaE True, -- this one evaluates arguments
  mkProc "lambda!" False 2 $ lambdaE False, -- this one *doesn't* evaluate arguments
  mkProc "mk-lambda" True 2 $ lambdaE True, -- like lambda, but its args are evaluated
  mkProc "mk-lambda!" True 2 $ lambdaE False, -- like lambda, but its args are evaluated
  mkProc "evaluate" True 1 (const $ evaluate . head),
  mkProc "import" True 1 importE, -- load a source code file and evaluate it
  mkProc "begin" True (-1) (const $ return . last) -- sequential evaluation using language semantics
  ]

mkProc :: B.ByteString -> Bool -> Int -> (String -> PrimFunc) -> (B.ByteString, Expression)
mkProc name eval arity body = (name, Procedure eval arity $ body $ B.unpack name)

ifE :: String -> PrimFunc
ifE _ [x,t,f] = evaluate x >>= fn
  where fn (Bool False) = evaluate f
        fn _ = evaluate t
ifE n _ = invalidForm n

-- |Takes:
-- args -> list of atoms to which arguments will be bound
-- body -> a *single* expression that serves as the procedure's body.
-- Returns: function with arity @-1@ that evaluates args given key=val.
-- example: @(lambda (a b c) (+ a (+ b c)))@ returns a procedure
-- that adds three numbers.
lambdaE :: Bool -> String -> PrimFunc
lambdaE evalArgs n [args,body] = maybe argErr (lambda body) (fromAtoms args)
  where argErr = invalidForm $ n ++ ": invalid argument names"
        lambda bdy ["*"] = do
          cap <- get -- capture env it was defined in
          return $ Procedure evalArgs (-1) (scoped bdy cap . H.singleton "args" . toConsList)
        lambda bdy xs = do
          cap <- get -- capture env it was defined in
          return $ Procedure evalArgs (length xs) $ scoped bdy cap . H.fromList . zip xs
        scoped bdy cap env = modify' ((:) (mconcat $ env:cap)) *> evaluate bdy <* modify' tail
lambdaE _ n _ = invalidForm n

-- |Takes:
-- key -> what to bind the variable to
-- val -> value to bind
-- Does: Assigns val to key in the current environment scope.
letBangE :: String -> PrimFunc
letBangE _ [Atom k,v] = modify' add >> return v
  where add [] = error "empty stack"
        add (e:es) = (H.insert k v e):es
letBangE n _ = invalidForm n

-- |Like letBangE, except it first pops the environment.
letParentBangE :: String -> PrimFunc
letParentBangE _ [Atom k,v] = modify' add >> return v
  where add [] = error "empty stack"
        add [_] = error "no parent scope"
        add (e:e':es) = e:(H.insert k v e'):es
letParentBangE n _ = invalidForm n

-- |Compose two functions of arbitrary arities. If @barity@ is > 1,
-- this will return a procedure. @((. b a)<args>)@ = @(b (a <args>))@
composeE :: String -> PrimFunc
composeE _ [Procedure _ barity b, Procedure eargs aarity a] = 
  return $ Procedure eargs aarity ((apply procb . pure =<<) . a)
    where procb = Procedure False barity b
composeE n _ = invalidForm n

consE :: String -> PrimFunc
consE _ [a,b] = return $ Cell a b
consE n _     = invalidForm n

carE :: String -> PrimFunc
carE _ [Cell v _] = return v
carE n _          = invalidForm n

cdrE :: String -> PrimFunc
cdrE _ [Cell _ v] = return v
cdrE n _          = invalidForm n

printE :: String -> PrimFunc
printE n [x] = maybe (invalidForm n) (liftIO . putStr) (fromLispStr x) >> return Null
printE n _   = invalidForm n

isProcE :: String -> PrimFunc
isProcE _ [Procedure _ _ _] = return $ Bool True
isProcE _ [_]               = return $ Bool False
isProcE n _                 = invalidForm n

isNumberE :: String -> PrimFunc
isNumberE _ [Number _] = return $ Bool True
isNumberE _ [_]        = return $ Bool False
isNumberE n _          = invalidForm n

isStringE :: String -> PrimFunc
isStringE _ [xs] = return $ Bool $ isJust $ fromLispStr xs
isStringE n _    = invalidForm n

isAtomE :: String -> PrimFunc
isAtomE _ [Atom _] = return $ Bool True
isAtomE _ [_]      = return $ Bool False
isAtomE n _        = invalidForm n

isNullE :: String -> PrimFunc
isNullE _ [Null] = return $ Bool True
isNullE _ [_]    = return $ Bool False
isNullE n _      = invalidForm n

isListE :: String -> PrimFunc
isListE n [Cell _ xs] = isListE n [xs]
isListE _ [Null]      = return $ Bool True
isListE _ [_]         = return $ Bool False
isListE n _           = invalidForm n

isPairE :: String -> PrimFunc
isPairE _ [Cell _ _] = return $ Bool True
isPairE _ [_]        = return $ Bool False
isPairE n _          = invalidForm n

eqlE :: String -> PrimFunc
eqlE _ [a,b] = return $ Bool $ a == b
eqlE n _     = invalidForm n

readE :: String -> PrimFunc
readE n [x] = maybe (invalidForm n) f $ fromLispStr x
  where f = return . parseSilence . B.pack
readE n _ = invalidForm n

importE :: String -> PrimFunc
importE n [x] = maybe (invalidForm n) f $ fromLispStr x
  where f pth = (liftIO $ B.readFile pth) >>= evaluate . parseSilence
importE n _ = invalidForm n

toStrE :: String -> PrimFunc
toStrE _ [x] = return $ toLispStr x
toStrE n _ = invalidForm n

toAtomE :: String -> PrimFunc
toAtomE _ [x] = return $ Atom $ showExpr x
toAtomE n _ = invalidForm n

compE :: (Rational -> Rational -> Bool) -> String -> PrimFunc
compE p _ [Number a, Number b] = return $ Bool $ p a b
compE _ n _ = invalidForm n

mathBinaryE :: (Rational -> Rational -> Rational) -> String -> PrimFunc
mathBinaryE f _ [Number a, Number b] = return $ Number $ f a b
mathBinaryE _ n _ = invalidForm n

mathUnaryE :: (Rational -> Rational) -> String -> PrimFunc
mathUnaryE f _ [Number a] = return $ Number $ f a
mathUnaryE _ n _ = invalidForm n

wrapBinFrac :: RealFrac a => (a -> a -> a) -> Rational -> Rational -> Rational
wrapBinFrac f a b = toRational $ f (fromRational a) (fromRational b)

wrapFrac :: RealFrac a => (a -> a) -> Rational -> Rational
wrapFrac f a = toRational $ f (fromRational a)

numeratorE :: String -> PrimFunc
numeratorE _ [Number v] = return $ Number $ numerator v % 1
numeratorE n _ = invalidForm n

denominatorE :: String -> PrimFunc
denominatorE _ [Number v] = return $ Number $ denominator v % 1
denominatorE n _ = invalidForm n