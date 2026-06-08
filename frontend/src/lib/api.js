import { env } from "../config/env";

export async function apiFetch(url, token, options = {}) {
  const headers = {
    ...(options.headers || {}),
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
  };

  const response = await fetch(url, {
    ...options,
    headers,
  });

  if (!response.ok) {
    const message = await response.text();
    throw new Error(message || `Request failed with status ${response.status}`);
  }

  if (response.status === 204) {
    return null;
  }

  return response.json();
}

export function authLogin(payload) {
  return apiFetch(`${env.backendHttpUrl}/auth/login`, null, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });
}

export function authRegister(payload) {
  return apiFetch(`${env.backendHttpUrl}/auth/register`, null, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });
}

export function fetchMe(token) {
  return apiFetch(`${env.backendHttpUrl}/auth/me`, token);
}

export function fetchDevices(token) {
  return apiFetch(`${env.backendHttpUrl}/devices`, token);
}

export function registerDevice(token, deviceId) {
  return apiFetch(`${env.backendHttpUrl}/devices`, token, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ deviceId }),
  });
}

export function fetchLatest(deviceId) {
  return apiFetch(`${env.backendHttpUrl}/latest/${deviceId}`);
}

export function postGeofenceFull(token, payload) {
  return apiFetch(`${env.backendHttpUrl}/geofence/update`, token, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });
}

export function fetchGeofenceState(token) {
  return apiFetch(`${env.backendHttpUrl}/geofence/state`, token);
}

export function postGeofenceMode(token, mode) {
  return apiFetch(`${env.backendHttpUrl}/geofence/mode`, token, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ mode }),
  });
}

export function postGeofenceCenter(token, lat, lng) {
  return apiFetch(`${env.backendHttpUrl}/geofence/center`, token, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ lat, lng }),
  });
}

export function postGeofenceRadius(token, radius_m) {
  return apiFetch(`${env.backendHttpUrl}/geofence/radius`, token, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ radius_m }),
  });
}

export function postGeofencePath(token, path) {
  return apiFetch(`${env.backendHttpUrl}/geofence/path`, token, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ path }),
  });
}


// Statistics APIs
export function fetchStatistics(deviceId, start = null, end = null) {
  const params = new URLSearchParams();
  if (start !== null) params.append("start", start);
  if (end !== null) params.append("end", end);
  const queryString = params.toString();
  const url = queryString ? `${env.backendHttpUrl}/stats/${deviceId}?${queryString}` : `${env.backendHttpUrl}/stats/${deviceId}`;
  return apiFetch(url);
}

export function fetchAggregatedStats(deviceId, start = null, end = null, interval = "day") {
  const params = new URLSearchParams();
  if (start !== null) params.append("start", start);
  if (end !== null) params.append("end", end);
  params.append("interval", interval);
  const queryString = params.toString();
  const url = `${env.backendHttpUrl}/stats/${deviceId}/aggregated?${queryString}`;
  return apiFetch(url);
}

export function fetchHeatmapData(deviceId, start = null, end = null, bucketSize = 0.0005) {
  const params = new URLSearchParams();
  if (start !== null) params.append("start", start);
  if (end !== null) params.append("end", end);
  params.append("bucket_size", bucketSize);
  const queryString = params.toString();
  const url = `${env.backendHttpUrl}/stats/${deviceId}/heatmap?${queryString}`;
  return apiFetch(url);
}
