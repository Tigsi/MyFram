// SPDX-License-Identifier: MITls
pragma solidity ^0.8.0;
import "./common/BaseUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract MyFram is BaseUpgradeable {
    struct Field {
        uint256 grade; // 土地等级
        uint256 seedId; // 种子编号
        uint256 ripePeriod; // 成熟周期
        uint256 sowTime; // 播种时间
    }

    uint8 constant fieldInitialGrade = 1;
    uint8 constant fieldCount = 16;
    uint256 constant fieldPrice = 1 << 17;
    uint256 constant fieldUpgradePriceRate = 1 << 17;

    // 收益地址
    address public earnings;
    // 代币地址
    address public myToken;
    // 玩家地址对应的土地
    mapping(address => Field[]) public fieldOf;
    // 初始化土地
    modifier initField() {
        if (0 == fieldOf[msg.sender].length) {
            _addField();
        }
        _;
    }

    /**
     * 初始化函数
     */
    function initialize(address _myToken) public initializer {
        BaseUpgradeable.__Base_init();
        myToken = _myToken;
    }

    /**
     * 设置代币地址
     */
    function setMyToken(address _myToken) public onlyAdmin {
        myToken = _myToken;
    }

    /**
     * 设置收益地址
     */
    function setEarnings(address _earnings) public onlyAdmin {
        earnings = _earnings;
    }

    /**
     * 购买所有未购买的土地（原生币）
     */
    function buyAllFieldByETH() public payable initField {
        uint256 amount = _addAllField();
        _refundExcessETH(amount);
    }

    /**
     * 购买所有未购买的土地（代币）
     */
    function buyAllFieldByMyToken() public initField {
        uint256 amount = _addAllField();
        _settlementMyToken(amount);
    }

    /**
     * 升级土地
     */
    function fieldUpgradeByETH(uint256 _index) public payable {
        uint256 amount = _fieldUpgrade(_index);
        _refundExcessETH(amount);
    }

    /**
     * 升级土地（代币）
     */
    function fieldUpgradeByMyToken(uint256 _index) public payable {
        uint256 amount = _fieldUpgrade(_index);
        _settlementMyToken(amount);
    }

    /**
     * 升级所有土地
     */
    function fieldAllUpgradeByETH() public payable {}

    /**
     * 升级所有土地（代币）
     */
    function fieldAllUpgradeByMyToken() public {}

    /**
     * 获取升级土地需要的金额
     * @return 金额
     */
    function _fieldUpgrade(uint256 _index) private view returns (uint256) {
        require(_index + 1 <= fieldOf[msg.sender].length, "no index !");
        Field memory filed = fieldOf[msg.sender][_index];
        uint256 grade = filed.grade;
        uint256 amount = (grade + 1) * fieldUpgradePriceRate;
        return amount;
    }

    /**
     * 添加土地
     */
    function _addField() private {
        Field memory field;
        field.grade = fieldInitialGrade;
        fieldOf[msg.sender].push(field);
    }

    /**
     * 添加未添加的土地
     */
    function _addAllField() private returns (uint256) {
        uint256 fieldOfCount = fieldOf[msg.sender].length;
        uint256 amount = fieldCount * fieldPrice;
        for (uint256 i = fieldOfCount; i < fieldCount; i++) {
            _addField();
        }
        return amount;
    }

    /**
     * 退款
     */
    function _refundExcessETH(uint256 _amount) private {
        require(msg.value >= _amount, "no enough payfor!");
        if (msg.value > _amount) {
            payable(msg.sender).transfer(msg.value - _amount);
        }
    }

    /**
     * 结算
     */
    function _settlementMyToken(uint256 _amount) private {
        require(msg.value >= _amount, "no enough payfor!");
        IERC20Upgradeable(myToken).transferFrom(msg.sender, earnings, _amount);
    }
}
