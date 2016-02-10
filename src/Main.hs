{-# LANGUAGE OverloadedStrings #-}

import Felony.Lisp
import Felony.Repl
import Felony.Parser
import System.Environment
import Control.Monad

main :: IO ()
main = getArgs >>= procArgs

-- TODO: Optparse-Applicative

procArgs :: [String] -> IO ()
procArgs [] = procArgs ["-r"]
procArgs ["-r"] = Felony.Repl.terminalRepl "𝝺 "
procArgs ["-ep", code] = evalProgram code >>= print
procArgs ["-e", code] = void $ evalProgram code
procArgs ["-f", fp] = readFile fp >>= \c -> procArgs ["-e", c]
procArgs ["-fp", fp] = readFile fp >>= \c -> procArgs ["-ep", c]
procArgs _ = (putStrLn "Invalid arguments") >> printHelp

printHelp :: IO ()
printHelp = do
  putStrLn "This is the help message... Kinda sucks, right?"
  
evalProgram :: String -> IO Expression
evalProgram = evalExpressions . parseFelony