require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
const path = require("path");
const fs = require("fs");

const PRIVATE_KEY_1 = process.env.PRIVATE_KEY_1;
const PRIVATE_KEY_2 = process.env.PRIVATE_KEY_2;
const PRIVATE_KEY_3 = process.env.PRIVATE_KEY_3;
const PRIVATE_KEY_4 = process.env.PRIVATE_KEY_4;

const accounts = [PRIVATE_KEY_1, PRIVATE_KEY_2, PRIVATE_KEY_3, PRIVATE_KEY_4];

// Carica dinamicamente tutti i file nella cartella tasks
const tasksPath = path.join(__dirname, "tasks");
fs.readdirSync(tasksPath)
    .filter((file) => file.endsWith(".js"))
    .forEach((file) => require(path.join(tasksPath, file)));

module.exports = {
    defaultNetwork: "private_avalanche_isp_climatekick_l1_test",

    networks: {
        hardhat: {},
        private_avalanche_isp_climatekick_l1_test: {
            url: process.env.RPC_URL_AVALANCHE_L1_TEST,
            accounts: accounts,
            chainId: 1111,
            allowUnlimitedContractSize: true,
            timeout: 100000,
            httpHeaders: {
                Authorization: `Bearer ${process.env.RPC_BEARER_TOKEN_AVALANCHE_L1_TEST}`,
            },
        },
    },
    solidity: {
        version: "0.8.24",

        settings: {
            optimizer: {
                enabled: true,
                runs: 100,
            },
            viaIR: true,
        },
    },
};
