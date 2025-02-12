'use client'
import { useState, useEffect } from "react";
import { useReactMediaRecorder } from "react-media-recorder";

const VoiceRecording = () => {

    


    

   

    const handleStartRecording = () => {
        setRecordingDuration(0);
        startRecording();
    };

    const handleStopRecording = () => {
        stopRecording();
    };

    

    


    


    return (
        <>
            {/* <h2>Voice Recording</h2>
            <p>Status: {status}</p>
            <p>Duration: {formatDuration(recordingDuration)}</p>
            <button onClick={handleStartRecording} disabled={status === "recording"}>
                Start Recording
            </button>
            <button onClick={handleStopRecording} disabled={status !== "recording"}>
                Stop Recording
            </button>
            <button onClick={handleCancelRecording} disabled={status !== "recording"}>
                Cancel Recording
            </button>
            {mediaBlobUrl && (
                <audio src={mediaBlobUrl} controls />
            )} */}

            <button onClick={handleStartRecording}>
                <MdKeyboardVoice size={24} color="#595B6C" />
            </button>
        </>
    )
}

export default VoiceRecording