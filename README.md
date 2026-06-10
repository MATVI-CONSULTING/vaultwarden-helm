# vaultwarden-helm

Helm chart for self-hosted Vaultwarden deployment on Kubernetes, with Argon2 admin token, SMTP configuration, persistent storage, and Ingress support.

## Installation

```bash
helm install vaultwarden . -f values.yaml
```

With a custom values file:

```bash
helm install vaultwarden . -f my-values.yaml
```

## Configuration

Copy `values.yaml` and adjust the values for your target environment.

### Main parameters

| Parameter | Description | Default |
| --- | --- | --- |
| `image.repository` | Docker image | `vaultwarden/server` |
| `image.tag` | Image tag | `1.36.0` |
| `config.domain` | Public URL of the instance | `https://vaultwarden.example.com` |
| `config.signupsAllowed` | Allow new registrations | `false` |
| `secrets.adminToken` | Argon2 hash of the admin password | `""` |
| `secrets.smtpPassword` | SMTP password | `""` |
| `smtp.host` | SMTP server | `""` |
| `smtp.port` | SMTP port | `587` |
| `smtp.security` | SMTP security (`starttls` / `force_tls` / `off`) | `starttls` |
| `persistence.enabled` | Enable persistent storage | `true` |
| `persistence.size` | PVC size | `1Gi` |
| `ingress.enabled` | Enable Ingress | `true` |
| `ingress.host` | Ingress hostname | `vaultwarden.example.com` |
| `ingress.tls.enabled` | Enable TLS | `false` |

### Admin token (Argon2)

The Argon2 hash must be generated **locally before deploying to the cluster**. Docker is required on your local machine — this step does not run on the cluster.

Run the following command, which will interactively prompt you for a password:

```bash
docker run --rm -it vaultwarden/server /vaultwarden hash --preset owasp
```

```text
Password:           ← type your chosen admin password (hidden)
Confirm Password:   ← confirm it

ADMIN_TOKEN='$argon2id$v=19$m=19456,t=2,p=1$...'
```

Copy the generated `ADMIN_TOKEN` value and paste it into `values.yaml`:

```yaml
secrets:
  adminToken: "$argon2id$v=19$m=19456,t=2,p=1$..."
```

> At `/admin`, enter the **password** you typed during generation — not the hash. The hash is only stored server-side for verification.

### Ingress with TLS (cert-manager)

```yaml
ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  host: "vaultwarden.example.com"
  tls:
    enabled: true
    secretName: "vaultwarden-tls"
```

## Kubernetes resources

| Resource | Description |
| --- | --- |
| `Deployment` | Vaultwarden pod |
| `Service` | ClusterIP on port 80 |
| `Ingress` | HTTP/HTTPS exposure (if enabled) |
| `PersistentVolumeClaim` | Data storage at `/data` (if enabled) |
| `ConfigMap` | Non-sensitive configuration variables |
| `Secret` | `ADMIN_TOKEN` and `SMTP_PASSWORD` |

## Useful commands

```bash
# Validate the chart without deploying
helm template vaultwarden . -f values.yaml

# Upgrade after modifying values.yaml
helm upgrade vaultwarden . -f values.yaml

# Uninstall
helm uninstall vaultwarden

# Check deployment status
kubectl get pods -l app.kubernetes.io/name=vaultwarden
kubectl logs -l app.kubernetes.io/name=vaultwarden -f
```

## Feature Flags

Control which Vaultwarden features are enabled or disabled.

| Parameter | Description | Default |
| --- | --- | --- |
| `config.webVaultEnabled` | Enable the web vault UI | `true` |
| `config.sendsAllowed` | Allow users to create Sends (file/text sharing) | `true` |
| `config.emergencyAccessAllowed` | Allow emergency access feature | `true` |
| `config.orgCreationUsers` | Who can create organizations (`all` \| `admin` \| `none`) | `all` |
| `config.orgGroupsEnabled` | Enable organization groups (beta) | `false` |
| `config.orgEventsEnabled` | Enable organization event logging | `false` |

### Hardened configuration example

```yaml
config:
  webVaultEnabled: "true"
  sendsAllowed: "false"
  emergencyAccessAllowed: "false"
  orgCreationUsers: "admin"
  orgGroupsEnabled: "false"
  orgEventsEnabled: "true"
```

## WebSocket Support

Vaultwarden uses WebSockets at `/notifications/hub` for real-time synchronization across clients. When using Nginx Ingress, enable WebSocket support to ensure live updates work correctly.

| Parameter | Description | Default |
| --- | --- | --- |
| `ingress.websocket.enabled` | Enable WebSocket path and Nginx timeout annotations | `false` |

### Nginx Ingress example with WebSocket

