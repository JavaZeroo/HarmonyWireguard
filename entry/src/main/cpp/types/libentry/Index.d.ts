export interface WgNativeConfig {
  privateKey: string;
  peerPublicKey: string;
  presharedKey: string;
  endpointIp: string;
  endpointPort: number;
  keepalive: number;
}

export const startVpn: (tunFd: number, socketFd: number, config: WgNativeConfig) => number;
export const stopVpn: () => number;
export const udpConnect: (ip: string, port: number) => number;
export const getStatus: () => string;
