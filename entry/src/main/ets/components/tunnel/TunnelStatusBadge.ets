import { StatusBadge } from '../common/StatusBadge';
import type { TunnelStatusType } from '../../model/WgConfig';

@Component
export struct TunnelStatusBadge {
  @Prop status: TunnelStatusType = 'disconnected';

  build() {
    StatusBadge({ status: this.status })
  }
}
