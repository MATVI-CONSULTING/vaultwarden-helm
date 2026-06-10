# vaultwarden-helm

Helm chart for self-hosted Vaultwarden deployment on Kubernetes, with Argon2 admin token, SMTP configuration, persistent storage, and Ingress support.

## Installation

```bash
helm install vaultwarden . -f values.yaml
```

Avec un fichier de valeurs personnalisé :

```bash
helm install vaultwarden . -f my-values.yaml
```

## Configuration

Copier `values.yaml` et adapter les valeurs à l'environnement cible.

### Paramètres principaux

| Paramètre | Description | Valeur par défaut |
| --- | --- | --- |
| `image.repository` | Image Docker | `vaultwarden/server` |
| `image.tag` | Tag de l'image | `1.36.0` |
| `config.domain` | URL publique de l'instance | `https://vaultwarden.example.com` |
| `config.signupsAllowed` | Autoriser les inscriptions | `false` |
| `secrets.adminToken` | Hash Argon2 du mot de passe admin | `""` |
| `secrets.smtpPassword` | Mot de passe SMTP | `""` |
| `smtp.host` | Serveur SMTP | `""` |
| `smtp.port` | Port SMTP | `587` |
| `smtp.security` | Sécurité SMTP (`starttls` / `force_tls` / `off`) | `starttls` |
| `persistence.enabled` | Activer le stockage persistant | `true` |
| `persistence.size` | Taille du PVC | `1Gi` |
| `ingress.enabled` | Activer l'Ingress | `true` |
| `ingress.host` | Hostname de l'Ingress | `vaultwarden.example.com` |
| `ingress.tls.enabled` | Activer TLS | `false` |

### Token admin (Argon2)

Générer le hash Argon2 avant le déploiement :

```bash
docker run --rm -it vaultwarden/server /vaultwarden hash --preset owasp
```

Coller le hash généré dans `values.yaml` :

```yaml
secrets:
  adminToken: "$argon2id$v=19$m=19456,t=2,p=1$..."
```

> À `/admin`, saisir le **mot de passe** choisi lors de la génération, pas le hash.

### Ingress avec TLS (cert-manager)

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

## Ressources Kubernetes créées

| Ressource | Description |
| --- | --- |
| `Deployment` | Pod Vaultwarden |
| `Service` | ClusterIP sur le port 80 |
| `Ingress` | Exposition HTTP/HTTPS (si activé) |
| `PersistentVolumeClaim` | Stockage des données `/data` (si activé) |
| `ConfigMap` | Variables de configuration non-sensibles |
| `Secret` | `ADMIN_TOKEN` et `SMTP_PASSWORD` |

## Commandes utiles

```bash
# Valider le chart sans déployer
helm template vaultwarden . -f values.yaml

# Mettre à jour après modification de values.yaml
helm upgrade vaultwarden . -f values.yaml

# Désinstaller
helm uninstall vaultwarden

# Statut du déploiement
kubectl get pods -l app.kubernetes.io/name=vaultwarden
kubectl logs -l app.kubernetes.io/name=vaultwarden -f
```

## Sources

- Projet officiel : [github.com/dani-garcia/vaultwarden](https://github.com/dani-garcia/vaultwarden)
- DockerHub : [hub.docker.com/r/vaultwarden/server](https://hub.docker.com/r/vaultwarden/server)
- Wiki — token admin : [Enabling admin page](https://github.com/dani-garcia/vaultwarden/wiki/Enabling-admin-page)
