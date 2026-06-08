import { useEffect, useRef, useState } from "react";

export function useTrackingSocket(url) {
  const [latestMessage, setLatestMessage] = useState(null);
  const [status, setStatus] = useState("disconnected");
  const reconnectTimerRef = useRef(null);
  const reconnectAttemptRef = useRef(0);
  const MAX_BACKOFF_MS = 30000;

  const getBackoffDelay = () => {
    const attempt = reconnectAttemptRef.current;
    const delay = Math.min(2000 * Math.pow(2, attempt), MAX_BACKOFF_MS);
    return delay;
  };

  useEffect(() => {
    if (!url) {
      setStatus("disconnected");
      return undefined;
    }
    let socket;
    let shouldReconnect = true;
    reconnectAttemptRef.current = 0;

    const connect = () => {
      setStatus("connecting");
      socket = new WebSocket(url);

      socket.onopen = () => {
        setStatus("connected");
        reconnectAttemptRef.current = 0;
      };

      socket.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          setLatestMessage(data);
        } catch {
          // Ignore malformed payloads from server.
        }
      };

      socket.onclose = (event) => {
        setStatus("disconnected");
        if (shouldReconnect) {
          const delay = getBackoffDelay();
          reconnectAttemptRef.current += 1;
          reconnectTimerRef.current = setTimeout(connect, delay);
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
