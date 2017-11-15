module Main where

import  Master

import System.Environment

main :: IO ()
main = do
  a:p:_ <- getArgs
  master (read a) (read p)