{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE FlexibleContexts #-}
module Rumpus.Systems.Animation where
import PreludeExtra hiding (Key)
import Rumpus.Systems.Shared
import Rumpus.Systems.PlayPause
import Rumpus.Systems.Physics
import Rumpus.Systems.Controls
import Data.ECS.Vault

defineComponentKeyWithType "ColorAnimation" [t|Animation (V4 GLfloat)|]
defineComponentKeyWithType "SizeAnimation"  [t|Animation (V3 GLfloat)|]
-- defineComponentKeyWithType "PoseAnimation"  [t|Animation (Pose GLfloat)|]

initAnimationSystem :: (MonadIO m, MonadState ECS m) => m ()
initAnimationSystem = do
    registerComponent "ColorAnimation" myColorAnimation (newComponentInterface myColorAnimation)
    registerComponent "SizeAnimation"  mySizeAnimation  (newComponentInterface mySizeAnimation)
    -- registerComponent "PoseAnimation"  myPoseAnimation  (newComponentInterface myPoseAnimation)

tickAnimationSystem :: (MonadIO m, MonadState ECS m) => m ()
tickAnimationSystem = whenWorldPlaying $ do
    now <- realToFrac <$> getNow
    
    tickComponentAnimation now myColorAnimation setColor
    tickComponentAnimation now mySizeAnimation  setSize
    -- tickComponentAnimation now myPoseAnimation  myPose

tickComponentAnimation :: MonadState ECS m 
                       => DiffTime
                       -> Key (EntityMap (Animation struct))
                       -> (struct -> ReaderT EntityID m a)
                       -> m ()
tickComponentAnimation now animComponentKey setter = 
    forEntitiesWithComponent animComponentKey $ 
        \(entityID, animation) -> runEntity entityID $ do
            let evaled = evalAnim now animation

            setter (evanResult evaled)
            when (evanRunning evaled == False) $ do
                removeComponent animComponentKey


animateSizeTo :: (MonadIO m, MonadState ECS m, MonadReader EntityID m) => V3 GLfloat -> DiffTime -> m ()
animateSizeTo newSize time = do
    currentSize <- getSize
    animation <- makeAnimation time currentSize newSize
    mySizeAnimation ==> animation
