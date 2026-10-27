# Security

This beta is designed for trusted local networks. It uses authenticated, unencrypted HTTP. Do not port-forward the companion or use it on untrusted Wi-Fi. Pairing links and QR codes are credentials; never include them in issues or screenshots.

Report vulnerabilities using **Security → Report a vulnerability** on this repository. Do not disclose tokens, private screenshots, or exploit details in a public issue. Only the latest beta is maintained.

The source tests cover authentication, host/origin validation, path rejection, PNG validation, size limits, original preservation, and idempotent saves. These checks do not provide network encryption. TLS and discoverable/recoverable pairing remain future work.
