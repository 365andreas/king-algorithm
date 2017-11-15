module Proposer where

import Messages

import Control.Concurrent (threadDelay)
import Control.Distributed.Process (
    match, send, liftIO, getSelfPid, spawnLocal,
    receiveWait, Process, ProcessId, expect, say
    )
-- import Control.Monad (forM_, replicateM, when)
import Data.List (delete)
import Prelude hiding (all)
-- import Data.Maybe (catMaybes)
-- import Data.Map (fromListWith, toList)
-- import System.Random (randomRIO)

-- randomList :: Int -> IO([Int])
-- randomList n = replicateM n $ randomRIO (1,6)

timer :: Delay -> ProcessId -> Process ()
timer delay pid = do
    liftIO $ threadDelay delay
    send pid Timeout

-- | Proposer's main.
propose :: Delay -> Phase -> Command -> Process ()
propose interval phase cmd = do

    self <- getSelfPid
    Info all n f master <- expect :: Process Info
    let others = delete self all
    roundOne others self n f interval cmd

roundOne :: [ProcessId] -> ProcessId -> Int -> Int -> Delay -> Command -> Process ()
roundOne others self n f interval cmd = do
    broadcast others $ Value cmd
    _ <- spawnLocal $ timer interval self
    msgs <- waitRoundOne []
    say $ "\tEnd of Round 1. Messages received: " ++ show msgs
    return ()

waitRoundOne :: [Value] -> Process [Value]
waitRoundOne msgs =
    receiveWait [ match (receiveValue msgs), match (receiveTimeout msgs)]

receiveValue :: [Value] -> Value -> Process [Value]
receiveValue list m = do
    say $ "\tReceived : " ++ show m
    waitRoundOne $ m:list

receiveTimeout :: [Value] -> Timeout -> Process [Value]
receiveTimeout list _ = return list

-- let a = length serverPids
-- answers <- replicateM a (receiveWait second [ match receivePromise ])
-- let (listOk, listNotOk) = splitOkNotOk t' answers

-- if length listOk < a `div` 2 + 1 then
--     case listNotOk of
--         [] -> propose serverPids cmd t'
--         _  -> let PromiseNotOk t'' _ = maximum listNotOk in
--             do
--                 proposerSay $ "Received 'PromiseNotOk'. Changing t: " ++
--                     show t' ++ " -> " ++ show (t''+1)
--                 propose serverPids cmd t''
-- else do
--     -- Phase 2
--     let (PromiseOk tStore c _ _) = maximum listOk
--     let cmd' = if tStore > 0 then c else cmd
--     let pidsListOk = map (\(PromiseOk _ _ pid _) -> pid) listOk
--     forM_ pidsListOk $ flip send $ Propose t' cmd' self

--     ans <- replicateM a (receiveTimeout second [ match receiveProposal ])
--     if length (catProposalSuccess ans t') < a `div` 2 + 1 then
--         propose serverPids cmd t'
--     else
--         forM_ serverPids $ flip send $ Execute cmd'