```yaml
ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  host: "vaultwarden.example.com"
  tls:
    enabled: true
    secretName: "vaultwarden-tls"
  websocket:
    enabled: true
```

When `websocket.enabled: true`, the following are automatically added:
- An explicit path rule for `/notifications/hub`
- `nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"`
- `nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"`

## Storage Quotas

Limit attachment storage per user and per organization, and configure automatic trash deletion.

| Parameter | Description | Default |
| --- | --- | --- |
| `storage.orgAttachmentLimit` | Organization attachment storage limit (KB, empty = unlimited) | `""` |
| `storage.userAttachmentLimit` | Per-user attachment storage limit (KB, empty = unlimited) | `""` |
| `storage.sendStorageLimit` | Per-user Sends storage limit (KB, empty = unlimited) | `""` |
| `storage.trashAutoDeletion` | Days before trash items are permanently deleted (empty = disabled) | `""` |

### Example: 1 GB per user, 5 GB per org, 30-day trash

```yaml
storage:
  orgAttachmentLimit: "5120000"   # 5 GB in KB
  userAttachmentLimit: "1024000"  # 1 GB in KB
  sendStorageLimit: "524288"      # 512 MB in KB
  trashAutoDeletion: "30"
```

## Scheduled Tasks

Configure the cron schedules for Vaultwarden's internal maintenance jobs. Leave empty to use Vaultwarden's built-in defaults.

| Parameter | Description | Default (Vaultwarden) |
| --- | --- | --- |
| `jobs.emergencyNotificationReminder` | Cron schedule for emergency access reminders | Every hour |
| `jobs.emergencyAccessRequestTimeout` | Cron schedule for timing out emergency access requests | Every hour |
| `jobs.eventCleanup` | Cron schedule for organization event log cleanup | Daily at 10:00 |
| `jobs.eventRetentionDays` | Days to retain organization events (empty = unlimited) | `""` |

### Example: custom schedules

```yaml
jobs:
  emergencyNotificationReminder: "0 */6 * * *"  # every 6 hours
  emergencyAccessRequestTimeout: "0 */6 * * *"  # every 6 hours
  eventCleanup: "0 2 * * 0"                     # weekly on Sunday at 2am
  eventRetentionDays: "90"
```

## Multi-Factor Authentication

### YubiKey

Hardware token 2FA via Yubico's validation API. Requires a free API key from [upgrade.yubico.com/getapikey](https://upgrade.yubico.com/getapikey/).

| Parameter | Description | Default |
| --- | --- | --- |
| `yubikey.clientId` | Yubico API client ID | `""` |
| `yubikey.secretKey` | Yubico API secret key (stored in Secret) | `""` |
| `yubikey.server` | Custom validation server URL (empty = api.yubico.com) | `""` |

```yaml
yubikey:
  clientId: "12345"
  secretKey: "your-yubico-secret"
```

### Duo Security

| Parameter | Description | Default |
| --- | --- | --- |
| `duo.iKey` | Duo integration key | `""` |
| `duo.secretKey` | Duo secret key (stored in Secret) | `""` |
| `duo.hostname` | Duo API hostname (e.g. `api-XXXXXXXX.duosecurity.com`) | `""` |

```yaml
duo:
  iKey: "DIXXXXXXXXXXXXXXXXXX"
  secretKey: "your-duo-secret"
  hostname: "api-XXXXXXXX.duosecurity.com"
```

## Advanced SMTP Options

In addition to the basic SMTP parameters, the following advanced options are available:

| Parameter | Description | Default |
| --- | --- | --- |
| `smtp.authMechanism` | Authentication mechanism (`Plain` \| `Login` \| `Xoauth2`) | `Plain` |
| `smtp.acceptInvalidHostnames` | Accept invalid hostnames in certificates | `false` |
| `smtp.acceptInvalidCerts` | Accept invalid SSL/TLS certificates | `false` |
| `smtp.debug` | Enable SMTP debug logging | `false` |

> **Warning:** `acceptInvalidHostnames` and `acceptInvalidCerts` should only be used in development/testing environments. Never enable these in production.

### Example: Office 365 with Login mechanism

```yaml
smtp:
  host: "smtp.office365.com"
  port: "587"
  security: "starttls"
  from: "vaultwarden@yourdomain.com"
  username: "vaultwarden@yourdomain.com"
  authMechanism: "Login"
```
## Sources

- Official project: [github.com/dani-garcia/vaultwarden](https://github.com/dani-garcia/vaultwarden)
- DockerHub: [hub.docker.com/r/vaultwarden/server](https://hub.docker.com/r/vaultwarden/server)
- Wiki — admin token: [Enabling admin page](https://github.com/dani-garcia/vaultwarden/wiki/Enabling-admin-page)
