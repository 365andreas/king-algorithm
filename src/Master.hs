{-# LANGUAGE TemplateHaskell #-}

module Master where

import Messages
import Proposer (propose)

import Control.Monad (replicateM_, forM_, forM)
import Control.Distributed.Process
import Control.Distributed.Process.Closure (mkClosure, remotable)
import Control.Distributed.Process.Node
import Network.Transport.TCP (createTransport, defaultTCPParameters)


serveExecuted :: Executed -> Process ()
serveExecuted (Executed _) = return ()

proposeClosure :: (Delay, Phase, Command) -> Process ()
proposeClosure (delay, p, cmd) = propose delay p cmd

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
        proposers <- forM (zip3 (repeat delay) (repeat 1::[Phase]) [1..n]) $
            spawn proposersNodeId . $( mkClosure 'proposeClosure )

        -- Send pids of all nodes to every one.
        forM_ proposers $ flip send (Info proposers n f masterPid)

        replicateM_ n $ receiveWait [ match serveExecuted ]