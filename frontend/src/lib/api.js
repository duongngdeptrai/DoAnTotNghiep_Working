import { env } from "../config/env";

export async function apiFetch(url, options = {}) {
  const response = await fetch(url, options);

  if (!response.ok) {
    if (response.status === 404 && options.allow404) {
      return null;
    }
    const message = await response.text();
    throw new Error(message || `Request failed with status ${response.status}`);
  }

  if (response.status === 204) {
    return null;
  }

  return response.json();
}

export function authLogin(payload) {
  return apiFetch(`${env.backendHttpUrl}/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
}

export function authRegister(payload) {
  return apiFetch(`${env.backendHttpUrl}/auth/register`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
}

export function fetchDevices() {
  return apiFetch(`${env.backendHttpUrl}/devices`);
}

export function registerDevice(deviceId) {
  return apiFetch(`${env.backendHttpUrl}/devices`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ deviceId }),
  });
}

export function shareDevice(deviceId, email) {
  return apiFetch(`${env.backendHttpUrl}/devices/${deviceId}/share`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email }),
  });
}

export function unshareDevice(deviceId, email) {
  return apiFetch(
    `${env.backendHttpUrl}/devices/${deviceId}/share/${encodeURIComponent(email)}`,
    { method: "DELETE" },
  );
}

export function fetchDeviceConfig(deviceId) {
  return apiFetch(`${env.backendHttpUrl}/devices/${deviceId}/config`);
}

export function postDeviceConfig(deviceId, parentEmail, alertEnabled) {
  return apiFetch(`${env.backendHttpUrl}/devices/${deviceId}/config`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ parentEmail, alertEnabled }),
  });
}

export function deleteDeviceConfig(deviceId) {
  return apiFetch(`${env.backendHttpUrl}/devices/${deviceId}/config`, {
    method: "DELETE",
  });
}

export function fetchLatest(deviceId) {
  return apiFetch(`${env.backendHttpUrl}/latest/${deviceId}`, { allow404: true });
}

export function postGeofenceFull(payload) {
  return apiFetch(`${env.backendHttpUrl}/geofence/update`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
}

export function fetchGeofenceState() {
  return apiFetch(`${env.backendHttpUrl}/geofence/state`);
}

export function postGeofenceMode(mode) {
  return apiFetch(`${env.backendHttpUrl}/geofence/mode`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ mode }),
  });
}

export function postGeofenceCenter(lat, lng) {
  return apiFetch(`${env.backendHttpUrl}/geofence/center`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ lat, lng }),
  });
}

export function postGeofenceRadius(radius_m) {
  return apiFetch(`${env.backendHttpUrl}/geofence/radius`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ radius_m }),
  });
}

export function postGeofencePath(path) {
  return apiFetch(`${env.backendHttpUrl}/geofence/path`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ path }),
  });
}

// Statistics APIs
export function fetchStatistics(deviceId, start = null, end = null) {
  const params = new URLSearchParams();
  if (start !== null) params.append("start", start);
  if (end !== null) params.append("end", end);
  const queryString = params.toString();
  const url = queryString
    ? `${env.backendHttpUrl}/stats/${deviceId}?${queryString}`
    : `${env.backendHttpUrl}/stats/${deviceId}`;
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
