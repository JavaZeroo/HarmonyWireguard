declare module 'libentry.so' {
  export interface WgConfigParams {
    privateKey: string;
    peerPublicKey: string;
    presharedKey?: string;
    endpointIp: string;
    endpointPort: number;
    keepalive?: number;
  }

  export function startVpn(tunFd: number, socketFd: number, config?: WgConfigParams): number;
  export function stopVpn(): number;
  export function udpConnect(ip: string, port: number): number;
}
