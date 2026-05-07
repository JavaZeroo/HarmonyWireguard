import type { WgConfig } from '../model/WgConfig';
import { parseWireGuardConfig, buildWgConfigFromParsed } from '../common/Utils';
import { validateBase64Key, validateEndpoint } from '../common/Validators';

export interface ParseResult {
  success: boolean;
  config?: WgConfig;
  error?: string | Resource;
}

export class ConfigParser {
  static parseFromText(text: string, name?: string): ParseResult {
    const parsed = parseWireGuardConfig(text);
    if (!parsed) {
      return { success: false, error: $r('app.string.error_parse_config') };
    }

    if (!parsed.privateKey || parsed.privateKey.length === 0) {
      return { success: false, error: $r('app.string.error_missing_private_key') };
    }

    if (!validateBase64Key(parsed.privateKey)) {
      return { success: false, error: $r('app.string.error_invalid_key') };
    }

    if (!parsed.peerPublicKey || parsed.peerPublicKey.length === 0) {
      return { success: false, error: $r('app.string.error_missing_public_key') };
    }

    if (!validateBase64Key(parsed.peerPublicKey)) {
      return { success: false, error: $r('app.string.error_invalid_key') };
    }

    if (!validateEndpoint(parsed.endpoint)) {
      return { success: false, error: $r('app.string.error_invalid_endpoint') };
    }

    if (!parsed.allowedIPs || parsed.allowedIPs.trim().length === 0) {
      return { success: false, error: $r('app.string.error_empty_allowed_ips') };
    }

    if (name && name.length > 0) {
      parsed.name = name;
    }

    const config = buildWgConfigFromParsed(parsed);
    return { success: true, config };
  }

  static parseFromClipboard(): Promise<ParseResult> {
    return new Promise((resolve) => {
      resolve({ success: false, error: $r('app.string.toast_clipboard_not_impl') });
    });
  }

  static resolveErrorMessage(message: string | Resource): string {
    if (typeof message === 'string') {
      return message;
    }
    try {
      return getContext().resourceManager.getStringSync(message.id);
    } catch {
      return 'Unknown error';
    }
  }
}
