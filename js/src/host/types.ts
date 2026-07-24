// The kind of host a HostInfo describes.
export type HostType = 'hostname' | 'ipv4' | 'ipv6';

// Structured data parsed out of a host by Host.parse.
export interface HostInfo {
  host: string;
  type: HostType;
  port: number | null;
  hasPort: boolean;
}
