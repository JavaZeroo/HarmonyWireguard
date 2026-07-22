import { configManager } from '../service/ConfigManager';
import type { TunnelBehavior, WgConfig } from '../model/WgConfig';
import { DEFAULT_CONFIG, DEFAULT_TUNNEL_BEHAVIOR } from '../common/Constants';
import { SPACING, RADIUS, TYPOGRAPHY, getString } from '../common/DesignSystem';
import { SectionCard } from '../components/common/SectionCard';
import { SecureKeyField } from '../components/config/SecureKeyField';
import { KeyField } from '../components/config/KeyField';
import { EndpointInput } from '../components/config/EndpointInput';
import { RouteModeSelector } from '../components/config/RouteModeSelector';
import { PageHeader } from '../components/app/PageHeader';
import { DialogHelper } from '../common/DialogHelper';
import { validateBase64Key, validateEndpoint, validateCidr, validateDns, validateMtu } from '../common/Validators';
import { buildVpnRoutePlan } from '../common/VpnRoutePlan';
import { parseEndpoint } from '../common/Utils';

interface FormErrors {
  name?: string;
  privateKey?: string;
  address?: string;
  dns?: string;
  mtu?: string;
  peerPublicKey?: string;
  presharedKey?: string;
  endpoint?: string;
  allowedIPs?: string;
  keepalive?: string;
}

@Component
export struct ConfigEditPage {
  pageStack: NavPathStack = new NavPathStack();
  @Prop navParam: Object | null = null;
  @State config: WgConfig = {
    id: '',
    name: '',
    privateKey: '',
    address: DEFAULT_CONFIG.ADDRESS,
    dns: DEFAULT_CONFIG.DNS,
    mtu: 0,
    peerPublicKey: '',
    presharedKey: '',
    allowedIPs: DEFAULT_CONFIG.ALLOWED_IPS,
    endpoint: '',
    persistentKeepalive: 0
  };

  @State errors: FormErrors = {};
  @State autoConnect: boolean = false;
  @State reconnectOnNetworkChange: boolean = false;
  @State blockIpv6Leak: boolean = false;
  @State allowLanAccess: boolean = false;
  @State isExistingConfig: boolean = false;
  @State appeared: boolean = false;

  aboutToAppear(): void {
    const p = this.navParam;
    if (p !== null) {
      const cfg = p as WgConfig;
      if (typeof cfg.privateKey === 'string') {
        // Navigation parameters may still be owned by the list/preview page. Edit an isolated copy so that
        // backing out without saving never mutates the source object.
        this.config = this.copyConfig(cfg);
        this.isExistingConfig = this.config.id.length > 0 &&
          configManager.getConfigById(this.config.id) !== undefined;
        if (!this.config.id) {
          this.config.id = Date.now().toString();
        }
        this.loadBehavior(this.config.behavior);
        return;
      }
    }
    this.isExistingConfig = false;
    this.config.id = Date.now().toString();
    this.loadBehavior(undefined);
  }

  private copyConfig(source: WgConfig): WgConfig {
    const copied: WgConfig = {
      id: source.id,
      name: source.name,
      privateKey: source.privateKey,
      address: source.address,
      dns: source.dns,
      mtu: source.mtu,
      peerPublicKey: source.peerPublicKey,
      presharedKey: source.presharedKey,
      allowedIPs: source.allowedIPs,
      endpoint: source.endpoint,
      persistentKeepalive: source.persistentKeepalive
    };
    if (source.behavior !== undefined) {
      copied.behavior = this.copyBehavior(source.behavior);
    }
    return copied;
  }

  private copyBehavior(source: TunnelBehavior): TunnelBehavior {
    return {
      autoConnect: source.autoConnect,
      reconnectOnNetworkChange: source.reconnectOnNetworkChange,
      allowLanAccess: source.allowLanAccess,
      blockIpv6Leak: source.blockIpv6Leak
    };
  }

  private loadBehavior(source: TunnelBehavior | undefined): void {
    const behavior = source ?? DEFAULT_TUNNEL_BEHAVIOR;
    this.autoConnect = behavior.autoConnect;
    this.reconnectOnNetworkChange = behavior.reconnectOnNetworkChange;
    this.allowLanAccess = behavior.allowLanAccess;
    this.blockIpv6Leak = behavior.blockIpv6Leak;
  }

