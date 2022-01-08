// SPDX-License-Identifier: MITls
pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract MyFram {
    // 土地
    struct Field {
        uint256 grade; // 土地等级
        uint256 seedId; // 种子编号
        uint256 ripePeriod; // 成熟周期
        uint256 sowTime; // 播种时间
    }

    // 果实
    struct Fruit {
        uint256 seedId; // 种子编号
        uint256 grade; // 等级
        uint256 pirce; // 价格
    }

    uint8 constant fieldInitialGrade = 1; // 土地初始化等级
    uint8 constant fieldCount = 16; // 土地块数
    uint256 constant fieldPrice = 0.1 ether; // 土地单价
    uint256 constant fieldUpgradePriceRate = 0.1 ether; // 土地价格随等级增加
    uint256 constant fieldhighestGrade = 3; // 土地最高等级
    uint256 constant fieldRipePeriodReduceRate = 15; // 土地成熟周期随等级减少（百分比）
    uint256 constant seedhighestGrade = 3; // 种子等级
    uint256 constant seedRipePeriodGradeIncreaseHours = 24; // 成熟周期种子随等级增加

    // 种子列表
    uint256[12] seedIds = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

    // 种子等级对应关系
    mapping(uint256 => uint256) public seedIdGradeMapping;

    // 收益地址
    address public earnings;
    // 代币地址
    address public myToken;
    // 合约拥有者
    address private owner;
    // 玩家地址对应的土地
    mapping(address => Field[]) public fieldOf;
    /// 初始化土地
    modifier initField() {
        if (0 == fieldOf[msg.sender].length) {
            _addField();
        }
        _;
    }
    /// 是否是合约的拥有者
    modifier isOwner() {
        require(msg.sender == owner, "Caller is not owner");
        _;
    }

    modifier canPlant(uint256 _seedId, uint256 _index) {
        // 存在 _index 对应的土地
        require(fieldOf[msg.sender].length > _index);
        // 种子等级大于等于土地
        require(
            seedIdGradeMapping[_seedId] >= fieldOf[msg.sender][_index].grade
        );
        // 土地尚未播种
        require(fieldOf[msg.sender][_index].sowTime == 0);
        _;
    }

    /**
     * 初始化函数
     */
    constructor(address _myToken) {
        myToken = _myToken;
        owner = msg.sender;
        _initSeeds();
    }

    /**
     * 设置代币地址
     */
    function setMyToken(address _myToken) public isOwner {
        myToken = _myToken;
    }

    /**
     * 设置收益地址
     */
    function setEarnings(address _earnings) public isOwner {
        earnings = _earnings;
    }

    /**
     * 购买所有未购买的土地（原生币）
     */
    function buyAllFieldByETH() public payable initField {
        _buyAllFieldByETH();
    }

    function buyOneFieldByETH() public payable initField {
        _buyOneFieldByETH();
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
        uint256 amount = _fieldAllUpgrade();
        _refundExcessETH(amount);
    }

    /**
     * 升级所有土地（代币）
     */
    function fieldAllUpgradeByMyToken() public {
        uint256 amount = _fieldAllUpgrade();
        if (amount != 0) {
            _settlementMyToken(amount);
        }
    }

    /**
     * 种植
     */
    function plant(uint256 _seedId, uint256 _index)
        public
        canPlant(_seedId, _index)
    {
        // 设置种植时间
        fieldOf[msg.sender][_index].sowTime = block.timestamp;
        // 计算成熟周期
        // 例如 ripePeriod = 24; 计算  ripePeriod =ripePeriod - ripePeriod * 15/100 * 2 => ripePeriod = 24 - 24*30/100 => ripePeriod = 17;
        uint256 _ripePeriod = seedRipePeriodGradeIncreaseHours *
            seedIdGradeMapping[_seedId];
        fieldOf[msg.sender][_index].ripePeriod =
            _ripePeriod -
            (_ripePeriod *
                fieldRipePeriodReduceRate *
                (fieldOf[msg.sender][_index].grade - 1)) /
            100;
    }

    /**
     * 一键种植
     */
    function plantAll() public {}

    /**
     * 卖出果实
     */
    function saleOne(uint256 _index) public {}

    /**
     * 一键卖出
     */
    function saleAll(uint256 _index) public {}

    /**
     * 加速
     */
    function speedUp(uint256 _index) public {}

    /**
     * 一键加速
     */
    function speedUpAll() public {}

    /**
    * 收获
     */
    function harvestAll() public{}

    /**
     * 获取升级所有土地需要的金额
     */
    function _fieldAllUpgrade() private returns (uint256) {
        Field[] memory fields = fieldOf[msg.sender];
        uint256 amount;
        for (uint256 i = 0; i < fields.length; i++) {
            for (uint256 j = fields[i].grade + 1; j <= fieldhighestGrade; j++) {
                amount += fieldUpgradePriceRate * fields[i].grade;
            }
            fieldOf[msg.sender][i].grade = fieldhighestGrade;
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
     * 购买一块土地（原生币）
     */
    function _buyOneFieldByETH() private {
        _addField();
        _refundExcessETH(fieldPrice);
    }

    /**
     * 购买所有未购买的土地（代币）
     */
    function _buyAllFieldByMyToken() private {
        uint256 amount = _addAllField();
        _settlementMyToken(amount);
    }

    /**
     * 购买一块土地（代币）
     */
    function _buyOneFieldByMyToken() private {
        _addField();
        _settlementMyToken(fieldPrice);
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
        uint256 amount = (fieldCount - fieldOfCount) * fieldPrice;
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
            seedIdGradeMapping[seedIds[i]] = (i % seedhighestGrade) + 1;
        }
    }
}
