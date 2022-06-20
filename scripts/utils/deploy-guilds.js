const { waitBlocks } = require("./wait");

/* eslint-disable no-case-declarations */
require("@nomiclabs/hardhat-web3");

const deployGuilds = async function (guilds, networkContracts) {
  const PermissionRegistry = await hre.artifacts.require("PermissionRegistry");
  const permissionRegistry = await PermissionRegistry.new();

  // Each guild is created and initialized and use a previously deployed token or specific token address

  for (let i = 0; i < guilds.length; i++) {
    const guildToDeploy = guilds[i];
    console.log("Deploying guild", guildToDeploy.name);
    const GuildContract = await hre.artifacts.require(
      guildToDeploy.contractName
    );
    const newGuild = await GuildContract.new();
    await newGuild.initialize(
      networkContracts.addresses[guildToDeploy.token],
      guildToDeploy.proposalTime,
      guildToDeploy.timeForExecution,
      guildToDeploy.votingPowerForProposalExecution,
      guildToDeploy.votingPowerForProposalCreation,
      guildToDeploy.name,
      guildToDeploy.voteGas,
      guildToDeploy.maxGasPrice,
      guildToDeploy.maxActiveProposals,
      guildToDeploy.lockTime,
      permissionRegistry.address
    );
    await waitBlocks(1);

    if (guildToDeploy.contractName === "SnapshotRepERC20Guild")
      await newGuild.transferOwnership(newGuild.address);

    networkContracts.addresses[guildToDeploy.name] = newGuild.address;
    networkContracts.addresses[guildToDeploy.name + "-vault"] =
      await newGuild.getTokenVault();
  }

  return networkContracts;
};

module.exports = {
  deployGuilds,
};
