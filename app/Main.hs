module Main where

import  Master

import System.Environment

main :: IO ()
main = do
  n:f:_ <- getArgs
  master (read n) (read f)