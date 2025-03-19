const { task } = require("hardhat/config");

// Mappatura tra label e indirizzi dei contratti
const PRECOMPILES_CONTRACT_ADDRESSES = {
    deployer: "0x0200000000000000000000000000000000000000",
    minter: "0x0200000000000000000000000000000000000001",
    transaction: "0x0200000000000000000000000000000000000002",
};

const ROLES = {
    0: "NONE",
    1: "ENABLED",
    2: "ADMIN",
    3: "MANAGER",
};

// Definizione del task
task("get-role-address", "Abilita un indirizzo in un contratto")
    .addParam("precompile", "Label del precompile (deployer, minter, transaction)")
    .addParam("address", "L'indirizzo da abilitare")
    .setAction(async (taskArgs, hre) => {
        const { precompile, address } = taskArgs;

        const precompileAddress = PRECOMPILES_CONTRACT_ADDRESSES[precompile.toLowerCase()];
        if (!precompileAddress) {
            console.error(`❌ Errore: la label '${precompile}' non è valida. Usa una delle seguenti:`);
            console.log(Object.keys(PRECOMPILES_CONTRACT_ADDRESSES).join(", "));
            return;
        }

        const [sender] = await hre.ethers.getSigners();
        const contractInstance = await hre.ethers.getContractAt("IAllowList", precompileAddress);

        try {
            const role = await contractInstance.connect(sender).readAllowList(address);
            console.log(`✅ Il ruolo dell'indirizzo è ${ROLES[role]}.`);
        } catch (error) {
            console.error("❌ Errore durante la richiesta:", error);
        }
    });
