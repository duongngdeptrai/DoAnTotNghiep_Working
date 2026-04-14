import { useEffect, useRef, useState } from "react";

export function useTrackingSocket(url) {
  const [latestMessage, setLatestMessage] = useState(null);
  const [status, setStatus] = useState("disconnected");
  const reconnectTimerRef = useRef(null);

  useEffect(() => {
    let socket;
    let shouldReconnect = true;

    const connect = () => {
      setStatus("connecting");
      socket = new WebSocket(url);

      socket.onopen = () => {
        setStatus("connected");
      };

      socket.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          setLatestMessage(data);
        } catch {
          // Ignore malformed payloads from server.
        }
      };

      socket.onclose = () => {
        setStatus("disconnected");
        if (shouldReconnect) {
          reconnectTimerRef.current = setTimeout(connect, 2000);
        }
      };

      socket.onerror = () => {
        socket.close();
      };
    };

    connect();

    return () => {
      shouldReconnect = false;
      if (reconnectTimerRef.current) {
        clearTimeout(reconnectTimerRef.current);
      }
      if (socket) {
        socket.close();
      }
    };
  }, [url]);

  return { latestMessage, status };
}
