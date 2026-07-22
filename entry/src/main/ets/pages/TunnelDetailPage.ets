import { getString } from '../common/DesignSystem';
import { PageHeader } from '../components/app/PageHeader';
import { TunnelDetailPanel } from '../components/tunnel/TunnelDetailPanel';

@Component
export struct TunnelDetailPage {
  pageStack: NavPathStack = new NavPathStack();
  @Prop navConfigId: string = '';

  build() {
    Column() {
      PageHeader({
        title: getString($r('app.string.page_tunnel_detail')),
        pageStack: this.pageStack
      })

      TunnelDetailPanel({ configId: this.navConfigId })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }
}
