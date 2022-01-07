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

    uint8 constant fieldInitialGrade = 1; // 土地初始化等级
    uint8 constant fieldCount = 16; // 土地块数
    uint256 constant fieldPrice = 1 << 17; // 土地单价
    uint256 constant fieldUpgradePriceRate = 1 << 17; // 土地价格随等级增加
    uint256 constant fieldhighestGrade = 3; // 土地最高等级
    uint256 constant fieldRipePeriodRate = 15; // 土地成熟周期随等级增加
    uint256 constant seedhighestGrade = 3; // 种子等级

    // 种子列表
    uint256[12] seedIds = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

    // 种子等级对应关系
    mapping(uint256 => uint256) public seedIdGradeMapping;

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
        _initSeeds();
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
        _buyAllFieldByETH();
    }

    /**
     * 购买所有未购买的土地（代币）
     */
    function buyAllFieldByMyToken() public initField {
        _buyAllFieldByMyToken();
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
    function fieldAllUpgradeByETH() public payable {
        // 先购买
        _buyAllFieldByETH();
        uint256 amount = _fieldAllUpgrade();
        _refundExcessETH(amount);
    }

    /**
     * 升级所有土地（代币）
     */
    function fieldAllUpgradeByMyToken() public {
        // 先购买
        _buyAllFieldByMyToken();
        uint256 amount = _fieldAllUpgrade();
        _settlementMyToken(amount);
    }

    /**
     * 获取升级所有土地需要的金额
     */
    function _fieldAllUpgrade() private view returns (uint256) {
        Field[] memory fields = fieldOf[msg.sender];
        uint256 amount;
        for (uint256 i = 0; i < fields.length; i++) {
            for (uint256 j = fields[i].grade + 1; j <= fieldhighestGrade; j++) {
                amount += fieldUpgradePriceRate * fields[i].grade;
            }
            fields[i].grade = fieldhighestGrade;
            // 例如 ripePeriod = 24; 计算  ripePeriod =ripePeriod - ripePeriod * 15/100 * 2 => ripePeriod = 24 - 24*30/100 => ripePeriod = 17;
            fields[i].ripePeriod =
                fields[i].ripePeriod -
                fields[i].ripePeriod *
                (fieldRipePeriodRate / 100) *
                (fieldhighestGrade - 1);
        }
        return amount;
    }

    /**
     * 购买所有未购买的土地（原生币）
     */
    function _buyAllFieldByETH() private {
        uint256 amount = _addAllField();
        _refundExcessETH(amount);
    }

    /**
     * 购买所有未购买的土地（代币）
     */
    function _buyAllFieldByMyToken() private {
        uint256 amount = _addAllField();
        _settlementMyToken(amount);
    }

    /**
     * 获取升级土地需要的金额
     * @return 金额
     */
    function _fieldUpgrade(uint256 _index) private view returns (uint256) {
        require(_index + 1 <= fieldOf[msg.sender].length, "no index!");
        Field memory filed = fieldOf[msg.sender][_index];
        require(filed.grade <= fieldhighestGrade, "beyond grade limit!");
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

    /**
     * 初始化种子和等级关系
     */
    function _initSeeds() private {
        for (uint256 i = 0; i < seedIds.length; i++) {
            seedIdGradeMapping[seedIds[i]] = (i + 1) % (seedhighestGrade + 1);
        }
    }
}
