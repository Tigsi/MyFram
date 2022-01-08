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
        uint256 ripeAddition; // 成熟速度加成
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
    uint256 constant speedUpOnecNeedPrice = 0.1 ether; // 加速一次单价
    uint256 constant speedUpOnecNeedHours = 12 hours; // 加速一减少时间
    uint256 constant fruitGradeOneDiffPrice = 0.1 ether; // 果实一级的价格差值
    uint256 constant fieldhighestGrade = 3; // 土地最高等级
    uint256 constant fieldRipePeriodReduceRate = 15; // 土地成熟周期随等级减少（百分比）
    uint256 constant seedhighestGrade = 3; // 种子等级
    uint256 constant seedRipePeriodGradeIncreaseHours = 24 hours; // 成熟周期种子随等级增加

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
    // 玩家地址对应的果实
    mapping(address => Fruit[]) public firuitOf;
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

    modifier canBuyField() {
        require(fieldOf[msg.sender].length + 1 <= fieldCount, "complete buy!");
        _;
    }

    modifier canSpeedUp(uint256 _index) {
        require(fieldOf[msg.sender].length > _index);
        // 确保土地已经播种
        require(fieldOf[msg.sender][_index].sowTime != 0, "no so!");
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
    function buyAllFieldByETH() public payable initField canBuyField {
        _buyAllFieldByETH();
    }

    function buyOneFieldByETH() public payable initField canBuyField{
        _buyOneFieldByETH();
    }

    /**
     * 购买所有未购买的土地（代币）
     */
    function buyAllFieldByMyToken() public initField canBuyField{
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
        _plant(_seedId, _index);
    }

    /**
     * 一键种植
     */
    function plantAll(uint256[] memory _seedIds) public {
        for (uint256 i = 0; i < _seedIds.length; i++) {
            for (uint256 j = 0; j < fieldOf[msg.sender].length; j++) {
                // 没有种植和符合等级
                if (
                    fieldOf[msg.sender][j].sowTime == 0 &&
                    fieldOf[msg.sender][j].grade ==
                    seedIdGradeMapping[_seedIds[i]]
                ) {
                    _plant(_seedIds[i], j);
                }
            }
        }
    }

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
    function speedUpOneByETH(uint256 _index) public payable canSpeedUp(_index) {
        require(msg.value >= speedUpOnecNeedPrice, "no enough payfor!");
        Field memory field = fieldOf[msg.sender][_index];
        uint256 diff = block.timestamp - field.sowTime;
        require(diff+field.ripeAddition <  field.ripePeriod,"no need speed!");
        fieldOf[msg.sender][_index].ripeAddition =
            fieldOf[msg.sender][_index].ripeAddition +
            speedUpOnecNeedHours;
        _refundExcessETH(speedUpOnecNeedPrice);
    }

    /**
     * 一键加速
     */
    function speedUpAll() public payable {
        uint256 _amount;
        Field[] memory fields = fieldOf[msg.sender];
        for (uint256 i = 0; i < fields.length; i++) {
            Field memory field = fields[i];
            if (field.sowTime != 0) {
                uint256 diff = block.timestamp - field.sowTime;
                uint256 speedTimes = (field.ripePeriod - diff) /
                    speedUpOnecNeedHours;
                if ((field.ripePeriod - diff) % speedUpOnecNeedHours != 0) {
                    speedTimes++;
                }
                fieldOf[msg.sender][i].ripeAddition =
                    speedTimes *
                    speedUpOnecNeedHours;
                _amount += speedTimes * speedUpOnecNeedPrice;
            }
        }
        _refundExcessETH(_amount);
    }

    /**
     * 收获
     */
    function harvestAll() public {
        Field[] memory fields = fieldOf[msg.sender];
        bool ripe;
        for (uint256 i = 0; i < fields.length; i++) {
            Field memory field = fields[i];
            uint256 diff = block.timestamp - field.sowTime;
            if (diff+field.ripeAddition >=  field.ripePeriod) {
                ripe = true;
                _addFruit(
                    seedIdGradeMapping[field.seedId],
                    field.grade,
                    fruitGradeOneDiffPrice * field.grade
                );
                _initNoBaseField(i);
            }
        }
        require(ripe, "no ripe!");
    }

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

    function _plant(uint256 _seedId, uint256 _index) private {
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

        fieldOf[msg.sender][_index].seedId = _seedId;
    }

    /**
     * 初始化土地
     */
    function _initNoBaseField(uint256 _index) private {
        fieldOf[msg.sender][_index].seedId = 0;
        fieldOf[msg.sender][_index].ripePeriod = 0;
        fieldOf[msg.sender][_index].sowTime = 0;
        fieldOf[msg.sender][_index].ripeAddition = 0;
    }

    /**
     * 添加果实
     */
    function _addFruit(
        uint256 _seedId,
        uint256 _grade,
        uint256 _pirce
    ) private {
        Fruit memory fruit;
        fruit.grade = _grade;
        fruit.pirce = _pirce;
        fruit.seedId = _seedId;
        firuitOf[msg.sender].push(fruit);
    }
}