// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// Open Zeppelin libraries for controlling upgradability and access.
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IWorld {
    function userSettlements(uint256 val) external view returns (address);
    function getUserSettlements(uint256[] calldata ownerTokenIds) external view returns (address[] memory res);
    function batchTransferResources(address to, string[] calldata resourcesNames, uint256[] calldata amounts) external;
    function resourcesMap(string calldata) external view returns (address);
    function bannerContract() external view returns (address);
}

interface ISettlement {
    function massUpdate() external;
    function buildingMap(string calldata buildingName) external view returns (address);
    function addDelegate(address _governorAddress) external;
    function removeDelegates() external;
}

interface IBuilding {
    function workers() external view returns (uint256 workersAmount);
}

//Update OwnableUpgradeable to AccessControl
contract MPool is Initializable, UUPSUpgradeable, AccessControlEnumerableUpgradeable {

    IWorld public world;

    IERC721 public flag;
    mapping(uint => address) public flagOwners;

    uint[] public flags;
    mapping(uint => uint) public flagsIndex;

    IERC20 public wood;
    IERC20 public food;
    IERC20 public copper;

    mapping(uint => address) public flagsSettlement;

    mapping(uint => address) public flagsFarm;
    mapping(uint => address) public flagsLumbermill;
    mapping(uint => address) public flagsMines;
    mapping(uint => address) public flagsWeaponFactory;

    function initialize(address _worldAddr) public initializer {
        world = IWorld(_worldAddr);
        flag = IERC721(world.bannerContract());

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        food = IERC20(world.resourcesMap("FOOD"));
        wood = IERC20(world.resourcesMap("WOOD"));
        copper = IERC20(world.resourcesMap("COPPER"));
    }


    function sendFlag(uint _id) external {
        require(flag.ownerOf(_id) == msg.sender, "Wrong owner");
        require(flag.isApprovedForAll(msg.sender, address(this)) || flag.getApproved(_id) == address(this), "Flag not approveed");


        ISettlement settlement = ISettlement(world.userSettlements(_id));

        flagsSettlement[_id] = address(settlement);

        flagsFarm[_id] = settlement.buildingMap("FARM");
        flagsLumbermill[_id] = settlement.buildingMap("LUMBERMILL");
        flagsMines[_id] = settlement.buildingMap("MINES");
        flagsWeaponFactory[_id] = settlement.buildingMap("WEAPON_FACTORY");

        require(IERC20(flagsFarm[_id]).transferFrom(msg.sender, address(this), 100 ether), "Fail transfer Farm");
        require(IERC20(flagsLumbermill[_id]).transferFrom(msg.sender, address(this), 100 ether), "Fail transfer Lumbermill");
        require(IERC20(flagsMines[_id]).transferFrom(msg.sender, address(this), 100 ether), "Fail transfer Mines");
        require(IERC20(flagsWeaponFactory[_id]).transferFrom(msg.sender, address(this), 100 ether), "Fail transfer WeaponFactory");


        flag.safeTransferFrom(msg.sender, address(this), _id);
        flagOwners[_id] = msg.sender;

        flags.push(_id);
        flagsIndex[_id] = flags.length;

        settlement.removeDelegates();
        settlement.addDelegate(msg.sender);
    }


    function returnFlag(uint _id) external {
        require(flag.ownerOf(_id) == address(this));
        require(flagOwners[_id] == msg.sender);


        require(IERC20(flagsFarm[_id]).transfer(msg.sender, 100 ether));
        require(IERC20(flagsLumbermill[_id]).transfer(msg.sender, 100 ether));
        require(IERC20(flagsMines[_id]).transfer(msg.sender, 100 ether));
        require(IERC20(flagsWeaponFactory[_id]).transfer(msg.sender, 100 ether));

        delete flagOwners[_id];


        flags[flagsIndex[_id] - 1] = flags[flags.length - 1];
        flagsIndex[flags[flags.length - 1]] = flagsIndex[_id];
        flags.pop();

        delete flagsIndex[_id];

        flag.safeTransferFrom(address(this), msg.sender, _id);
    }

    function updateSettlementAddr(uint _flagId) external  {
        flagsSettlement[_flagId] = world.userSettlements(_flagId);

        ISettlement settlement = ISettlement(flagsSettlement[_flagId]);

        flagsFarm[_flagId] = settlement.buildingMap("FARM");
        flagsLumbermill[_flagId] = settlement.buildingMap("LUMBERMILL");
        flagsMines[_flagId] = settlement.buildingMap("MINES");
        flagsWeaponFactory[_flagId] = settlement.buildingMap("WEAPON_FACTORY");
    }

    function harvestAllFlags() external {
        for (uint i = 0; i < flags.length; i++) {
            ISettlement(world.userSettlements(flags[i])).massUpdate();
        }
    }

    function harvest(uint[] calldata _ids) external {
        for (uint i = 0; i < _ids.length; i++) {
            ISettlement(world.userSettlements(_ids[i])).massUpdate();
        }
    }

    function depositAll() external {
        uint mFood;
        uint mWood;
        uint mCopper;

        (mFood, mWood, mCopper) = calculateResForSettlement();

        if (mFood > 0) {
            for (uint i = 0; i < flags.length; i++) {
                uint lumbermillWorkers = IBuilding(flagsLumbermill[flags[i]]).workers() / 1 ether;
                uint minesWorkers = IBuilding(flagsMines[flags[i]]).workers() / 1 ether;
                uint wFactoryWorkers = IBuilding(flagsWeaponFactory[flags[i]]).workers() / 1 ether;

                uint minDeposit = calculateMinDeposit(mFood, mWood, mCopper, lumbermillWorkers, minesWorkers, wFactoryWorkers);

                string[] memory _r = new string[](1);
                _r[0] = "FOOD";

                uint[] memory _v = new uint[](1);
                _v[0] = minDeposit * lumbermillWorkers;

                world.batchTransferResources(flagsLumbermill[flags[i]], _r, _v);

                if (mWood > 0) {
                    _r = new string[](2);
                    _r[0] = "FOOD";
                    _r[1] = "WOOD";

                    _v = new uint[](2);
                    _v[0] = minDeposit * minesWorkers;
                    _v[1] = _v[0];

                    world.batchTransferResources(flagsMines[flags[i]], _r, _v);
                }

                if (mCopper > 0) {
                    _r = new string[](3);
                    _r[0] = "FOOD";
                    _r[1] = "WOOD";
                    _r[2] = "COPPER";

                    _v = new uint[](3);
                    _v[0] = minDeposit * wFactoryWorkers;
                    _v[1] = _v[0];
                    _v[2] = _v[0];

                    world.batchTransferResources(flagsWeaponFactory[flags[i]], _r, _v);
                }


            }
        }


    }

    function calculateResForSettlement() public view returns (uint, uint, uint) {
        uint mFood = food.balanceOf(address(this)) / flags.length;
        uint mWood = wood.balanceOf(address(this)) / flags.length;
        uint mCopper = copper.balanceOf(address(this)) / flags.length;

        return (mFood, mWood, mCopper);
    }

    function calculateMinDeposit(uint _mFood, uint _mWood, uint _mCopper, uint _lWorkers, uint _mWorkers, uint _wFactoryWorkers) public pure returns(uint) {
        if (_mFood == 0) return 0;

        if (_mWood == 0) {
            _mWorkers = 0;
            _wFactoryWorkers = 0;
        }

        if (_mCopper == 0) {
            _wFactoryWorkers = 0;
        }


        _mFood = _lWorkers > 0  ? _mFood / (_lWorkers + _mWorkers + _wFactoryWorkers) : 0;
        _mWood = _mWorkers > 0  ? _mWood / (_mWorkers + _wFactoryWorkers) : 0;
        _mCopper = _wFactoryWorkers > 0 ? _mCopper / _wFactoryWorkers : 0;

        uint minDep = _mFood;

        minDep = _mWood > 0 && minDep < _mWood ? _mWood : minDep;
        minDep = _mCopper > 0 && minDep < _mCopper ? _mCopper : minDep;

        return minDep;
    }



    function setWorldAddr(address _worldAddr) external onlyRole(DEFAULT_ADMIN_ROLE) {
        world = IWorld(_worldAddr);

        flag = IERC721(world.bannerContract());

        food = IERC20(world.resourcesMap("FOOD"));
        wood = IERC20(world.resourcesMap("WOOD"));
        copper = IERC20(world.resourcesMap("COPPER"));
    }


    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external view returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data) external view returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    ///@dev required by the OZ UUPS module
    function _authorizeUpgrade(address) internal virtual override(UUPSUpgradeable) {
        _checkRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }


}
