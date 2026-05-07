import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { configManager } from '../service/ConfigManager';
import type { WgConfig } from '../model/WgConfig';
import { DEFAULT_CONFIG } from '../common/Constants';
import { SPACING, RADIUS, TYPOGRAPHY } from '../common/DesignSystem';
import { SectionCard } from '../components/common/SectionCard';
import { SecureKeyField } from '../components/config/SecureKeyField';
import { KeyField } from '../components/config/KeyField';
import { EndpointInput } from '../components/config/EndpointInput';
import { RouteModeSelector } from '../components/config/RouteModeSelector';
import { AdvancedSection } from '../components/config/AdvancedSection';
import { SecureConfirmDialog } from '../components/common/SecureConfirmDialog';
import { validateBase64Key, validateEndpoint, validateCidr, validateDns, validateMtu } from '../common/Validators';

interface FormErrors {
  name?: string;
  privateKey?: string;
  address?: string;
  dns?: string;
  mtu?: string;
  peerPublicKey?: string;
  endpoint?: string;
  allowedIPs?: string;
}

@Entry
@Component
struct ConfigEditPage {
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

  private deleteDialogController: CustomDialogController | null = null;

  aboutToAppear(): void {
    const params = router.getParams() as object;
    const id = (params as Record<string, string>)['id'];
    const cfg = (params as Record<string, WgConfig>)['config'];
    if (id) {
      const exist = configManager.getConfigById(id);
      if (exist) {
        this.config = exist;
      }
    } else if (cfg) {
      this.config = cfg;
    } else {
      this.config.id = Date.now().toString();
    }
  }

  private validate(): boolean {
    const errs: FormErrors = {};

    if (!this.config.name || this.config.name.trim().length === 0) {
      errs.name = getContext().resourceManager.getStringSync($r('app.string.error_required').id);
    }

    if (!this.config.privateKey || !validateBase64Key(this.config.privateKey)) {
      errs.privateKey = getContext().resourceManager.getStringSync($r('app.string.error_invalid_key').id);
    }

    if (!this.config.address || !validateCidr(this.config.address)) {
      errs.address = getContext().resourceManager.getStringSync($r('app.string.error_invalid_cidr').id);
    }

    if (this.config.dns && !validateDns(this.config.dns)) {
      errs.dns = getContext().resourceManager.getStringSync($r('app.string.error_invalid_dns').id);
    }

    if (this.config.mtu !== 0 && !validateMtu(this.config.mtu)) {
      errs.mtu = getContext().resourceManager.getStringSync($r('app.string.error_invalid_mtu').id);
    }

    if (!this.config.peerPublicKey || !validateBase64Key(this.config.peerPublicKey)) {
      errs.peerPublicKey = getContext().resourceManager.getStringSync($r('app.string.error_invalid_key').id);
    }

    if (!this.config.endpoint || !validateEndpoint(this.config.endpoint)) {
      errs.endpoint = getContext().resourceManager.getStringSync($r('app.string.error_invalid_endpoint').id);
    }

    if (!this.config.allowedIPs || this.config.allowedIPs.trim().length === 0) {
      errs.allowedIPs = getContext().resourceManager.getStringSync($r('app.string.error_empty_allowed_ips').id);
    }

    this.errors = errs;
    return errs.name === undefined && errs.privateKey === undefined && errs.address === undefined && errs.dns === undefined && errs.mtu === undefined && errs.peerPublicKey === undefined && errs.endpoint === undefined && errs.allowedIPs === undefined;
  }

  saveConfig(): void {
    if (!this.validate()) {
      promptAction.showToast({ message: '请修正表单错误', duration: 2000 });
      return;
    }

    if (!this.config.id) {
      this.config.id = Date.now().toString();
    }
    configManager.saveConfig(this.config);
    router.back();
  }

  deleteConfig(): void {
    if (this.config.id) {
      configManager.deleteConfig(this.config.id);
      router.back();
    }
  }

