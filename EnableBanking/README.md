# EnableBanking (PowerShell module)

Log in to a bank through Enable Banking with BankID, and see exactly what it sends:
accounts, details, balances and transactions, as Enable Banking's own objects. Nothing is
hidden, so the output holds real names, account numbers and amounts. Don't paste it anywhere
public.

Needs PowerShell 7.2 or later, and your own Enable Banking application (its id and the
private key `.pem` you made when registering it).

```powershell
Import-Module .\tools\EnableBanking

Connect-EB -AppId <application id> -KeyPath ~\keys\enablebanking.pem
Get-EBBank -Name '*sparebank*'                  # which banks there are
New-EBSession -Bank DNB                         # BankID in the browser, then paste the address
Get-EBSession                                   # your saved sessions
Get-EBSession -Bank DNB                         # status and consent, from Enable Banking
Get-EBAccount -Bank DNB                         # uid and identification_hash per account
Get-EBAccount -Bank DNB | Get-EBAccountDetails  # name, account number, product
Get-EBAccount -Bank DNB | Get-EBBalance
Get-EBAccount -Bank DNB | Get-EBTransaction -From 2026-01-01 | Export-Csv dnb.csv
Remove-EBSession -Bank DNB                      # ends the consent at Enable Banking
Disconnect-EB
```

`Get-Help <command> -Full` explains each one.

- **Connecting:** `Connect-EB` takes the key as a file (`-KeyPath`) or as PEM text (`-Key`,
  for a key kept in a secret store). Anything you leave out is read from the environment:

  | Variable | Instead of | Default |
  | --- | --- | --- |
  | `ENABLEBANKING_APP_ID` | `-AppId` | |
  | `ENABLEBANKING_KEY_PATH` | `-KeyPath` | |
  | `ENABLEBANKING_SESSION_FILE` | `-SessionFile` | `~/.enablebanking/sessions.json` |
  | `ENABLEBANKING_REDIRECT_URL` | `-RedirectUrl` | `https://localhost:8443/callback` |

- **Saved sessions** are in the session file. With your key, that file reads your accounts
  until the consent runs out: keep it out of git, and run `Remove-EBSession` when you are
  done.
- **Bank limits:** details, balances and transactions are fetched from the bank. Without you
  present, banks allow about 4 such calls per account per day. `Get-EBAccount` asks only
  Enable Banking, so it is free.

Tests (Pester 5 or later, no network): `Invoke-Pester tools/EnableBanking/tests`
