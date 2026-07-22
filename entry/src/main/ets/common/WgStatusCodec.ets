import type { WgStatusPayload, WgTerminalState } from '../model/WgConfig';

interface RawWgStatusPayload {
  connected?: boolean;
  handshakeAgeSec?: number;
  rxBytes?: number;
  txBytes?: number;
  state?: string;
}

function isValidCounter(value: number | undefined): boolean {
  return value !== undefined && Number.isSafeInteger(value) && value >= 0;
}

function isValidHandshakeAge(value: number | undefined): boolean {
  return value !== undefined && Number.isSafeInteger(value) && value >= -1;
}

export function decodeWgStatusPayload(body: string): WgStatusPayload | null {
  if (body.length === 0) {
    return null;
  }

  let raw: RawWgStatusPayload;
  try {
    raw = JSON.parse(body) as RawWgStatusPayload;
  } catch (err) {
    return null;
  }

  if (raw === null || typeof raw !== 'object' || typeof raw.connected !== 'boolean' ||
    !isValidHandshakeAge(raw.handshakeAgeSec) ||
    !isValidCounter(raw.rxBytes) || !isValidCounter(raw.txBytes)) {
    return null;
  }

  if (raw.state !== undefined && raw.state !== 'disconnected' && raw.state !== 'failed') {
    return null;
  }
  if (raw.connected && raw.state !== undefined) {
    return null;
  }

  const payload: WgStatusPayload = {
    connected: raw.connected,
    handshakeAgeSec: raw.handshakeAgeSec as number,
    rxBytes: raw.rxBytes as number,
    txBytes: raw.txBytes as number
  };
  if (raw.state !== undefined) {
    payload.state = raw.state as WgTerminalState;
  }
  return payload;
}
