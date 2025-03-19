const { task } = require("hardhat/config");

// Mappatura tra label e indirizzi dei contratti
const PRECOMPILES_CONTRACT_ADDRESSES = {
    deployer: "0x0200000000000000000000000000000000000000",
    minter: "0x0200000000000000000000000000000000000001",
    transaction: "0x0200000000000000000000000000000000000002",
};

// Definizione del task
task("set-manager-address", "Abilita un indirizzo a manager nel allow list di un precompile")
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

        console.log(`🔹 Inviando transazione per abilitare l'indirizzo: ${address} sul ${precompile}...`);

        try {
            const tx = await contractInstance.connect(sender).setManager(address);
            console.log(`📤 Transazione inviata! Hash: ${tx.hash}`);

            await tx.wait();
            console.log(`✅ Transazione confermata! L'indirizzo è stato abilitato.`);
        } catch (error) {
            console.error("❌ Errore durante la transazione:", error);
        }
    });
