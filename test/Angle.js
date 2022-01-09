// This is an exmaple test file. Hardhat will run every *.js file in `test/`,
// so feel free to add new ones.

// Hardhat tests are normally written with Mocha and Chai.

// We import Chai to use its asserting functions here.
const { expect } = require("chai")
const { ethers } = require('hardhat')
const { bytecode: bytecodeMint } = require('../artifacts/contracts/adapters/Angle/MintAgEurAdapterView.sol/MintAgEurAdapterView.json');
const { bytecode: bytecodeBurn } = require('../artifacts/contracts/adapters/Angle/BurnAgEurAdapterView.sol/BurnAgEurAdapterView.json');

// `describe` is a Mocha function that allows you to organize your tests. It's
// not actually needed, but having your tests organized makes debugging them
// easier. All Mocha functions are available in the global scope.

// `describe` recieves the name of a section of your test suite, and a callback.
// The callback must define the tests of that section. This callback can't be
// an async function.
describe("Forex contract", function () {
  // Mocha has four functions that let you hook into the the test runner's
  // lifecyle. These are: `before`, `beforeEach`, `after`, `afterEach`.

  // They're very useful to setup the environment for tests, and to clean it
  // up after they run.

  // A common pattern is to declare some variables, and assign them in the
  // `before` and `beforeEach` callbacks.

  let forex, lpAdapter, angleAdapter
  let owner
  let ibEurWhale
  let ibEurLPWhale
  let susdWhale
  let usdcWhale, feiWhale, fraxWhale
  let ibEur
  let ibEurLP
  let ibKrw
  let susd, usdc, dai, frax, fei, seur, ageur

  const ibEurWhaleAddress = '0xbb3bf20822507c70eafdf11c7469c98fc752ccca'
  const ibEurAddress = '0x96E61422b6A9bA0e068B6c5ADd4fFaBC6a4aae27'
  const ibKRWAddress = '0x95dfdc8161832e4ff7816ac4b6367ce201538253'
  const susdAddress = '0x57Ab1ec28D129707052df4dF418D58a2D46d5f51'
  const ibEurLPWhaleAddress = '0xFFb57364d63D5C5cf299D12Fa73cfabEFc301Dc4'
  const susdWhaleAddress = '0xbc3569a03af09f92a9b07e4845fa809dbdc6adfe'
  const ibEurLPAddress = '0x19b080FE1ffA0553469D20Ca36219F17Fcf03859'
  const usdcWhaleAddress = '0x47ac0fb4f2d84898e4d9e7b4dab3c24507a6d503'
  const feiWhaleAddress = '0x22fa8cc33a42320385cbd3690ed60a021891cb32'
  const fraxWhaleAddress = '0xc564ee9f21ed8a2d8e7e76c085740d5e4c5fafbe'
  const usdcAddress = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'
  const daiAddress = '0x6b175474e89094c44da98b954eedeac495271d0f'
  const fraxAddress = '0x853d955acef822db058eb8505911ed77f175b99e'
  const feiAddress = '0x956F47F50A910163D8BF957Cf5846D573E7f87CA'
  const seurAddress = '0xd71ecff9342a5ced620049e616c5035f1db98620'
  const ageurAddress = '0x1a7e4e63778b4f12a199c062f3efdd288afcbce8'

  const poolManagers = [
      '0xc9daabc677f3d1301006e723bd21c60be57a5915',
      '0xe9f183FC656656f1F17af1F2b0dF79b8fF9ad8eD',
      '0x53b981389Cfc5dCDA2DC2e903147B5DD0E985F44',
      '0x6b4eE7352406707003bC6f6b96595FD35925af48'
  ]

  const poolManagersMap = {
    [daiAddress]: '0xc9daabc677f3d1301006e723bd21c60be57a5915',
    [usdcAddress]: '0xe9f183FC656656f1F17af1F2b0dF79b8fF9ad8eD',
    [feiAddress]: '0x53b981389Cfc5dCDA2DC2e903147B5DD0E985F44',
    [fraxAddress]: '0x6b4eE7352406707003bC6f6b96595FD35925af48'
  }


  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  before(async function () {
    // Get the ContractFactory and Signers here.
    const Forex = await ethers.getContractFactory("SynthIBForex")
    const LPAdapter = await ethers.getContractFactory("LPAdapter")
    const AngleAdapter = await ethers.getContractFactory("AngleAdapter")
    ibEur = await ethers.getContractAt("IERC20", ibEurAddress)
    ibEurLP = await ethers.getContractAt("IERC20", ibEurLPAddress)
    susd = await ethers.getContractAt("IERC20", susdAddress)
    ibKrw = await ethers.getContractAt("IERC20", ibKRWAddress)
    usdc = await ethers.getContractAt("IERC20", usdcAddress)
    dai = await ethers.getContractAt("IERC20", daiAddress)
    frax = await ethers.getContractAt("IERC20", fraxAddress)
    fei = await ethers.getContractAt("IERC20", feiAddress)
    seur = await ethers.getContractAt("IERC20", seurAddress)
    ageur = await ethers.getContractAt("IERC20", ageurAddress)

    ;[owner, acc1] = await ethers.getSigners()

    forex = await Forex.deploy()
    await forex.deployed()

    lpAdapter = await LPAdapter.deploy(forex.address)
    await lpAdapter.deployed()

    angleAdapter = await AngleAdapter.deploy(lpAdapter.address, poolManagers)
    await angleAdapter.deployed()

    await ethers.provider.send("hardhat_setBalance", [ibEurWhaleAddress, '0x3635c9adc5dea00000' /* 1000Ether */]);
    await ethers.provider.send("hardhat_setBalance", [usdcWhaleAddress, '0x3635c9adc5dea00000' /* 1000Ether */]);
    await ethers.provider.send("hardhat_setBalance", [ibEurLPWhaleAddress, '0x3635c9adc5dea00000' /* 1000Ether */]);
    await ethers.provider.send("hardhat_setBalance", [fraxWhaleAddress, '0x3635c9adc5dea00000' /* 1000Ether */]);
    await ethers.provider.send("hardhat_setBalance", [feiWhaleAddress, '0x3635c9adc5dea00000' /* 1000Ether */]);
    await ethers.provider.send("hardhat_impersonateAccount", [ibEurWhaleAddress])
    await ethers.provider.send("hardhat_impersonateAccount", [ibEurLPWhaleAddress])
    await ethers.provider.send("hardhat_impersonateAccount", [susdWhaleAddress])
    await ethers.provider.send("hardhat_impersonateAccount", [usdcWhaleAddress])
    await ethers.provider.send("hardhat_impersonateAccount", [fraxWhaleAddress])
    await ethers.provider.send("hardhat_impersonateAccount", [feiWhaleAddress])
    ibEurWhale = await ethers.getSigner(ibEurWhaleAddress)
    ibEurLPWhale = await ethers.getSigner(ibEurLPWhaleAddress)
    susdWhale = await ethers.getSigner(susdWhaleAddress)
    usdcWhale = await ethers.getSigner(usdcWhaleAddress)
    fraxWhale = await ethers.getSigner(fraxWhaleAddress)
    feiWhale = await ethers.getSigner(feiWhaleAddress)
  })

  describe("Exchange", function () {
    it("Quote stables via Angle mint", async function () {

      const forUsdc = await calcMint(usdcAddress, 6, susdAddress)
      console.log('usdc -> susd: ' + Number(BigInt(forUsdc) / 10n ** 16n) / 100)

      const forDai = await calcMint(daiAddress, 18, ibEurAddress)
      console.log('dai -> ibEur: ' + Number(BigInt(forDai) / 10n ** 16n) / 100)

      const forFei = await calcMint(feiAddress, 18, ethers.constants.AddressZero)
      console.log('fei -> agEur: ' + Number(BigInt(forFei) / 10n ** 16n) / 100)

      const forFrax = await calcMint(fraxAddress, 18, ibEurLPAddress)
      console.log('frax -> ibEurLP: ' + Number(BigInt(forFrax) / 10n ** 16n) / 100)

    })

    it("Exchange stables via Angle mint", async function () {
      await usdc.connect(usdcWhale).approve(angleAdapter.address, ethers.constants.MaxUint256)
      await angleAdapter.connect(usdcWhale).swapUSDToIB(usdcAddress, ibEurAddress, 100_000n * 10n ** 6n, 0)
      console.log('usdc -> ibEur: ' + Number(BigInt(await ibEur.balanceOf(usdcWhaleAddress)) / 10n ** 16n) / 100)

      await dai.connect(usdcWhale).approve(angleAdapter.address, ethers.constants.MaxUint256)
      await angleAdapter.connect(usdcWhale).swapUSDToSynth(daiAddress, seurAddress, 100_000n * 10n ** 18n, 0)
      console.log('dai -> seur: ' + Number(BigInt(await seur.balanceOf(usdcWhaleAddress)) / 10n ** 16n) / 100)

      await fei.connect(feiWhale).approve(angleAdapter.address, ethers.constants.MaxUint256)
      await angleAdapter.connect(feiWhale).swapUSDToLP(feiAddress, ibEurLPAddress, 100_000n * 10n ** 18n, 0)
      console.log('fei -> ibEurLP: ' + Number(BigInt(await ibEurLP.balanceOf(feiWhaleAddress)) / 10n ** 16n) / 100)

      await frax.connect(fraxWhale).approve(angleAdapter.address, ethers.constants.MaxUint256)
      await angleAdapter.connect(fraxWhale).swapUSDToLP(fraxAddress, ibEurLPAddress, 100_000n * 10n ** 18n, 0)
      console.log('frax -> ibEurLP: ' + Number(BigInt(await ibEurLP.balanceOf(fraxWhaleAddress)) / 10n ** 16n) / 100)

      await angleAdapter.connect(usdcWhale).mintAgEurForUsd(usdcAddress, 100_000n * 10n ** 6n, 0)
      console.log('usdc -> agEur: ' + Number(BigInt(await ageur.balanceOf(usdcWhaleAddress)) / 10n ** 16n) / 100)

      await ageur.connect(usdcWhale).approve(angleAdapter.address, ethers.constants.MaxUint256)
      await angleAdapter.connect(usdcWhale).burnAgEurForUsd(fraxAddress, 50_000n * 10n ** 18n, 0)
      console.log('agEur -> frax: ' + Number(BigInt(await frax.balanceOf(usdcWhaleAddress)) / 10n ** 16n) / 100)
    })

    it("Quote stables via Angle burn", async function () {
      const forUsdc = await calcBurn(ibEurAddress,  usdcAddress)
      console.log('ibEur -> usdc: ' + Number(BigInt(forUsdc) / 10n ** 4n) / 100)

      const forDai = await calcBurn(ibEurLPAddress,  daiAddress)
      console.log('ibEurLP -> dai: ' + Number(BigInt(forDai) / 10n ** 16n) / 100)

      const forFei = await calcBurn(susdAddress,  feiAddress)
      console.log('susd -> fei: ' + Number(BigInt(forFei) / 10n ** 16n) / 100)

      const forFrax = await calcBurn(ethers.constants.AddressZero,  fraxAddress)
      console.log('agEur -> frax: ' + Number(BigInt(forFrax) / 10n ** 16n) / 100)

    })
  })

  calcMint = async (token, decimals, to) => {
    let inputData = ethers.utils.defaultAbiCoder.encode(["address", "address", "uint256", "address"],[lpAdapter.address, poolManagersMap[token] , 100_000n * 10n ** BigInt(decimals), to]);
    const payload = bytecodeMint.concat(inputData.slice(2));
    return BigInt(await ethers.provider.call({ data: payload, value: 10_000n * 10n ** 18n }))
  }

  calcBurn = async (from, toTokenName) => {
    let inputData = ethers.utils.defaultAbiCoder.encode(["address", "address", "uint256", "address"],[lpAdapter.address, poolManagersMap[toTokenName], 100_000n * 10n ** 18n, from]);
    const payload = bytecodeBurn.concat(inputData.slice(2));
    return BigInt(await ethers.provider.call({ data: payload, value: 10_000n * 10n ** 18n }))
  }
})