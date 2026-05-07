import type { WgConfig } from '../model/WgConfig';
import { parseWireGuardConfig, buildWgConfigFromParsed } from '../common/Utils';
import { validateBase64Key, validateEndpoint } from '../common/Validators';
import { promptAction } from '@kit.ArkUI';

export interface ParseResult {
  success: boolean;
  config?: WgConfig;
  error?: string;
}

export class ConfigParser {
  static parseFromText(text: string, name?: string): ParseResult {
    const parsed = parseWireGuardConfig(text);
    if (!parsed) {
      return { success: false, error: '未识别到有效的 WireGuard 配置' };
    }

    if (!parsed.privateKey || parsed.privateKey.length === 0) {
      return { success: false, error: '配置缺少本机私钥' };
    }

    if (!validateBase64Key(parsed.privateKey)) {
      return { success: false, error: '密钥格式不正确' };
    }

    if (!parsed.peerPublicKey || parsed.peerPublicKey.length === 0) {
      return { success: false, error: '配置缺少服务器公钥' };
    }

    if (!validateBase64Key(parsed.peerPublicKey)) {
      return { success: false, error: '密钥格式不正确' };
    }

    if (!validateEndpoint(parsed.endpoint)) {
      return { success: false, error: '服务器地址或端口格式不正确' };
    }

    if (!parsed.allowedIPs || parsed.allowedIPs.trim().length === 0) {
      return { success: false, error: '未配置路由范围，连接后可能无法访问目标网络' };
    }

    if (name && name.length > 0) {
      parsed.name = name;
    }

    const config = buildWgConfigFromParsed(parsed);
    return { success: true, config };
  }

  static parseFromClipboard(): Promise<ParseResult> {
    return new Promise((resolve) => {
      resolve({ success: false, error: 'Clipboard access not implemented' });
    });
  }

  static showParseError(message: string | Resource): void {
    let msg: string;
    if (typeof message === 'string') {
      msg = message;
    } else {
      msg = getContext().resourceManager.getStringSync(message.id);
    }
    promptAction.showToast({ message: msg, duration: 3000 });
  }
}
