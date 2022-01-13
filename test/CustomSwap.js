// This is an exmaple test file. Hardhat will run every *.js file in `test/`,
// so feel free to add new ones.

// Hardhat tests are normally written with Mocha and Chai.

// We import Chai to use its asserting functions here.
const { expect } = require("chai")
const { ethers } = require('hardhat')
const { utils : { Interface }} = ethers

const synthIBSwapsInterface = new Interface([
  "function swapSynth(address synthIn, address synthOut, uint amount) internal returns (uint)",
]);

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

  let SynthIBSwaps, CurveLPSwaps, AngleSwaps, CurveSwaps
  let owner
  let ibEurWhale
  let ibEurLPWhale
  let susdWhale
  let usdcWhale, feiWhale, fraxWhale
  let ibEur
  let ibEurLP
  let ibKrw
  let susd, usdc, dai, frax, fei, seur, ageur
  let anglePoolStorageDeployer
  let synthIBPoolStorageDeployer
  let synthIBPoolStorage
  let anglePoolStorage
  let customSwap

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
  const anglePoolStorageDeployerAddress = '0x092D703AF2B1b566de68872008F904e320D04659'
  const synthIBPoolStorageDeployerAddress = '0xEe2Cc24dc2E3D545E809C867710A2C0128DAE338'

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
    const CurveSwapsLib = await ethers.getContractFactory("CurveSwaps")
    CurveSwaps = await CurveSwapsLib.deploy()
    await CurveSwaps.deployed()
    // Get the ContractFactory and Signers here.
    const SynthIBSwapsContract = await ethers.getContractFactory("SynthIBSwaps", { libraries: { CurveSwaps: CurveSwaps.address } })
    SynthIBSwaps = await SynthIBSwapsContract.deploy()
    await SynthIBSwaps.deployed()

    const CurveLPSwapsContract = await ethers.getContractFactory("CurveLPSwaps", { libraries: { SynthIBSwaps: SynthIBSwaps.address } })
    CurveLPSwaps = await CurveLPSwapsContract.deploy()
    await CurveLPSwaps.deployed()



    const CustomSwapContract = await ethers.getContractFactory("CustomSwap")
    customSwap = await CustomSwapContract.deploy()
    await customSwap.deployed()


    const AngleSwapsContract = await ethers.getContractFactory("AngleSwaps")
    const AnglePoolStorage = await ethers.getContractFactory("AnglePoolStorage")
    const SynthIBPoolStorage = await ethers.getContractFactory("SynthIBPoolStorage")
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

    SynthIBSwaps = await SynthIBSwapsContract.deploy()
    await SynthIBSwaps.deployed()

    AngleSwaps = await AngleSwapsContract.deploy()
    await AngleSwaps.deployed()

    await ethers.provider.send("hardhat_setBalance", [ibEurWhaleAddress, '0x3635c9adc5dea00000' /* 1000Ether */]);
    await ethers.provider.send("hardhat_setBalance", [usdcWhaleAddress, '0x3635c9adc5dea00000' /* 1000Ether */]);
    await ethers.provider.send("hardhat_setBalance", [ibEurLPWhaleAddress, '0x3635c9adc5dea00000' /* 1000Ether */]);
    await ethers.provider.send("hardhat_setBalance", [fraxWhaleAddress, '0x3635c9adc5dea00000' /* 1000Ether */]);
    await ethers.provider.send("hardhat_setBalance", [feiWhaleAddress, '0x3635c9adc5dea00000' /* 1000Ether */]);
    await ethers.provider.send("hardhat_setBalance", [anglePoolStorageDeployerAddress, '0x3635c9adc5dea00000' /* 1000Ether */]);
    await ethers.provider.send("hardhat_setBalance", [synthIBPoolStorageDeployerAddress, '0x3635c9adc5dea00000' /* 1000Ether */]);

    await ethers.provider.send("hardhat_impersonateAccount", [ibEurWhaleAddress])
    await ethers.provider.send("hardhat_impersonateAccount", [ibEurLPWhaleAddress])
    await ethers.provider.send("hardhat_impersonateAccount", [susdWhaleAddress])
    await ethers.provider.send("hardhat_impersonateAccount", [usdcWhaleAddress])
    await ethers.provider.send("hardhat_impersonateAccount", [fraxWhaleAddress])
    await ethers.provider.send("hardhat_impersonateAccount", [feiWhaleAddress])
    await ethers.provider.send("hardhat_impersonateAccount", [anglePoolStorageDeployerAddress])
    await ethers.provider.send("hardhat_impersonateAccount", [synthIBPoolStorageDeployerAddress])

    ibEurWhale = await ethers.getSigner(ibEurWhaleAddress)
    ibEurLPWhale = await ethers.getSigner(ibEurLPWhaleAddress)
    susdWhale = await ethers.getSigner(susdWhaleAddress)
    usdcWhale = await ethers.getSigner(usdcWhaleAddress)
    fraxWhale = await ethers.getSigner(fraxWhaleAddress)
    feiWhale = await ethers.getSigner(feiWhaleAddress)
    anglePoolStorageDeployer = await ethers.getSigner(anglePoolStorageDeployerAddress)
    synthIBPoolStorageDeployer = await ethers.getSigner(synthIBPoolStorageDeployerAddress)
    anglePoolStorage = await AnglePoolStorage.connect(anglePoolStorageDeployer).deploy()
    await anglePoolStorage.addPoolManagers(poolManagers)
    AngleSwaps = await AngleSwapsContract.deploy()

    synthIBPoolStorage = await SynthIBPoolStorage.connect(synthIBPoolStorageDeployer).deploy()
  })

  describe("Exchange", function () {
    it("Quote stables via Angle mint/burn", async function () {

      const agEurReceived = await AngleSwaps.quoteMint(usdcAddress, 100_000n * 10n ** 6n)
      console.log('usdc -> agEur: ' + Number(BigInt(agEurReceived) / 10n ** 16n) / 100)

      const usdcReceived = await AngleSwaps.quoteBurn(usdcAddress, agEurReceived)
      const contracts = [SynthIBSwaps.address, SynthIBSwaps.address]
      console.log('agEur -> usdc: ' + Number(BigInt(usdcReceived) / 10n ** 4n) / 100)
      let data1 = SynthIBSwaps.interface.encodeFunctionData('quoteSynth', [susdAddress, seurAddress, 1000n * 10n ** 18n])
      let data2 = SynthIBSwaps.interface.encodeFunctionData('quoteSynth', [seurAddress, susdAddress, 1000n * 10n ** 18n])
      data2 = data2.substring(0, data2.length - 64)
      const res = await customSwap.callStatic.viewMulticall(contracts, [data1, data2]);
      console.log(res)
    })

    it("Exchange susd -> seur -> susd", async function () {
      let data1 = synthIBSwapsInterface.encodeFunctionData('swapSynth', [susdAddress, seurAddress, 1000n * 10n ** 18n])
      let data2 = synthIBSwapsInterface.encodeFunctionData('swapSynth', [seurAddress, susdAddress, 1000n * 10n ** 18n])
      data2 = data2.substring(0, data2.length - 64)
      const contracts = [SynthIBSwaps.address, SynthIBSwaps.address]

      const before = BigInt(await susd.balanceOf(susdWhaleAddress))
      await susd.connect(susdWhale).approve(customSwap.address, ethers.constants.MaxUint256)
      const tx = await customSwap.connect(susdWhale).multicall(contracts, [data1, data2]);
      const after = BigInt(await susd.balanceOf(susdWhaleAddress))
      console.log({before, after})
      console.log(Number((1000n * 10n ** 18n - (before - after)) / 10n ** 16n ) / 100)

      console.log((await tx.wait()).gasUsed)
    })
  })
})