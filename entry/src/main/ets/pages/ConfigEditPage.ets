import { configManager } from '../service/ConfigManager';
import type { WgConfig } from '../model/WgConfig';
import { DEFAULT_CONFIG } from '../common/Constants';
import { SPACING, RADIUS, TYPOGRAPHY, getString } from '../common/DesignSystem';
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

@Component
export struct ConfigEditPage {
  @Consume('pageStack') pageStack: NavPathStack;
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

  private deleteDialogController: CustomDialogController | null = null;

  aboutToAppear(): void {
    // navParam 有值(来自预览页的 WgConfig)则编辑它，否则新建
    const p = this.navParam;
    if (p !== null) {
      const cfg = p as WgConfig;
      if (typeof cfg.privateKey === 'string') {
        this.config = cfg;
        if (!this.config.id) {
          this.config.id = Date.now().toString();
        }
        return;
      }
    }
    this.config.id = Date.now().toString();
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
    }

    if (this.config.dns && !validateDns(this.config.dns)) {
      errs.dns = getString($r('app.string.error_invalid_dns'));
    }

    if (this.config.mtu !== 0 && !validateMtu(this.config.mtu)) {
      errs.mtu = getString($r('app.string.error_invalid_mtu'));
    }

    if (!this.config.peerPublicKey || !validateBase64Key(this.config.peerPublicKey)) {
      errs.peerPublicKey = getString($r('app.string.error_invalid_key'));
    }

    if (!this.config.endpoint || !validateEndpoint(this.config.endpoint)) {
      errs.endpoint = getString($r('app.string.error_invalid_endpoint'));
    }

    if (!this.config.allowedIPs || this.config.allowedIPs.trim().length === 0) {
      errs.allowedIPs = getString($r('app.string.error_empty_allowed_ips'));
    }

    this.errors = errs;
    return Object.keys(errs).length === 0;
  }

  saveConfig(): void {
    if (!this.validate()) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: getString($r('app.string.error_fix_form')), duration: 2000 });
      } catch {}
      return;
    }

    if (!this.config.id) {
      this.config.id = Date.now().toString();
    }
    configManager.saveConfig(this.config);
    this.pageStack.pop();
  }

  deleteConfig(): void {
    if (this.config.id) {
      configManager.deleteConfig(this.config.id);
      this.pageStack.pop();
    }
  }

  private showDeleteDialog(): void {
    this.deleteDialogController = new CustomDialogController({
      builder: SecureConfirmDialog({
        title: getString($r('app.string.dialog_delete_config_title')),
        message: getString($r('app.string.dialog_delete_config_message')),
        confirmText: getString($r('app.string.button_delete')),
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
            this.pageStack.pop();
          })

        Text(this.config.id ? getString($r('app.string.page_config_edit')) : getString($r('app.string.page_config_new')))
          .fontSize(TYPOGRAPHY.title_sm.size)
          .fontWeight(TYPOGRAPHY.title_sm.weight)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Text(getString($r('app.string.button_save')))
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
                '',
                InputType.Number
              )

              SecureKeyField({
                label: getString($r('app.string.field_preshared_key')),
                hasValue: this.config.presharedKey.length > 0,
                value: this.config.presharedKey,
                onReplace: (val) => this.config.presharedKey = val
              })
            }
            .width('100%')
          }

          SectionCard({ title: getString($r('app.string.section_advanced')) }) {
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
            Button(getString($r('app.string.button_delete')))
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
}
