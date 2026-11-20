#!/usr/bin/env bash
# चौतारी — create our own server on Azure. Run in Azure Cloud Shell (Bash), signed in as the ZenTrust account:
#   curl -fsSL https://raw.githubusercontent.com/zentrust-inc/chautari/<ref>/deploy/azure/provision.sh | REF=<ref> bash
# It is safe to run again: what exists is kept.
#
# What it makes (all in resource group rg-chautari, paid from ZenTrust's nonprofit Azure credit):
#   - budgets first: USD 100 a month and USD 1,500 a year; alerts to the subscription Owner, and to ALERT_EMAIL if given
#   - one Ubuntu 24.04 machine in Central India (2 CPU, 8 GB; cheapest allowed size, ARM first), 64 GB SSD, a fixed public address with a name
#   - firewall: only web traffic in (80, 443); no remote login port is open (we manage it with Azure's run-command)
#   - a Key Vault for the server's secrets (database keys, backup passphrase, the readers' API keys)
#   - a storage account in South India for the encrypted nightly backups (kept 90 days)
#   - then it installs everything on the machine (deploy/server/setup.sh) and prints a health check
set -euo pipefail
REF="${REF:-main}"
SUB="${SUB:-e34c1e50-2cde-4f6c-82bf-f00720511278}"
RG=rg-chautari; LOC=centralindia; BLOC=southindia
VM=chautari-1; DNS=chautari-zentrust
ALERT_EMAIL="${ALERT_EMAIL:-}"   # optional: an address for the budget alerts, given when running the script
SFX=$(echo "$SUB" | cut -c1-6)
KV="kv-chautari-$SFX"; ST="stchautari$SFX"
DOMAIN="$DNS.$LOC.cloudapp.azure.com"
say() { printf '\n== %s\n' "$*"; }

az account set -s "$SUB"
ME=$(az ad signed-in-user show --query id -o tsv)

say "register the services we use (first time only)"
for p in Microsoft.Compute Microsoft.Network Microsoft.Storage Microsoft.KeyVault Microsoft.Consumption; do
  az provider register -n "$p" --wait -o none
done

say "budgets: USD 100 a month, USD 1,500 a year (alerts at 50%, 80%, 100% and forecast 100%)"
if [ -n "$ALERT_EMAIL" ]; then TO="\"contactRoles\":[\"Owner\"],\"contactEmails\":[\"$ALERT_EMAIL\"]"; else TO="\"contactRoles\":[\"Owner\"],\"contactEmails\":[]"; fi
budget() { # name amount grain start end
  az rest --method put -o none \
    --url "https://management.azure.com/subscriptions/$SUB/providers/Microsoft.Consumption/budgets/$1?api-version=2023-05-01" \
    --body "{\"properties\":{\"category\":\"Cost\",\"amount\":$2,\"timeGrain\":\"$3\",
      \"timePeriod\":{\"startDate\":\"$4\",\"endDate\":\"$5\"},
      \"notifications\":{
        \"a50\":{\"enabled\":true,\"operator\":\"GreaterThan\",\"threshold\":50,\"thresholdType\":\"Actual\",$TO},
        \"a80\":{\"enabled\":true,\"operator\":\"GreaterThan\",\"threshold\":80,\"thresholdType\":\"Actual\",$TO},
        \"a100\":{\"enabled\":true,\"operator\":\"GreaterThan\",\"threshold\":100,\"thresholdType\":\"Actual\",$TO},
        \"f100\":{\"enabled\":true,\"operator\":\"GreaterThan\",\"threshold\":100,\"thresholdType\":\"Forecasted\",$TO}}}}"
}
budget chautari-monthly 100 Monthly 2026-11-01T00:00:00Z 2027-12-31T00:00:00Z
budget chautari-grant-year 1500 Annually 2026-11-01T00:00:00Z 2027-12-31T00:00:00Z
az rest --method get --url "https://management.azure.com/subscriptions/$SUB/providers/Microsoft.Consumption/budgets?api-version=2023-05-01" \
  --query "value[].{name:name, amount:properties.amount, grain:properties.timeGrain}" -o table

say "resource group"
az group create -n "$RG" -l "$LOC" -o none

