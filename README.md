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

## Advanced Pod Configuration

### Node selector, tolerations and affinity

```yaml
nodeSelector:
  kubernetes.io/os: linux

tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "vaultwarden"
    effect: "NoSchedule"

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          topologyKey: kubernetes.io/hostname
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: vaultwarden
```

### Security contexts

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000

containerSecurityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: false
```

### Extra environment variables

```yaml
extraEnvVars:
  - name: ROCKET_WORKERS
    value: "10"
  - name: WEB_VAULT_FOLDER
    value: "/web-vault/"
```

### Startup probe

Enable the startup probe for slower cluster environments where the container takes time to initialize:

```yaml
startupProbe:
  enabled: true
  initialDelaySeconds: 10
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 30
```

### Image pull secrets

```yaml
imagePullSecrets:
  - name: my-registry-secret
```

## User Registration Controls

Fine-grained control over user registration, email verification, and invitations.

| Parameter | Description | Default |
| --- | --- | --- |
| `config.signupDomains` | Restrict registrations to these email domains (comma-separated) | `""` (all allowed) |
| `config.signupsVerify` | Require email verification upon registration | `false` |
| `config.emailChangeAllowed` | Allow users to change their email address | `true` |
| `config.invitationOrgName` | Organization name shown in invitation emails | `Vaultwarden` |
| `config.invitationExpiration` | Invitation link validity in hours | `120` |
| `config.requireDeviceEmail` | Require users to have an email address on their device | `false` |

### Restricting to company domains

```yaml
config:
  signupsAllowed: "true"
  signupDomains: "mycompany.com,subsidiary.com"
  signupsVerify: "true"
  invitationOrgName: "MyCompany Vault"
```

## SSO / OpenID Connect

Vaultwarden supports Single Sign-On via OpenID Connect. This requires a compatible identity provider (Keycloak, Authentik, Azure AD, Google, etc.).

| Parameter | Description | Default |
| --- | --- | --- |
| `sso.enabled` | Enable SSO authentication | `false` |
| `sso.onlySSO` | Disable password login — enforce SSO only | `false` |
| `sso.authority` | OpenID Connect discovery URL | `""` |
| `sso.clientId` | OIDC client ID | `""` |
| `sso.clientSecret` | OIDC client secret (stored in Secret) | `""` |
| `sso.pkce` | Enable PKCE (Proof Key for Code Exchange) | `true` |
| `sso.scopes` | OIDC scopes to request | `email profile` |
| `sso.masterPasswordPolicy` | Master password policy JSON | `""` |

### Keycloak example

```yaml
sso:
  enabled: true
  onlySSO: false
  authority: "https://keycloak.example.com/realms/myrealm"
  clientId: "vaultwarden"
  clientSecret: "your-client-secret"
  pkce: true
  scopes: "email profile"
```

> **Note:** SSO in Vaultwarden requires the SSO patch (available in the official `vaultwarden/server` image). Consult the [Vaultwarden SSO wiki](https://github.com/dani-garcia/vaultwarden/wiki) for setup details.

## Push Notifications

Enable mobile push notifications to sync vaults in real-time on iOS and Android clients. Requires a free Bitwarden.com account to obtain installation credentials.

| Parameter | Description | Default |
| --- | --- | --- |
| `pushNotifications.enabled` | Enable push notifications | `false` |
| `pushNotifications.installationId` | Bitwarden installation ID (stored in Secret) | `""` |
| `pushNotifications.installationKey` | Bitwarden installation key (stored in Secret) | `""` |
| `pushNotifications.relayUri` | Custom relay URI (empty = Bitwarden default) | `""` |
| `pushNotifications.identityUri` | Custom identity URI (empty = Bitwarden default) | `""` |

### Setup

1. Create a Bitwarden account at [bitwarden.com](https://bitwarden.com)
2. Go to [bitwarden.com/host](https://bitwarden.com/host) to generate credentials
3. Add the credentials to your `values.yaml`:

```yaml
pushNotifications:
  enabled: true
  installationId: "your-installation-id"
  installationKey: "your-installation-key"
```

The `installationId` and `installationKey` are stored in the Kubernetes Secret.

## Database Configuration

By default, Vaultwarden uses SQLite stored at `/data/db.sqlite3`. For production deployments with higher availability requirements, PostgreSQL or MySQL/MariaDB are recommended.

| Parameter | Description | Default |
| --- | --- | --- |
| `database.type` | Database engine (`sqlite` \| `mysql` \| `postgresql`) | `sqlite` |
| `database.host` | Database server hostname | `""` |
| `database.port` | Database server port | `""` |
| `database.name` | Database name | `vaultwarden` |
| `database.username` | Database username | `""` |
| `database.password` | Database password | `""` |
| `database.uri` | Full connection URI (overrides individual fields) | `""` |

### PostgreSQL example

```yaml
database:
  type: postgresql
  host: postgres.default.svc.cluster.local
  port: "5432"
  name: vaultwarden
  username: vaultwarden
  password: "strongpassword"
```

The `DATABASE_URL` is constructed as `postgresql://username:password@host:port/name` and stored in the Kubernetes Secret.

### Using an existing database URI

```yaml
database:
  type: postgresql
  uri: "postgresql://user:pass@host:5432/vaultwarden?sslmode=require"
```

## HIBP Integration

[Have I Been Pwned](https://haveibeenpwned.com) integration allows Vaultwarden to check passwords against known data breach databases.

| Parameter | Description | Default |
| --- | --- | --- |
| `hibp.apiKey` | HIBP API key (stored in Secret) | `""` |

Get your API key at [haveibeenpwned.com/API/Key](https://haveibeenpwned.com/API/Key).

```yaml
hibp:
  apiKey: "your-hibp-api-key"
```

## Icon Service

Configure how Vaultwarden fetches favicons for vault entries.

| Parameter | Description | Default |
| --- | --- | --- |
| `icons.service` | Icon source (`internal` \| `bitwarden` \| `duckduckgo` \| `google` \| custom URL) | `internal` |
| `icons.redirectCode` | HTTP redirect code (`301` \| `302`) | `302` |
| `icons.disableLocalNetworkAccess` | Block icon fetches from private/local IPs | `false` |

### Privacy-focused configuration

```yaml
icons:
  service: "internal"
  disableLocalNetworkAccess: "true"
```

## Administration

| Parameter | Description | Default |
| --- | --- | --- |
| `admin.rateLimitSeconds` | Admin panel rate limit window (seconds) | `300` |
| `admin.rateLimitMaxBurst` | Max failed login attempts in the window | `3` |

## Logging

| Parameter | Description | Default |
| --- | --- | --- |
| `logging.level` | Log verbosity (`trace` \| `debug` \| `info` \| `warn` \| `error`) | `info` |
| `logging.file` | Path to log file (empty = stdout only) | `""` |
| `logging.timestamps` | Enable extended logging with timestamps | `false` |

```yaml
logging:
  level: "warn"
  file: "/data/vaultwarden.log"
  timestamps: "true"
```
## Sources

- Official project: [github.com/dani-garcia/vaultwarden](https://github.com/dani-garcia/vaultwarden)
- DockerHub: [hub.docker.com/r/vaultwarden/server](https://hub.docker.com/r/vaultwarden/server)
- Wiki — admin token: [Enabling admin page](https://github.com/dani-garcia/vaultwarden/wiki/Enabling-admin-page)
