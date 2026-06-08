import { useEffect, useRef, useState } from "react";

async function postJson(url, body) {
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const message = await response.text();
    throw new Error(message || `Request failed with status ${response.status}`);
  }

  return response.json();
}

export function useGeofenceSharing(backendHttpUrl, enabled, onStateUpdate) {
  const [sharingStatus, setSharingStatus] = useState("idle");
  const [sharingError, setSharingError] = useState(null);
  const lastSentAtRef = useRef(0);
  const inFlightRef = useRef(false);

  useEffect(() => {
    if (!enabled) {
      setSharingStatus("idle");
      setSharingError(null);
      return undefined;
    }

    if (!navigator.geolocation) {
      setSharingStatus("unsupported");
      setSharingError("Trinh duyet hien tai khong ho tro geolocation.");
      return undefined;
    }

    setSharingStatus("starting");
    setSharingError(null);

    const syncCenter = async (lat, lng) => {
      const now = Date.now();
      if (inFlightRef.current || now - lastSentAtRef.current < 2000) {
        return;
      }

      inFlightRef.current = true;
      lastSentAtRef.current = now;

      try {
        const state = await postJson(`${backendHttpUrl}/geofence/center`, { lat, lng });
        onStateUpdate?.(state);
        setSharingStatus("sharing");
      } catch (error) {
        setSharingStatus("error");
        setSharingError(error instanceof Error ? error.message : "Khong the gui vi tri len backend.");
      } finally {
        inFlightRef.current = false;
      }
    };

    const watchId = navigator.geolocation.watchPosition(
      (position) => {
        const { latitude, longitude } = position.coords;
        void syncCenter(latitude, longitude);
      },
      (error) => {
        setSharingStatus("error");
        setSharingError(error.message || "Khong lay duoc vi tri hien tai.");
      },
      {
        enableHighAccuracy: true,
        maximumAge: 1000,
        timeout: 10000,
      },
    );

    return () => {
      navigator.geolocation.clearWatch(watchId);
    };
  }, [backendHttpUrl, enabled, onStateUpdate]);

  return { sharingStatus, sharingError };
}
