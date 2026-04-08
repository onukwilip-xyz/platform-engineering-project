# cert-manager-config

Terraform module that configures cert-manager after it has been installed. Manages:

- A self-signed root CA key pair (`cluster-ca-key-pair` secret in the `cert-manager` namespace)
- `internal-ca` ClusterIssuer — issues certificates signed by the private root CA, for services inside the VPC
- `letsencrypt-public-ca` ClusterIssuer — issues publicly trusted certificates via ACME DNS-01 (Let's Encrypt + Cloud DNS)

---

## Trusting the Private CA

Services inside the cluster that receive a certificate from `internal-ca` are signed by a self-signed root CA that **no OS or browser trusts by default**. Devices that need to establish TLS connections to those services (e.g. VPN-connected engineers, internal tooling) must install the root CA certificate into their trust store.

### Step 1 — Export the CA certificate from the cluster

You need `kubectl` access and permission to read secrets in the `cert-manager` namespace (`container.secrets.get` IAM permission or a Kubernetes RBAC role with `get` on `secrets`).

```bash
kubectl get secret cluster-ca-key-pair \
  -n cert-manager \
  -o jsonpath='{.data.tls\.crt}' \
  | base64 --decode \
  > internal-ca.crt
```

Verify the certificate before distributing it:

```bash
openssl x509 -in internal-ca.crt -noout -subject -issuer -dates
```

> **Security note:** Only distribute `internal-ca.crt` (the public certificate). Never share `tls.key` (the private key) from the secret.

---

### Step 2 — Install the CA certificate into the trust store

#### macOS

```bash
# Add to the System keychain and trust it for all users
sudo security add-trusted-cert \
  -d \
  -r trustRoot \
  -k /Library/Keychains/System.keychain \
  internal-ca.crt
```

To verify it was added:

```bash
# Extract the CN — works with both legacy (CN=) and RFC 2253 (CN = ) subject formats
CERT_CN=$(openssl x509 -in internal-ca.crt -noout -subject -nameopt multiline \
  | grep -E '^\s*commonName' | sed 's/.*= //' | xargs)

security find-certificate -c "$CERT_CN" /Library/Keychains/System.keychain
```

To remove it later:

```bash
CERT_CN=$(openssl x509 -in internal-ca.crt -noout -subject -nameopt multiline \
  | grep -E '^\s*commonName' | sed 's/.*= //' | xargs)

sudo security delete-certificate -c "$CERT_CN" /Library/Keychains/System.keychain
```

> After installation, restart any open browsers (Chrome, Safari, Edge) for the change to take effect. Firefox maintains its own trust store — see the Firefox note below.

---

#### Windows

Open **PowerShell as Administrator**:

```powershell
# Import into the machine-wide Trusted Root Certification Authorities store
Import-Certificate `
  -FilePath ".\internal-ca.crt" `
  -CertStoreLocation Cert:\LocalMachine\Root
```

To verify it was added:

```powershell
Get-ChildItem Cert:\LocalMachine\Root | Where-Object {
  $_.Subject -like "*$(
    (New-Object Security.Cryptography.X509Certificates.X509Certificate2 ".\internal-ca.crt").GetNameInfo('SimpleName', $false)
  )*"
}
```

To remove it later:

```powershell
$thumbprint = (New-Object Security.Cryptography.X509Certificates.X509Certificate2 ".\internal-ca.crt").Thumbprint
Remove-Item "Cert:\LocalMachine\Root\$thumbprint"
```

Alternatively, using `certutil`:

```cmd
certutil -addstore Root internal-ca.crt
```

> After installation, restart any open browsers (Chrome, Edge) for the change to take effect.

---

#### Linux

The exact commands vary by distribution.

**Debian / Ubuntu:**

```bash
sudo cp internal-ca.crt /usr/local/share/ca-certificates/internal-ca.crt
sudo update-ca-certificates
```

**RHEL / Fedora / CentOS:**

```bash
sudo cp internal-ca.crt /etc/pki/ca-trust/source/anchors/internal-ca.crt
sudo update-ca-trust extract
```

**Arch Linux:**

```bash
sudo cp internal-ca.crt /etc/ca-certificates/trust-source/anchors/internal-ca.crt
sudo trust extract-compat
```

To verify the CA is trusted system-wide after installation:

```bash
# Replace <CN> with the CommonName from the cert (visible in the openssl output above)
openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt internal-ca.crt
```

> Browsers that use the system trust store (Chrome, Chromium) will pick up the change automatically. Firefox requires a separate step — see below.

---

#### Firefox (all platforms)

Firefox does not use the OS trust store by default. You must import the certificate through the browser UI:

1. Open Firefox → **Settings** → **Privacy & Security**
2. Scroll to **Certificates** → click **View Certificates**
3. Select the **Authorities** tab → click **Import**
4. Select `internal-ca.crt`
5. Check **Trust this CA to identify websites** → click **OK**

Alternatively, enable Firefox to use the OS trust store (Firefox 124+):

```
about:config → security.enterprise_roots.enabled → true
```

After setting that flag, the certificate you added to the OS store will be trusted automatically without a manual Firefox import.

---

### Rotating the CA

If the CA certificate is rotated (e.g. by running `terraform apply` after the `tls_self_signed_cert` expires or is tainted), you must:

1. Re-export the new `internal-ca.crt` using the kubectl command above
2. Replace the old certificate in each device's trust store using the install steps above
3. Existing certificates signed by the old CA will no longer be trusted — they must be reissued by annotating the relevant `Certificate` resources with `cert-manager.io/issuer-name`
