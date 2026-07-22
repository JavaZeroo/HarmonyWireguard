import abilityTest from './Ability.test'
import configTest from './Config.test'
import vpnRoutePlanTest from './VpnRoutePlan.test'
import logServiceTest from './LogService.test'
import diagnosticsTest from './Diagnostics.test'

export default function testsuite() {
  abilityTest()
  configTest()
  vpnRoutePlanTest()
  logServiceTest()
  diagnosticsTest()
}
