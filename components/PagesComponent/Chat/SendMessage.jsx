"use client";
import { sendMessageApi } from "@/utils/api";
import { useEffect, useState, useRef } from "react";
import { IoMdAttach, IoMdSend } from "react-icons/io";
import { FaMicrophone, FaRegStopCircle } from "react-icons/fa";
import { Loader2, X } from "lucide-react";
import { useReactMediaRecorder } from "react-media-recorder";
import { toast } from "sonner";
import { t } from "@/utils";
import CustomImage from "@/components/Common/CustomImage";

const SendMessage = ({ selectedChatDetails, setChatMessages }) => {
  const isAllowToChat =
    selectedChatDetails?.item?.status === "approved" ||
    selectedChatDetails?.item?.status === "featured";

  if (!isAllowToChat) {
    return (
      <div className="p-4 border-t text-center text-muted-foreground">
        {t("thisAd")} {selectedChatDetails?.item?.status}
      </div>
    );
  }

  const id = selectedChatDetails?.id;
  const [message, setMessage] = useState("");
  const [selectedFile, setSelectedFile] = useState(null);
  const [previewUrl, setPreviewUrl] = useState("");
  const [isSending, setIsSending] = useState(false);
  const fileInputRef = useRef(null);

  // Voice recording setup
  const { status, startRecording, stopRecording, mediaBlobUrl, error } =
    useReactMediaRecorder({
      audio: true,
      blobPropertyBag: { type: "audio/mpeg" },
    });

  const isRecording = status === "recording";
  const [recordingDuration, setRecordingDuration] = useState(0);

  // Format recording duration as mm:ss
  const formatDuration = (seconds) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, "0")}:${secs
      .toString()
      .padStart(2, "0")}`;
  };

  // Timer for recording
  useEffect(() => {
    let timer;
    if (isRecording) {
      timer = setInterval(() => {
        setRecordingDuration((prev) => prev + 1);
      }, 1000);
    } else {
      setRecordingDuration(0);
    }

    return () => clearInterval(timer);
  }, [isRecording]);

  useEffect(() => {
    return () => {
      if (previewUrl) {
        URL.revokeObjectURL(previewUrl);
      }
      stopRecording();
    };
  }, []);

  // Handle recorded audio
  useEffect(() => {
    if (mediaBlobUrl && status === "stopped") {
      handleRecordedAudio();
    }
  }, [mediaBlobUrl, status]);

  const handleRecordedAudio = async () => {
    try {
      const response = await fetch(mediaBlobUrl);
      const blob = await response.blob();
      const audioFile = new File([blob], "recording.mp3", {
        type: "audio/mpeg",
      });
      sendMessage(audioFile);
    } catch (err) {
      console.error("Error processing audio:", err);
      toast.error("Failed to process recording");
    }
  };

  const handleFileSelect = (e) => {
    const file = e.target.files[0];
    if (!file) return;

    // Check if file is an image
    const allowedTypes = ["image/jpeg", "image/png", "image/jpg"];

    if (!allowedTypes.includes(file.type)) {
      toast.error("Only image files (JPEG, PNG, JPG) are allowed");
      return;
    }

    // Create preview URL for image
    const fileUrl = URL.createObjectURL(file);
    setPreviewUrl(fileUrl);
    setSelectedFile(file);
  };

  const removeSelectedFile = () => {
    if (previewUrl) {
      URL.revokeObjectURL(previewUrl);
    }
    setSelectedFile(null);
    setPreviewUrl("");
    // Reset file input value to allow selecting the same file again
    if (fileInputRef.current) {
      fileInputRef.current.value = "";
    }
  };

  const sendMessage = async (audioFile = null) => {
    if ((!message.trim() && !selectedFile && !audioFile) || isSending) return;

    const params = {
      item_offer_id: id,
      message: message ? message : "",
      file: selectedFile ? selectedFile : "",
      audio: audioFile ? audioFile : "",
    };

    try {
      setIsSending(true);
      const response = await sendMessageApi.sendMessage(params);

      if (!response?.data?.error) {
        setChatMessages((prev) => [...prev, response.data.data]);
        setMessage("");
        removeSelectedFile();
      } else {
        toast.error(response?.data?.message || "Failed to send message");
      }
    } catch (error) {
      console.error(error);
      toast.error("Error sending message");
    } finally {
      setIsSending(false);
    }
  };

  const handleVoiceButtonClick = () => {
    if (isRecording) {
      stopRecording();
    } else {
      startRecording();
      if (error) {
        console.log(error);
        switch (error) {
          case "permission_denied":
            toast.error(t("microphoneAccessDenied"));
            break;
          case "no_specified_media_found":
            toast.error(t("noMicrophoneFound"));
            break;
          default:
            toast.error(t("somethingWentWrong"));
        }
      }
    }
  };

  return (
    <div className="flex flex-col">
      {/* File Preview */}
      {previewUrl && (
        <div className="px-4 pt-2 pb-1">
          <div className="relative w-32 h-32 border rounded-md overflow-hidden group">
            <CustomImage
              src={previewUrl}
              alt="File preview"
              fill
              className="object-contain"
            />
            <button
              onClick={removeSelectedFile}
              className="absolute top-1 right-1 bg-black/70 text-white p-1 rounded-full opacity-70 hover:opacity-100"
            >
              <X size={14} />
            </button>
          </div>
        </div>
      )}

      {/* Input Area */}
      <div className="p-4 border-t flex items-center gap-2">
        {!isRecording && (
          <>
            <input
              type="file"
              ref={fileInputRef}
              className="hidden"
              accept="image/jpeg,image/png,image/jpg"
              onChange={handleFileSelect}
            />
            <button
              onClick={() => fileInputRef.current.click()}
              aria-label="Attach file"
            >
              <IoMdAttach size={20} className="text-muted-foreground" />
            </button>
          </>
        )}

        {isRecording ? (
          <div className="flex-1 py-2 px-3 bg-red-50 text-red-500 rounded-md flex items-center justify-center font-medium">
            {t("recording")} {formatDuration(recordingDuration)}
          </div>
        ) : (
          <textarea
            type="text"
            placeholder="Message..."
            className="flex-1 outline-none border px-3 py-1 rounded-md"
            value={message}
            rows={2}
            onChange={(e) => setMessage(e.target.value)}
          />
        )}

        <button
          className="p-2 bg-primary text-white rounded-md"
          disabled={isSending}
          onClick={
            message.trim() || selectedFile
              ? () => sendMessage()
              : handleVoiceButtonClick
          }
        >
          {isSending ? (
            <Loader2 size={20} className="animate-spin" />
          ) : message.trim() || selectedFile ? (
            <IoMdSend size={20} className="rtl:scale-x-[-1]" />
          ) : isRecording ? (
            <FaRegStopCircle size={20} />
          ) : (
            <FaMicrophone size={20} />
          )}
        </button>
      </div>
    </div>
  );
};

export default SendMessage;
