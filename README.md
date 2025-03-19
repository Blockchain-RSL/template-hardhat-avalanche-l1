## Sample Hardhat Project connected to isp climate kick layer 1 local avalanche network

This project demonstrates a basic use case of Hardhat. It includes a sample contract and a script to deploy that contract.

After setting the .env variables, you can try running the following tasks:

```shell
npx hardhat run .\scripts\CustomERC20\0_deploy.js --network private_avalanche_isp_climatekick_l1_test

npx hardhat run .\scripts\CustomERC20\1_transfer_token.js --network private_avalanche_isp_climatekick_l1_test

npx hardhat run .\scripts\NativeTokenICKT\0_transfer_token.js --network private_avalanche_isp_climatekick_l1_test
```

## Get Native Token

The current native token of the network is ICKT. You can obtain some ICKT by running the following command:

```shell
npx hardhat run .\scripts\NativeTokenICKT\0_transfer_token.js --network private_avalanche_isp_climatekick_l1_test
```

The private_avalanche_isp_climatekick_l1_test network is set by default in the hardhat.config.js file.

## Execute Flow HLC full ledger

It is also possible to execute a flow that creates a full ledger DvP transaction using a custom ERC20 token and a security asset.

```shell
./utils/executeHLCFullLedger_ECHLC.bat
```

This flow is based on the scInfo.json file, which contains the information about the deployed smart contract.

To reset the scInfo.json, you can use the following .bat file:

```shell
./utils/resetScInfo.bat
```

### Steps HLC flow

Clean the scInfo.json file

```shell
node .\scripts\HLC\resetScInfo.js
```

Request native token ICKT in order to pay gas fee

```shell
call npx hardhat run ./scripts/NativeTokenICKT/0_transfer_token.js
```

Deploy the ERC20 custom used to "pay" the security asset

```shell
call npx hardhat run ./scripts/CustomERC20/0_deploy.js
```

Transfer the custom ERC20 token to the buyer and seller

```shell
call npx hardhat run ./scripts/CustomERC20/1_transfer_token.js
```

Deploy the restrictions contract dedicated to whitelist the security asset holders

```shell
call npx hardhat run ./scripts/HLC/0_deploy_restrictions.js
```

Deploy the security asset representing the asset

```shell
call npx hardhat run ./scripts/HLC/1_deploy_custom_security_asset.js
```

Deploy the HLC contract, an escrow account where tokens are locked until the DvP is executed

```shell
call npx hardhat run ./scripts/HLC/ECHLC/2_deploy_hlc.js
```

Transfer the security asset to the HLC contract

```shell
call npx hardhat run ./scripts/HLC/ECHLC/3_seller_transfer_token_to_hlc.js
```

Transfer the custom ERC20 token to the HLC contract

```shell
call npx hardhat run ./scripts/HLC/ECHLC/4_buyer_transfer_token_to_hlc.js
```

Execute the DvP transaction

```shell
call npx hardhat run ./scripts/HLC/ECHLC/5_execute_dvp.js
```

## Slither report

In order to generate a report of slither, execute the .bat file:

```shell
./utils/runSlitherReport.bat
```

It will create a report on the slither folder slitherReport.

## ENV file

```shell
PRIVATE_KEY_1 deployer and admin
```

```shell
PRIVATE_KEY_2 seller and issuer
```

```shell
PRIVATE_KEY_3 buyer and holder
```

```shell
PRIVATE_KEY_4 main airdrop account
```

```shell
RPC_URL_AVALANCHE_L1_TEST RPC URL of the avalanche network
```

```shell
RPC_BEARER_TOKEN_AVALANCHE_L1_TEST Bearer token of the avalanche network
```

## ABI and bin extract

In order to extract the abi and the bin of a contract, you can use the following command:

```shell
node ./utils/extractAbiByteCode.js
```

# 🛠 Hardhat Tasks per la gestione dei permessi

Questa repository include una serie di task Hardhat per interagire con contratti precompilati su una blockchain compatibile con Ethereum.

I task disponibili sono:

-   `enable-address` → Abilita un indirizzo su un contratto precompilato.
-   `get-role-address` → Recupera il ruolo di un indirizzo su un contratto precompilato.
-   `set-admin-address` → Imposta un indirizzo come admin.
-   `set-manager-address` → Imposta un indirizzo come manager.

---

## 📌 **Setup del progetto**

### **Configurazione**

I task utilizzano un mapping per identificare gli indirizzi dei contratti precompilati. Questi contratti sono:

| Label precompiles | Nome contratto         | Indirizzo                                    |
| ----------------- | ---------------------- | -------------------------------------------- |
| **deployer**      | Deployer Allow List    | `0x0200000000000000000000000000000000000000` |
| **minter**        | Native Minter          | `0x0200000000000000000000000000000000000001` |
| **transaction**   | Transaction Allow List | `0x0200000000000000000000000000000000000002` |

Per eseguire i task, puoi specificare il **Label precompiles** invece dell'indirizzo, grazie alla mappatura interna.

---

## 🚀 **Utilizzo dei task**

### **1️⃣ Abilitare un indirizzo (`enable-address`)**

Abilita un indirizzo in un contratto precompilato.

```sh
npx hardhat enable-address --precompile <nome-contratto> --address <indirizzo>
```

**Esempio:**

```sh
npx hardhat enable-address --precompile deployer --address 0x627306090abaB3A6e1400e9345bC60c78a8BEf57
```

### **2️⃣ Ottenere il ruolo di un indirizzo (`get-role-address`)**

Recupera il ruolo di un indirizzo in un contratto precompilato.

```sh
npx hardhat get-role-address --precompile <nome-contratto> --address <indirizzo>
```

**Esempio:**

```sh
npx hardhat get-role-address --precompile minter --address 0x627306090abaB3A6e1400e9345bC60c78a8BEf57
```

L'output mostrerà il ruolo assegnato all'indirizzo.

---

### **3️⃣ Impostare un admin (`set-admin-address`)**

Imposta un indirizzo come admin in un contratto precompilato.

```sh
npx hardhat set-admin-address --precompile <nome-contratto> --address <indirizzo>
```

**Esempio:**

```sh
npx hardhat set-admin-address --precompile transaction --address 0x627306090abaB3A6e1400e9345bC60c78a8BEf57
```

---

### **4️⃣ Impostare un manager (`set-manager-address`)**

Imposta un indirizzo come manager in un contratto precompilato.

```sh
npx hardhat set-manager-address --precompile <nome-contratto> --address <indirizzo>
```

**Esempio:**

```sh
npx hardhat set-manager-address --precompile deployer --address 0x627306090abaB3A6e1400e9345bC60c78a8BEf57
```

---