say "machine size: the cheapest 2-CPU / 8 GB size this subscription may use in $LOC"
pick() { [ -n "$(az vm list-skus -l "$LOC" --size "$1" --resource-type virtualMachines --query "[?name=='$1' && length(restrictions)==\`0\`].name" -o tsv)" ]; }
SIZE=""; for s in ${SIZES:-Standard_B2ps_v2 Standard_B2as_v2 Standard_B2s_v2}; do if pick "$s"; then SIZE=$s; break; fi; echo "$s: not available to this subscription here"; done
[ -n "$SIZE" ] || { echo "no 2-CPU / 8 GB size available in $LOC"; exit 1; }
case "$SIZE" in *p*_v2|*pl*_v2) IMAGE=Canonical:ubuntu-24_04-lts:server-arm64:latest ;; *) IMAGE=Canonical:ubuntu-24_04-lts:server:latest ;; esac
echo "using $SIZE ($IMAGE)"

say "Key Vault $KV (secrets) and storage $ST in $BLOC (backups)"
az keyvault show -n "$KV" -o none 2>/dev/null || az keyvault create -n "$KV" -g "$RG" -l "$LOC" --enable-rbac-authorization true --retention-days 90 -o none
KVID=$(az keyvault show -n "$KV" --query id -o tsv)
az role assignment create --assignee-object-id "$ME" --assignee-principal-type User --role "Key Vault Secrets Officer" --scope "$KVID" -o none 2>/dev/null || true
az storage account show -n "$ST" -o none 2>/dev/null || az storage account create -n "$ST" -g "$RG" -l "$BLOC" --sku Standard_LRS --kind StorageV2 \
  --access-tier Cool --min-tls-version TLS1_2 --allow-blob-public-access false --allow-shared-key-access false -o none
STID=$(az storage account show -n "$ST" --query id -o tsv)
az role assignment create --assignee-object-id "$ME" --assignee-principal-type User --role "Storage Blob Data Contributor" --scope "$STID" -o none 2>/dev/null || true
az rest --method put -o none --url "https://management.azure.com$STID/blobServices/default/containers/backups?api-version=2023-01-01" --body '{"properties":{"publicAccess":"None"}}'
az storage account management-policy create --account-name "$ST" -g "$RG" -o none --policy '{"rules":[{"enabled":true,"name":"keep-90-days","type":"Lifecycle",
  "definition":{"filters":{"blobTypes":["blockBlob"],"prefixMatch":["backups/"]},"actions":{"baseBlob":{"delete":{"daysAfterModificationGreaterThan":90}}}}}]}'

say "the readers' API keys: empty placeholders that Dr. Shrestha fills in the portal (Key Vault › Secrets)"
for s in anthropic-api-key vision-api-key sarvam-api-key; do
  az keyvault secret show --vault-name "$KV" -n "$s" -o none 2>/dev/null || az keyvault secret set --vault-name "$KV" -n "$s" --value "not-set" -o none
done

say "machine $VM ($SIZE), 64 GB SSD, fixed address $DOMAIN"
if ! az vm show -g "$RG" -n "$VM" -o none 2>/dev/null; then
  az vm create -g "$RG" -n "$VM" -l "$LOC" --image "$IMAGE" --size "$SIZE" \
    --os-disk-size-gb 64 --storage-sku StandardSSD_LRS --public-ip-sku Standard --public-ip-address-dns-name "$DNS" \
    --admin-username chautari --generate-ssh-keys --nsg-rule NONE --assign-identity --only-show-errors -o none
fi
NSG=$(az network nsg list -g "$RG" --query "[0].name" -o tsv)
az network nsg rule create -g "$RG" --nsg-name "$NSG" -n web --priority 100 --direction Inbound --access Allow --protocol Tcp \
  --destination-port-ranges 80 443 -o none
VMID=$(az vm show -g "$RG" -n "$VM" --query identity.principalId -o tsv)
az role assignment create --assignee-object-id "$VMID" --assignee-principal-type ServicePrincipal --role "Key Vault Secrets Officer" --scope "$KVID" -o none 2>/dev/null || true
az role assignment create --assignee-object-id "$VMID" --assignee-principal-type ServicePrincipal --role "Storage Blob Data Contributor" --scope "$STID" -o none 2>/dev/null || true
echo "waiting a minute for the machine's permissions to take effect"; sleep 60

say "install everything on the machine (runs there in the background, 10-15 minutes)"
az vm run-command invoke -g "$RG" -n "$VM" --command-id RunShellScript -o tsv --query "value[0].message" --scripts \
  "curl -fsSL https://raw.githubusercontent.com/zentrust-inc/chautari/$REF/deploy/server/setup.sh -o /root/setup.sh && \
   (REF=$REF KV=$KV ST=$ST DOMAIN=$DOMAIN setsid bash /root/setup.sh > /var/log/chautari-setup.log 2>&1 &) && echo started"
echo "follow it with:"
echo "  az vm run-command invoke -g $RG -n $VM --command-id RunShellScript -o tsv --query 'value[0].message' --scripts 'tail -25 /var/log/chautari-setup.log'"

say "done: https://$DOMAIN"
az vm show -d -g "$RG" -n "$VM" --query "{name:name, size:hardwareProfile.vmSize, state:powerState, ip:publicIps, fqdn:fqdns}" -o table