  private currentBehavior(): TunnelBehavior {
    return {
      autoConnect: this.autoConnect,
      reconnectOnNetworkChange: this.reconnectOnNetworkChange,
      allowLanAccess: this.allowLanAccess,
      blockIpv6Leak: this.blockIpv6Leak
    };
  }

  private validate(): boolean {
    const errs: FormErrors = {};

    if (!this.config.name || this.config.name.trim().length === 0) {
      errs.name = getString($r('app.string.error_required'));
    }

    if (!this.config.privateKey || !validateBase64Key(this.config.privateKey)) {
      errs.privateKey = getString($r('app.string.error_invalid_key'));
    }

    if (!this.config.address || !validateCidr(this.config.address)) {
      errs.address = getString($r('app.string.error_invalid_cidr'));
    } else if (this.config.address.includes(':')) {
      errs.address = getString($r('app.string.error_ipv6_address_unsupported'));
    }

    if (this.config.dns && !validateDns(this.config.dns)) {
      errs.dns = getString($r('app.string.error_invalid_dns'));
    } else if (this.config.dns.includes(':')) {
      errs.dns = getString($r('app.string.error_ipv6_dns_unsupported'));
    }

    if (this.config.mtu !== 0 && !validateMtu(this.config.mtu)) {
      errs.mtu = getString($r('app.string.error_invalid_mtu'));
    }

    if (!this.config.peerPublicKey || !validateBase64Key(this.config.peerPublicKey)) {
      errs.peerPublicKey = getString($r('app.string.error_invalid_key'));
    }
    if (this.config.presharedKey.length > 0 && !validateBase64Key(this.config.presharedKey)) {
      errs.presharedKey = getString($r('app.string.error_invalid_key'));
    }

    if (!this.config.endpoint || !validateEndpoint(this.config.endpoint)) {
      errs.endpoint = getString($r('app.string.error_invalid_endpoint'));
    } else if (parseEndpoint(this.config.endpoint)?.isIPv6 === true) {
      errs.endpoint = getString($r('app.string.error_ipv6_endpoint_unsupported'));
    }

    if (!this.config.allowedIPs || this.config.allowedIPs.trim().length === 0) {
      errs.allowedIPs = getString($r('app.string.error_empty_allowed_ips'));
    } else {
      const routePlan = buildVpnRoutePlan(this.config.allowedIPs);
      const hasInvalidRoute = routePlan.ignoredRoutes.some(route => route.reason === 'invalid_cidr');
      if (hasInvalidRoute) {
        errs.allowedIPs = getString($r('app.string.error_invalid_cidr'));
      } else if (routePlan.acceptedIpv4Routes.length === 0) {
        errs.allowedIPs = getString($r('app.string.error_ipv4_route_required'));
      }
    }
    if (this.config.persistentKeepalive < 0 || this.config.persistentKeepalive > 65535) {
      errs.keepalive = getString($r('app.string.error_invalid_keepalive'));
    }

    this.errors = errs;
    return errs.name === undefined &&
      errs.privateKey === undefined &&
      errs.address === undefined &&
      errs.dns === undefined &&
      errs.mtu === undefined &&
      errs.peerPublicKey === undefined &&
      errs.presharedKey === undefined &&
      errs.endpoint === undefined &&
      errs.allowedIPs === undefined &&
      errs.keepalive === undefined;
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message, duration: 2000 });
    } catch {}
  }

  saveConfig(): void {
    if (!this.validate()) {
      this.showToast(getString($r('app.string.error_fix_form')));
      return;
    }

    if (!this.config.id) {
      this.config.id = Date.now().toString();
    }
    this.config.behavior = this.currentBehavior();
    if (!configManager.saveConfig(this.config)) {
      this.showToast(getString($r('app.string.error_save_config')));
      return;
    }
    this.showToast(getString($r('app.string.toast_saved')));
    this.pageStack.pop();
  }

  deleteConfig(): void {
    if (this.isExistingConfig && this.config.id) {
      if (configManager.getActiveConfigId() === this.config.id) {
        this.showToast(getString($r('app.string.error_disconnect_before_delete')));
        return;
      }
      if (!configManager.deleteConfig(this.config.id)) {
        this.showToast(getString($r('app.string.error_delete_config')));
        return;
      }
      this.pageStack.pop();
    }
  }

  private showDeleteDialog(): void {
    DialogHelper.showConfirm(this.getUIContext(), {
      title: getString($r('app.string.dialog_delete_config_title')),
      message: getString($r('app.string.dialog_delete_config_message')),
      confirmText: getString($r('app.string.button_delete')),
      secure: true,
      onConfirm: () => {
        this.deleteConfig();
      }
    });
  }

  private getError(key: string): string {
    if (key === 'name') return this.errors.name || '';
    if (key === 'privateKey') return this.errors.privateKey || '';
    if (key === 'address') return this.errors.address || '';
    if (key === 'dns') return this.errors.dns || '';
    if (key === 'mtu') return this.errors.mtu || '';
    if (key === 'peerPublicKey') return this.errors.peerPublicKey || '';
    if (key === 'presharedKey') return this.errors.presharedKey || '';
    if (key === 'endpoint') return this.errors.endpoint || '';
    if (key === 'allowedIPs') return this.errors.allowedIPs || '';
    if (key === 'keepalive') return this.errors.keepalive || '';
    return '';
  }

  @Builder
  FormInput(
    label: string,
    value: string,
    placeholder: string,
    onChange: (val: string) => void,
    errorKey: string,
    inputType: InputType
  ) {
    Column() {
      Text(label)
        .fontSize(TYPOGRAPHY.label.size)
        .fontWeight(TYPOGRAPHY.label.weight)
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: SPACING.xs })
        .width('100%')

      TextInput({ placeholder: placeholder, text: value })
        .fontSize(TYPOGRAPHY.body_md.size)
        .width('100%')
        .height(48)
        .backgroundColor($r('app.color.surface_subtle'))
        .border({
          width: 1,
          color: this.getError(errorKey).length > 0
            ? $r('app.color.danger') : $r('app.color.divider'),
          radius: RADIUS.md
        })
        .type(inputType)
        .onChange(onChange)

      if (this.getError(errorKey).length > 0) {
        Text(this.getError(errorKey))
          .fontSize(12)
          .fontColor($r('app.color.danger'))
          .width('100%')
          .margin({ top: 4 })
      }
    }
    .width('100%')
    .margin({ bottom: SPACING.md })
  }

  @Builder
  FormInputOptional(label: string, value: string, placeholder: string, onChange: (val: string) => void) {
    Column() {
      Text(label)
        .fontSize(TYPOGRAPHY.label.size)
        .fontWeight(TYPOGRAPHY.label.weight)
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: SPACING.xs })
        .width('100%')

      TextInput({ placeholder: placeholder, text: value })
        .fontSize(TYPOGRAPHY.body_md.size)
        .width('100%')
        .height(48)
        .backgroundColor($r('app.color.surface_subtle'))
        .border({ width: 1, color: $r('app.color.divider'), radius: RADIUS.md })
        .onChange(onChange)
    }
    .width('100%')
    .margin({ bottom: SPACING.md })
  }

  build() {
    Column() {
      PageHeader({
        pageStack: this.pageStack,
        title: this.isExistingConfig
          ? getString($r('app.string.page_config_edit'))
          : getString($r('app.string.page_config_new')),
        actionText: getString($r('app.string.button_save')),
        onAction: () => {
          this.saveConfig();
        }
      })

      Scroll() {
        Column() {
        Column({ space: SPACING.md }) {
          SectionCard({ title: getString($r('app.string.section_display')) }) {
            Column() {
              this.FormInputOptional(
                getString($r('app.string.field_name')),
                this.config.name,
                getString($r('app.string.placeholder_name')),
                (v) => this.config.name = v
              )
              if (this.getError('name').length > 0) {
                Text(this.getError('name'))
                  .fontSize(12)
                  .fontColor($r('app.color.danger'))
                  .width('100%')
                  .margin({ bottom: SPACING.sm })
              }
            }
            .width('100%')
          }

          SectionCard({ title: getString($r('app.string.section_interface')) }) {
            Column() {
              this.FormInputOptional(
                getString($r('app.string.field_address')),
                this.config.address,
                getString($r('app.string.placeholder_address')),
                (v) => this.config.address = v
              )
              if (this.getError('address').length > 0) {
                Text(this.getError('address'))
                  .fontSize(12)
                  .fontColor($r('app.color.danger'))
                  .width('100%')
                  .margin({ bottom: SPACING.sm })
              }

              SecureKeyField({
                label: getString($r('app.string.field_private_key')),
                hasValue: this.config.privateKey.length > 0,
                value: this.config.privateKey,
                onReplace: (val) => this.config.privateKey = val
              })

              if (this.getError('privateKey').length > 0) {
                Text(this.getError('privateKey'))
                  .fontSize(12)
                  .fontColor($r('app.color.danger'))
                  .width('100%')
                  .margin({ bottom: SPACING.sm })
              }

              this.FormInputOptional(
                getString($r('app.string.field_dns')),
                this.config.dns,
                getString($r('app.string.placeholder_dns')),
                (v) => this.config.dns = v
              )
              if (this.getError('dns').length > 0) {
                Text(this.getError('dns'))
                  .fontSize(12)
                  .fontColor($r('app.color.danger'))
                  .width('100%')
                  .margin({ bottom: SPACING.sm })
              }

              this.FormInput(
                getString($r('app.string.field_mtu')),
                this.config.mtu > 0 ? String(this.config.mtu) : '',
                getString($r('app.string.placeholder_mtu')),
                (v) => this.config.mtu = v ? parseInt(v) : 0,
                'mtu',
                InputType.Number
              )
            }
            .width('100%')
          }

          SectionCard({ title: getString($r('app.string.section_peer')) }) {
            Column() {
              KeyField({
                label: getString($r('app.string.field_public_key')),
                value: this.config.peerPublicKey,
                placeholder: getString($r('app.string.placeholder_public_key')),
                onChange: (val) => this.config.peerPublicKey = val
              })

              if (this.getError('peerPublicKey').length > 0) {
                Text(this.getError('peerPublicKey'))
                  .fontSize(12)
                  .fontColor($r('app.color.danger'))
                  .width('100%')
                  .margin({ bottom: SPACING.sm })
              }

              EndpointInput({
                endpoint: this.config.endpoint,
                onChange: (val) => this.config.endpoint = val
              })

              if (this.getError('endpoint').length > 0) {
                Text(this.getError('endpoint'))
                  .fontSize(12)
                  .fontColor($r('app.color.danger'))
                  .width('100%')
                  .margin({ bottom: SPACING.sm })
              }

              RouteModeSelector({
                allowedIPs: this.config.allowedIPs,
                onChange: (val) => this.config.allowedIPs = val
              })

              if (this.getError('allowedIPs').length > 0) {
                Text(this.getError('allowedIPs'))
                  .fontSize(12)
                  .fontColor($r('app.color.danger'))
                  .width('100%')
                  .margin({ bottom: SPACING.sm })
              }

              this.FormInput(
                getString($r('app.string.field_keepalive')),
                this.config.persistentKeepalive > 0 ? String(this.config.persistentKeepalive) : '',
                getString($r('app.string.placeholder_keepalive')),
                (v) => this.config.persistentKeepalive = v ? parseInt(v) : 0,
                this.getError('keepalive'),
                InputType.Number
              )

              SecureKeyField({
                label: getString($r('app.string.field_preshared_key')),
                hasValue: this.config.presharedKey.length > 0,
                value: this.config.presharedKey,
                onReplace: (val) => this.config.presharedKey = val
              })

              if (this.getError('presharedKey').length > 0) {
                Text(this.getError('presharedKey'))
                  .fontSize(TYPOGRAPHY.caption.size)
                  .fontColor($r('app.color.danger'))
                  .width('100%')
              }
            }
            .width('100%')
          }

          if (this.isExistingConfig) {
            Button(getString($r('app.string.button_delete')))
              .fontSize(TYPOGRAPHY.body_md.size)
              .fontColor($r('app.color.danger'))
              .backgroundColor($r('app.color.danger_bg'))
              .width('100%')
              .height(48)
              .borderRadius(RADIUS.md)
              .margin({ top: SPACING.lg, bottom: SPACING.xl })
              .hoverEffect(HoverEffect.Highlight)
              .stateStyles({
                pressed: {
                  .opacity(0.82)
                }
              })
              .onClick(() => {
                this.showDeleteDialog();
              })
          }
        }
        .constraintSize({ maxWidth: 640 })
        .width('100%')
        .padding({ left: SPACING.md, right: SPACING.md, top: SPACING.md, bottom: SPACING.xl })
        .opacity(this.appeared ? 1 : 0)
        .translate({ y: this.appeared ? 0 : 12 })
        .renderGroup(true)
        .onAppear(() => {
          this.getUIContext().animateTo({ duration: 350, curve: Curve.EaseOut }, () => {
            this.appeared = true;
          });
        })
        }
        .width('100%')
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
    // 页面间转场：入栈自右侧滑入 + 淡入，出栈反向，取代默认纯淡入淡出
    .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ x: 40 }))
      .animation({ duration: 300, curve: Curve.Friction }))
  }
}
