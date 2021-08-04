// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;
import "./PriceLibrary.sol";
import "./SafeERC20.sol";
import './IERC20.sol';
import './Ownable.sol';


contract DomInvitation is Ownable {
    using SafeMath for uint256;
    struct user {
        uint256 id;
        uint256 level;
        uint256 burn;
        address referrer;
    }

    uint256 public userCount;
    address public primaryAddr = 0x5baa5EA4a9C9E17cF3c71Da7a0E93e615b4B7a71;
    
    address public factory;
    address public dead = 0x000000000000000000000000000000000000dEaD;

    IERC20 public pToken;
    IERC20 public domToken;
    IERC20 public usdtToken;

    uint256[2] public marketList = [30, 25];
    uint256[6] public levelList = [0, 100*1e18, 200*1e18, 200*1e18, 500*1e18, 500*1e18];
    
    mapping(address => user) public Users;
    mapping(uint256 => address) public index2User;
    mapping(uint256 => uint256[20]) levelReferMap;

    event Register(address indexed _userAddr, address indexed _referrer);
    event Promote(address indexed _userAddr, uint256 level);
    event Burn(address indexed _userAddr, uint256 _amount);
    event Redeem(address indexed _userAddr, uint256 _power);

    constructor(IERC20 _pToken, IERC20 _domToken) public {
        pToken = _pToken;
        domToken = _domToken;

        userCount = userCount.add(1);
        Users[primaryAddr].id = userCount;
        index2User[userCount] = primaryAddr;
        level_init();
        emit Register(primaryAddr, address(0));
    }

    function level_init() internal {
        // vip level 0
        levelReferMap[0] = [0, 0];
        // vip level 1
        levelReferMap[1] = [15, 10];
        // vip level 2
        levelReferMap[2] = [16, 11];
        // vip level 3
        levelReferMap[3] = [18, 13];
        // vip level 4
        levelReferMap[4] = [20, 15];
        // vip level 5
        levelReferMap[5] = [25, 20];
    }

    function setMarketList(uint256[2] memory _marketList) onlyOwner public {
        marketList = _marketList;
    }

    function setLevelRewardList(uint256 _levelId, uint256[20] memory _levelRewardList) onlyOwner public {
        levelReferMap[_levelId] = _levelRewardList;
    }

    function setPToken(IERC20 _pToken) onlyOwner public {
        pToken = _pToken;
    }

    function setDomToken(IERC20 _domToken) onlyOwner public {
        domToken = _domToken;
    }

    function setFactory(address _factory, IERC20 _usdtToken) onlyOwner public {
        usdtToken = _usdtToken;
        factory = _factory;
    }

    function register(address _referrer) public {
        require(!Address.isContract(msg.sender), "contract address is forbidden");
        require(!isExists(msg.sender), "user exists");
        require(isExists(_referrer), "referrer not exists");
        user storage regUser = Users[msg.sender];
        userCount = userCount.add(1);
        regUser.id = userCount;
        index2User[userCount] = msg.sender;
        regUser.referrer = _referrer;
        
        
        emit Register(msg.sender, _referrer);
    }

    function isExists(address _userAddr) view public returns (bool) {
        return Users[_userAddr].id != 0;
    }

    function promote(uint256 _level) public {
        require(isExists(msg.sender), "user not exists");
        require(Users[msg.sender].level < _level, "level is lower than the last one");
        require(_level <= 5, "level exceeds");
        (uint inAmount, uint outAmount) = PriceLibrary.price(factory, address(usdtToken), address(domToken));
        require(outAmount!=0,"Invalid price");
        uint256 levelAmount = 0;
        // due to promote more than one level
        for(uint256 i = Users[msg.sender].level+1; i <= _level; i++) {
            levelAmount = levelAmount.add(levelList[i]);
        }
        uint256 burnAmount = outAmount.mul(levelAmount).div(inAmount);
        require(domToken.balanceOf(msg.sender) >= burnAmount, "dom is not enough");
        marketReward(msg.sender, burnAmount);
        Users[msg.sender].level = _level;
        Users[msg.sender].burn = Users[msg.sender].burn.add(burnAmount);
        emit Promote(msg.sender, _level);
    }

    function referReward(address _userAddr, uint256 _power) external {
        require(msg.sender == address(pToken), "only pToken can call referReward");
        address preAddr = Users[_userAddr].referrer;
        for(uint256 i = 0; i < 2; i++) {
            if(preAddr == address(0)) {
                break;
            }
            uint256 rewardRate = levelReferMap[Users[preAddr].level][i];
            if (rewardRate > 0){
                pToken.mint(preAddr, _power.mul(rewardRate).div(100));
            }
            preAddr = Users[preAddr].referrer;
        }
        emit Promote(msg.sender, _power);
    }

    function redeemPower(address _userAddr, uint256 _power) external {
        require(msg.sender == address(pToken), "only pToken can call redeemPower");
        address preAddr = Users[_userAddr].referrer;
        for(uint256 i = 0; i < 2; i++) {
            if(preAddr == address(0)) {
                break;
            }
            uint256 rewardRate = levelReferMap[Users[preAddr].level][i];
            uint256 bal = pToken.balanceOf(preAddr);
            uint256 rew = _power.mul(rewardRate).div(100);
            if (rew > bal) {
                pToken.burn(preAddr, bal);
            } else {
                pToken.burn(preAddr, rew);
            }
            preAddr = Users[preAddr].referrer;
        }
    }

    function marketReward(address _userAddr, uint256 _amount) internal{
        
        domToken.transferFrom(msg.sender, dead, _amount);
        emit Burn(msg.sender, _amount);
    }
}