  private showDeleteDialog(): void {
    this.deleteDialogController = new CustomDialogController({
      builder: SecureConfirmDialog({
        title: getContext().resourceManager.getStringSync($r('app.string.dialog_delete_config_title').id),
        message: getContext().resourceManager.getStringSync($r('app.string.dialog_delete_config_message').id),
        confirmText: getContext().resourceManager.getStringSync($r('app.string.button_delete').id),
        onConfirm: () => {
          this.deleteConfig();
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center
    });
    this.deleteDialogController.open();
  }

  private getError(key: string): string {
    if (key === 'name') return this.errors.name || '';
    if (key === 'privateKey') return this.errors.privateKey || '';
    if (key === 'address') return this.errors.address || '';
    if (key === 'dns') return this.errors.dns || '';
    if (key === 'mtu') return this.errors.mtu || '';
    if (key === 'peerPublicKey') return this.errors.peerPublicKey || '';
    if (key === 'endpoint') return this.errors.endpoint || '';
    if (key === 'allowedIPs') return this.errors.allowedIPs || '';
    return '';
  }

  @Builder
  FormInput(label: string, value: string, placeholder: string, onChange: (val: string) => void, errorKey: string, inputType: InputType) {
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
        .height(44)
        .backgroundColor($r('app.color.surface_subtle'))
        .borderRadius(RADIUS.md)
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
        .height(44)
        .backgroundColor($r('app.color.surface_subtle'))
        .borderRadius(RADIUS.md)
        .onChange(onChange)
    }
    .width('100%')
    .margin({ bottom: SPACING.md })
  }

  build() {
    Column() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(24)
          .fontColor([$r('app.color.text_primary')])
          .onClick(() => {
            router.back();
          })

        Text(this.config.id ? getContext().resourceManager.getStringSync($r('app.string.page_config_edit').id) : '新建配置')
          .fontSize(TYPOGRAPHY.title_sm.size)
          .fontWeight(TYPOGRAPHY.title_sm.weight)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Text(getContext().resourceManager.getStringSync($r('app.string.button_save').id))
          .fontSize(TYPOGRAPHY.body_md.size)
          .fontColor($r('app.color.primary'))
          .onClick(() => {
            this.saveConfig();
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: SPACING.md, right: SPACING.md })
      .backgroundColor($r('app.color.surface'))

      Scroll() {
        Column({ space: SPACING.md }) {
          SectionCard({ title: getContext().resourceManager.getStringSync($r('app.string.section_display').id) }) {
            Column() {
              this.FormInputOptional(
                getContext().resourceManager.getStringSync($r('app.string.field_name').id),
                this.config.name,
                '例如: 公司内网',
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

          SectionCard({ title: getContext().resourceManager.getStringSync($r('app.string.section_interface').id) }) {
            Column() {
              this.FormInputOptional(
                getContext().resourceManager.getStringSync($r('app.string.field_address').id),
                this.config.address,
                '例如: 10.0.0.2/24',
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
                label: getContext().resourceManager.getStringSync($r('app.string.field_private_key').id),
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
                getContext().resourceManager.getStringSync($r('app.string.field_dns').id),
                this.config.dns,
                '例如: 8.8.8.8, 1.1.1.1',
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
                getContext().resourceManager.getStringSync($r('app.string.field_mtu').id),
                this.config.mtu > 0 ? String(this.config.mtu) : '',
                '自动',
                (v) => this.config.mtu = v ? parseInt(v) : 0,
                'mtu',
                InputType.Number
              )
            }
            .width('100%')
          }

          SectionCard({ title: getContext().resourceManager.getStringSync($r('app.string.section_peer').id) }) {
            Column() {
              KeyField({
                label: getContext().resourceManager.getStringSync($r('app.string.field_public_key').id),
                value: this.config.peerPublicKey,
                placeholder: '服务器公钥',
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
                getContext().resourceManager.getStringSync($r('app.string.field_keepalive').id),
                this.config.persistentKeepalive > 0 ? String(this.config.persistentKeepalive) : '',
                '秒，默认 25',
                (v) => this.config.persistentKeepalive = v ? parseInt(v) : 0,
                '',
                InputType.Number
              )

              SecureKeyField({
                label: getContext().resourceManager.getStringSync($r('app.string.field_preshared_key').id),
                hasValue: this.config.presharedKey.length > 0,
                value: this.config.presharedKey,
                onReplace: (val) => this.config.presharedKey = val
              })
            }
            .width('100%')
          }

          SectionCard({ title: getContext().resourceManager.getStringSync($r('app.string.section_advanced').id) }) {
            AdvancedSection({
              autoConnect: this.autoConnect,
              reconnectOnNetworkChange: this.reconnectOnNetworkChange,
              blockIpv6Leak: this.blockIpv6Leak,
              allowLanAccess: this.allowLanAccess,
              onAutoConnectChange: (val) => this.autoConnect = val,
              onReconnectChange: (val) => this.reconnectOnNetworkChange = val,
              onBlockIpv6Change: (val) => this.blockIpv6Leak = val,
              onAllowLanChange: (val) => this.allowLanAccess = val
            })
          }

          if (this.config.id) {
            Button(getContext().resourceManager.getStringSync($r('app.string.button_delete').id))
              .fontSize(TYPOGRAPHY.body_md.size)
              .fontColor($r('app.color.danger'))
              .backgroundColor($r('app.color.danger_bg'))
              .width('100%')
              .height(48)
              .borderRadius(RADIUS.md)
              .margin({ top: SPACING.lg, bottom: SPACING.xl })
              .onClick(() => {
                this.showDeleteDialog();
              })
          }
        }
        .width('100%')
        .padding({ left: SPACING.md, right: SPACING.md, top: SPACING.md, bottom: SPACING.xl })
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }

  pageTransition() {
    PageTransitionEnter({ duration: 250, curve: Curve.EaseOut })
      .slide(SlideEffect.Right)
      .opacity(0)
    PageTransitionExit({ duration: 200, curve: Curve.EaseIn })
      .opacity(1)
  }
}
