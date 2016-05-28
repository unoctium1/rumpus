module Rumpus.Systems.SceneLoader where
import PreludeExtra hiding (delete, catch)
import Rumpus.Systems.Drag
import Rumpus.Systems.Animation
import Rumpus.Systems.Clock
import Rumpus.Systems.Shared
import Rumpus.Systems.Controls
import Rumpus.Systems.Scene
import Rumpus.Systems.PlayPause
import Rumpus.Systems.Physics
import Rumpus.Systems.Text
--import Rumpus.Systems.Scene
--import Rumpus.Systems.SceneWatcher
import Rumpus.Types
import Control.Exception

import RumpusLib

data SceneLoaderSystem = SceneLoaderSystem
    { _sclSceneIcons        :: ![EntityID]
    }
makeLenses ''SceneLoaderSystem
defineSystemKey ''SceneLoaderSystem


initSceneLoaderSystem :: MonadState ECS m => m ()
initSceneLoaderSystem = do
    registerSystem sysSceneLoader (SceneLoaderSystem mempty)


startSceneLoaderSystem :: (MonadIO m, MonadState ECS m) => m ()
startSceneLoaderSystem = do
    -- Profiling doesn't support hot code load, so we can't load scenes
    -- (we use TestScene instead in Main)
    --unless isBeingProfiled $ do
    showSceneLoader

listScenes :: (MonadState ECS m, MonadIO m) => m [FilePath]
listScenes = do
    rumpusRoot <- getRumpusRootFolder

    scenePaths <- listDirectories rumpusRoot
    return scenePaths

showSceneLoader :: (MonadState ECS m, MonadIO m) => m ()
showSceneLoader = do
    setPlayerPosition 0

    scenePaths <- listScenes
    let scenePathsWithNewScene = Nothing : map Just scenePaths
        positions = goldenSectionSpiralPoints (length scenePathsWithNewScene)
        positionsAndCodePaths = zip positions scenePathsWithNewScene

    libraryEntities <- forM positionsAndCodePaths $ \(position, maybeCodePath) -> do
        addSceneLibraryItem position maybeCodePath

    decorations <- spawnEntity (myStart ==> makeLoaderDecorations)

    modifySystemState sysSceneLoader $
        sclSceneIcons .= decorations:libraryEntities

makeLoaderDecorations :: Start
makeLoaderDecorations = do

    -- Platform
    let roomCube = 4
        (roomW, _roomH, roomD) = (roomCube,roomCube,roomCube)
        wallD = 0.2

        roomOffset = -wallD/2
    spawnChild $ do
        myPose       ==> translateMatrix (V3 0 roomOffset 0)
        myShape      ==> Cube
        myProperties ==> [Floating, Ungrabbable, Teleportable]
        mySize       ==> V3 roomW wallD roomD
        myColor      ==> colorHSL 0.5 0.8 0.6
        myMass       ==> 0

    let n = 10
    forM (take 100 $ cycle "RUMPUSrumpus") $ \letter -> do
        pos <- V3 <$> randomRange (-n,n)
                  <*> randomRange (-n,n)
                  <*> randomRange (-n,n)

        let (V3 x y z) = pos
        unless (abs x < 4 && abs y < 4 && abs z < 4) $ do
            void . spawnChild $ do
                myPose ==> translateMatrix pos
                mySize ==> 0.2
                myText ==> [letter]
                myTextPose ==> translateMatrix (V3 0 1 0)
                myProperties ==> [Holographic]
                myShape ==> Cube
                myUpdate ==> do
                    now <- getNow
                    let n = (now + pos ^. _x + pos ^. _y) * 0.5
                    setSize (realToFrac (sin n))
                    setPose $ rotationAndPosition
                       (axisAngle pos n)
                       (pos & _x +~ sin n & _y +~ cos n)
                    setColor (colorHSL (x+(sin n * 0.3)) 0.5 0.5)

    return ()


hideSceneLoader :: (MonadState ECS m, MonadIO m) => m ()
hideSceneLoader = do
    iconIDs <- viewSystem sysSceneLoader sclSceneIcons
    forM_ iconIDs removeEntity

sceneLoaderAnimationInitialSize :: V3 GLfloat
sceneLoaderAnimationInitialSize = V3 0.01 0.01 0.01

sceneLoaderAnimationFinalSize :: V3 GLfloat
sceneLoaderAnimationFinalSize   = V3 0.3  0.3  0.3

sceneLoaderAnimationDuration :: Double
sceneLoaderAnimationDuration    = 0.3

listDirectories :: MonadIO m => FilePath -> m [FilePath]
listDirectories inPath = liftIO $
    filterM (doesDirectoryExist . (inPath </>)) =<< getDirectoryContentsSafe inPath

addSceneLibraryItem :: (MonadIO m, MonadState ECS m)
                    => V3 GLfloat -> Maybe FilePath -> m EntityID
addSceneLibraryItem spherePosition maybeScenePath = do
    newEntityID <- spawnEntity $ do
        myPose         ==> translateMatrix (spherePosition * 1 + V3 0 1.5 0)
        myShape        ==> Sphere
        mySize         ==> sceneLoaderAnimationInitialSize
        myProperties   ==> [Floating]
        myDragOverride ==> True
        myText         ==> maybe "New Scene" takeBaseName maybeScenePath
        myTextPose     ==> rotationAndPosition
                            (axisAngle (V3 1 0 0) (0))
                            (V3 0 (-1) 0)
                            !*! scaleMatrix 0.3
        myColor      ==> V4 0.1 0.1 0.1 1
        -- Make the new object pulse
        when (isNothing maybeScenePath) $ do
            myUpdate ==> do
                now <- getNow
                setColor (colorHSL now 0.3 0.8)
        myDragBegan ==> do
            rumpusRoot <- getRumpusRootFolder
            mScenePathToLoad <- case maybeScenePath of
                Just scenePath -> return (Just (rumpusRoot </> scenePath))
                Nothing -> do
                    -- FIXME two users could create a new scene at once and we don't handle this
                    scenePaths <- listScenes
                    let newSceneName = findNextNumberedName "MyScene" scenePaths
                        newScenePath = rumpusRoot </> newSceneName

                    -- Do nothing if we can't create the folder
                    createdSuccessfully <- createDirectorySafe newScenePath
                    if createdSuccessfully
                        then return (Just newScenePath)
                        else return Nothing
            forM_ mScenePathToLoad $ \scenePathToLoad -> do
                fadeToColor (V4 1 1 1 1) 1
                setDelayedAction 1 $ do
                    fadeToColor (V4 0 0 0 0) 1
                    setWorldPlaying False
                    hideSceneLoader
                    loadScene scenePathToLoad

    inEntity newEntityID $
        animateSizeTo sceneLoaderAnimationFinalSize 0.3
    return newEntityID

createDirectorySafe :: MonadIO m => FilePath -> m Bool
createDirectorySafe dirName = liftIO (do
    createDirectoryIfMissing True dirName
    return True
    `catch` (\e -> do
        putStrLn ("Error in getDirectoryContentsSafe: " ++ show (e :: IOException))
        return False))