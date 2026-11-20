# Our own server (Azure)

The real चौतारी runs on one machine that the community controls, paid from ZenTrust's nonprofit Azure credit
(USD 2,000 a year, valid to 19 Nov 2027; it is renewed by hand each year).

| What | Where |
| --- | --- |
| Machine | `chautari-1` in resource group `rg-chautari`, Central India, Ubuntu 24.04, 2 CPU / 8 GB, 64 GB SSD |
| Address | https://chautari-zentrust.centralindia.cloudapp.azure.com |
| Secrets | Key Vault `kv-chautari-e34c1e` (database keys, backup passphrase, the readers' API keys) |
| Backups | Storage `stchautarie34c1e` in South India, container `backups`, encrypted nightly at 02:30 Nepal time, kept 90 days |
| Budgets | USD 100 a month, USD 1,500 a year; alerts to the subscription Owner and to the address given as `ALERT_EMAIL` |

**Data:** TEST data only (the app shows a "परीक्षण · TEST" badge) until the lawyer has reviewed members' data
on a server in India (Individual Privacy Act 2075). Before real use the test database is wiped and rebuilt.

## Build or rebuild

In Azure Cloud Shell (Bash), signed in as the ZenTrust account:

    curl -fsSL https://raw.githubusercontent.com/zentrust-inc/chautari/main/deploy/azure/provision.sh | REF=main bash

It is safe to run again. `deploy/server/setup.sh` does the work on the machine; its log is `/var/log/chautari-setup.log`.
No remote-login port is open; the machine is managed with `az vm run-command invoke … --scripts '…'`.

## The readers' keys

The bill reader uses Claude + Google Cloud Vision (decided 19 Nov 2026). Their keys are put **by hand** into the Key Vault
(portal › Key vaults › kv-chautari-e34c1e › Objects › Secrets): `anthropic-api-key`, `vision-api-key`, and optionally
`sarvam-api-key`. Then restart the reader:

    az vm run-command invoke -g rg-chautari -n chautari-1 --command-id RunShellScript \
      --scripts 'DOMAIN=chautari-zentrust.centralindia.cloudapp.azure.com chautari-start-reader'

Until both keys are in, the reader uses Tesseract on the machine.

## Restore

A new machine from `provision.sh` takes the Supabase secrets back from the Key Vault (`supabase-env`). The database and
photos come back from the newest backup: download `db.sql.gz.gpg` and `documents.tgz.gpg`, decrypt them with the
`backup-passphrase` secret (`gpg -d`), and load the dump with `psql`.
