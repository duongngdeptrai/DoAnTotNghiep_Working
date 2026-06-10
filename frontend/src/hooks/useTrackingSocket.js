import { useEffect, useRef, useState } from "react";
import { fetchGeofenceState, fetchLatest } from "../lib/api";

export function useTrackingSocket(url, trackingDeviceIds = []) {
  const [latestMessage, setLatestMessage] = useState(null);
  const [status, setStatus] = useState("disconnected");
  const reconnectTimerRef = useRef(null);
  const reconnectAttemptRef = useRef(0);
  const socketRef = useRef(null);
  const wsFailedRef = useRef(false);
  const pollTimerRef = useRef(null);
  const MAX_BACKOFF_MS = 30000;

  const getBackoffDelay = () => {
    const attempt = reconnectAttemptRef.current;
    return Math.min(2000 * Math.pow(2, attempt), MAX_BACKOFF_MS);
  };

  const emitLocationUpdate = (deviceId, lat, lng) => {
    setLatestMessage({
      type: "location_update",
      deviceId,
      lat,
      lng,
      timestamp: Math.floor(Date.now() / 1000),
    });
  };

  const emitGeofenceStateUpdate = (state) => {
    setLatestMessage({
      type: "geofence_state_update",
      ...state,
    });
  };

  const pollDevices = async () => {
    const ids = trackingDeviceIds;
    if (ids.length === 0) return;

    try {
      const results = await Promise.allSettled(
        ids.map((deviceId) => fetchLatest(deviceId)),
      );

      results.forEach((result, index) => {
        if (result.status === "fulfilled" && result.value) {
          const data = result.value;
          console.log("[poll raw]", ids[index], data);
          emitLocationUpdate(ids[index], data.lat, data.lng);
        }
      });
    } catch {
      // ignore polling errors
    }
  };

  const pollGeofenceState = async () => {
    try {
      const state = await fetchGeofenceState();
      if (state) {
        emitGeofenceStateUpdate(state);
      }
    } catch {
      // ignore polling errors
    }
  };

  const startPolling = () => {
    setStatus("polling");
    pollDevices();
    pollGeofenceState();
    pollTimerRef.current = setInterval(() => {
      pollDevices();
      pollGeofenceState();
    }, 3000);
  };

  const stopPolling = () => {
    if (pollTimerRef.current) {
      clearInterval(pollTimerRef.current);
      pollTimerRef.current = null;
    }
  };

  useEffect(() => {
    if (!url) {
      setStatus("disconnected");
      return undefined;
    }

    wsFailedRef.current = false;
    reconnectAttemptRef.current = 0;
    let shouldReconnect = true;

    const connect = () => {
      setStatus("connecting");
      const socket = new WebSocket(url);
      socketRef.current = socket;

      socket.onopen = () => {
        setStatus("connected");
        reconnectAttemptRef.current = 0;
        wsFailedRef.current = false;
        stopPolling();
      };

      socket.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          console.log("[ws raw]", data);
          setLatestMessage(data);
        } catch {
          // Ignore malformed payloads from server.
        }
      };

      socket.onclose = () => {
        socketRef.current = null;
        if (!wsFailedRef.current) {
          setStatus("disconnected");
          if (shouldReconnect) {
            const delay = getBackoffDelay();
            reconnectAttemptRef.current += 1;
            reconnectTimerRef.current = setTimeout(() => {
              if (shouldReconnect) connect();
            }, delay);
          }
        }
      };

      socket.onerror = () => {
        wsFailedRef.current = true;
        stopPolling();
        socket.close();
        startPolling();
      };
    };

    connect();

    return () => {
      shouldReconnect = false;
      wsFailedRef.current = true;
      if (reconnectTimerRef.current) {
        clearTimeout(reconnectTimerRef.current);
      }
      if (socketRef.current) {
        socketRef.current.close();
        socketRef.current = null;
      }
      stopPolling();
    };
  }, [url]);

  useEffect(() => {
    stopPolling();
    if (wsFailedRef.current && trackingDeviceIds.length > 0) {
      startPolling();
    }
    return stopPolling;
  }, [trackingDeviceIds]);

  return { latestMessage, status };
}
