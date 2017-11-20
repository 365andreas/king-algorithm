module Proposer where

import Messages

import Control.Concurrent (threadDelay)
import Control.Distributed.Process (
    match, send, liftIO, getSelfPid, spawnLocal,
    receiveWait, Process, ProcessId, expect, say
    )
import Control.Monad (when)
import Data.List (delete, find, sortOn, reverse)
import Data.Map (fromListWith, toList)
import Prelude hiding (all)


frequency :: (Ord a) => [a] -> [(a, Int)]
frequency xs = reverse $ sortOn snd $ toList (fromListWith (+) [(x, 1) | x <- xs])

timer :: Delay -> ProcessId -> Process ()
timer delay pid = do
    liftIO $ threadDelay delay
    send pid Timeout

-- | Proposer's main.
propose :: Delay -> Command -> Process ()
propose delay cmd = do
    self <- getSelfPid
    Info all n f master kings <- expect :: Process Info
    let others = delete self all
    executedMsg <- rounding others self 1 kings n f delay cmd
    say $ "\tSending " ++ show executedMsg
    send master executedMsg

rounding :: [ProcessId] -> ProcessId -> Phase -> [ProcessId]
    -> Int -> Int -> Int -> Command  -> Process Executed
rounding others self phase (king:restKings) n f interval cmd = do
    say $ " \t-- Phase " ++ show phase ++ " --"
    -- Round 1
    vals <- roundOne others self interval cmd
    let values = Value cmd:vals
    -- Round 2
    let (Value y , t):_ = frequency values
    when (t >= (n-f)) (broadcast others $ Propose y)
    _ <- spawnLocal $ timer interval self
    proposes <- waitRoundTwo []
    let (cmd', fProposes) = case frequency proposes of
            []                     -> (cmd, [])
            l@((Propose z, t'):_)  ->
                (if t' > f then z else cmd, l)
    say $ "\tEnd of Round 2. Proposes received: " ++ show proposes
    -- Round 3
    nextCmd <- roundThree (self==king) others cmd' fProposes n f interval self
    say ("\tEnd of Round 3. x=" ++ show nextCmd)
    if phase < f+1 then
        rounding others self (phase+1) restKings n f interval nextCmd
    else
        return $ Executed nextCmd

type IsKing = Bool

roundThree :: IsKing -> [ProcessId] -> Command -> [(Propose, Int)]
    -> Int -> Int -> Int -> ProcessId -> Process Command
roundThree True others x _ _ _ interval _ = do
    broadcast others $ King x
    liftIO $ threadDelay interval
    return x
roundThree False _ _ [] _ _ interval self = do
    _ <- spawnLocal $ timer interval self
    Just (King w) <- waitKing Nothing  -- since it is on local net it must receive a king
    return w
roundThree False _ cmd' fProposes n f interval self = do
    _ <- spawnLocal $ timer interval self
    Just (King w) <- waitKing Nothing  -- since it is on local net it must receive a king
    case find (flip ((==).fst) (Propose cmd')) fProposes of
        Just (_, times) -> do
            let nextCmd = if times < n-f then w else cmd'
            return nextCmd
        Nothing         -> error "This should NOT happen!!"


waitKing :: Maybe King -> Process (Maybe King)
waitKing m =
    receiveWait [ match receiveKing, match (receiveTimeout m)]

roundOne :: [ProcessId] -> ProcessId -> Delay -> Command -> Process [Value]
roundOne others self interval cmd = do
    broadcast others $ Value cmd
    _ <- spawnLocal $ timer interval self
    msgs <- waitRoundOne []
    say $ "\tEnd of Round 1. Messages received: " ++ show msgs
    return msgs

waitRoundOne :: [Value] -> Process [Value]
waitRoundOne msgs =
    receiveWait [ match (receiveValue msgs), match (receiveTimeout msgs)]

receiveValue :: [Value] -> Value -> Process [Value]
receiveValue list m = do
    say $ "\tReceived : " ++ show m
    waitRoundOne $ m:list

receiveKing :: King -> Process (Maybe King)
receiveKing m = do
    say $ "\tReceived : " ++ show m
    waitKing $ Just m

waitRoundTwo :: [Propose] -> Process [Propose]
waitRoundTwo msgs =
    receiveWait [ match (receivePropose msgs), match (receiveTimeout msgs)]

receivePropose :: [Propose] -> Propose -> Process [Propose]
receivePropose list m = do
    say $ "\tReceived : " ++ show m
    waitRoundTwo $ m:list

receiveTimeout :: a -> Timeout -> Process a
receiveTimeout a _ = return a