{-# LANGUAGE TemplateHaskell #-}

module Master where

import Messages
import Proposer (propose)

import Control.Monad (replicateM, forM_, forM)
import Control.Distributed.Process
import Control.Distributed.Process.Closure (mkClosure, remotable)
import Control.Distributed.Process.Node
import Network.Transport.TCP (createTransport, defaultTCPParameters)
import System.Random
import Data.Array.IO


-- | Randomly shuffle a list
shuffle :: [a] -> IO [a]
shuffle xs = do
        ar <- newArray n xs
        forM [1..n] $ \i -> do
            j <- randomRIO (i,n)
            vi <- readArray ar i
            vj <- readArray ar j
            writeArray ar j vi
            return vj
  where
    n = length xs
    newArray :: Int -> [a] -> IO (IOArray Int a)
    newArray n = newListArray (1, n)

serveExecuted :: Executed -> Process ()
serveExecuted m = do
    say $ "[Master] : \tReceived " ++ show m
    return ()

proposeClosure :: (Delay, Command) -> Process ()
proposeClosure (delay, cmd) = propose delay cmd

remotable ['proposeClosure]

masterRemoteTable :: RemoteTable
masterRemoteTable = Master.__remoteTable initRemoteTable

master :: Int -> Int -> IO ()
master n f = do
    Right t     <- createTransport "127.0.0.1" "10501" defaultTCPParameters
    Right tProp <- createTransport "127.0.0.1" "10503" defaultTCPParameters

    masterNode    <- newLocalNode     t   initRemoteTable
    proposersNode <- newLocalNode tProp masterRemoteTable

    let proposersNodeId = localNodeId proposersNode

    runProcess masterNode $ do
        masterPid <- getSelfPid

        -- Spawn proposers on their node
        let delay = 2 * second
        proposers <- forM (zip (repeat delay) [1..n]) $
            spawn proposersNodeId . $( mkClosure 'proposeClosure )

        shuffledProposers <- liftIO $ shuffle proposers
        let kings = take (f+1) shuffledProposers
        -- Send pids of all nodes to every one.
        forM_ proposers $ flip send (Info proposers n f masterPid kings)

        cmds <- replicateM n $ receiveWait [ match serveExecuted ]
        say "[Master] : \tFinished."
        if all (\ cmd -> cmd == head cmds) cmds
            then say "[Master] : \tSuccess! All executed commands were the same."
            else say "[Master] : \tERROR! Not all the commands were the same."