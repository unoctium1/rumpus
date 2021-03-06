module Verylogue where
import Rumpus

--majorScale = [0,2,4,5,7,9,11,12]
majorScale = [0..12]
pianoKeySize = V3 0.01 0.2 0.3

start :: Start
start = do
    setSynthPatch "Verylogue.pd"

    forM_ majorScale $ \n -> do
        let note = fromIntegral $ n + 60
        sendSynth "piano-key" (List [note, 0])
    rootEntityID <- ask
    forM_ (zip [0..] majorScale) $ \(i, note) -> do

        let x        = (1/12) * fromIntegral i - 0.27
            keyPos   = V3 x 0.4 0
        keyID <- spawnEntity $
            makePianoKey rootEntityID i note
        attachEntity keyID (position keyPos)

makePianoKey parentID i noteDegree = do
    let note = fromIntegral $ noteDegree + 60
        hue      = fromIntegral i / fromIntegral (length majorScale)
        colorOn  = colorHSL hue 0.8 0.8
        colorOff = colorHSL hue 0.8 0.4
    myColor          ==> colorOff
    myParent         ==> parentID
    myShape          ==> Cube
    myBody           ==> Detector
    mySize           ==> pianoKeySize
    myCollisionBegan ==> \_ _ -> do
        myColor ==> colorOn
        sendEntitySynth parentID "piano-key" (List [note, 1])
    myCollisionEnded    ==> \_ -> do
        myColor ==> colorOff
        sendEntitySynth parentID "piano-key" (List [note, 0])
