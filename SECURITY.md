# Security policy

## Release status

HarmonyWireguard v1.0.0 is a technology preview. It has not received an independent cryptographic or security audit and
must not be treated as a production security boundary.

Known hardening work includes protocol-state concurrency, replay protection, key rotation and expiry, failure handling
for random-number generation, secure-at-rest configuration storage, and broader malformed-packet testing.

## Reporting a vulnerability

Contact the repository owner through GitHub before publishing exploit details. Do not include real private keys,
preshared keys, endpoints or complete WireGuard configurations in an issue, log or screenshot.

Please include a sanitized reproduction, affected commit or version, device/API version, and expected impact. The
maintainer will acknowledge the report and coordinate disclosure after a fix is available.

## Supported versions

Only the newest published technology-preview version receives security fixes.
