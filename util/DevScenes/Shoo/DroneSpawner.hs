{-# LANGUAGE FlexibleContexts #-}
module DroneSpawner where
import Rumpus

numDrones = 30

start :: Start
start = do
    removeChildren
    parentID <- ask
    forM [0..numDrones] $ \ i -> do
        childID <- spawnEntity $ do
            myParent ==> parentID
            myShape ==> Sphere
            myBody ==> Animated
            mySize ==> 0.2
            myMass ==> 0.1
            let h = (fromIntegral $ (i * 27) `mod` 37) / 37
            myColor ==> colorHSL h 0.9 0.8
            myUpdate ==> do
                now <- getNow
                let iF = fromIntegral i
                    rate = 0.05
                    t = rate * iF * now
                    x = 1 + 0.3 * iF * cos t
                    y = 1 + iF * 0.4
                    z = 1 + 0.3 * iF * sin t
                setPose (identity & translation .~ V3 x y z)
            myCollisionBegan ==> \_ _ -> do
                myColor ==> colorHSL 1 0.5 0.5

        return ()
    return Nothing
