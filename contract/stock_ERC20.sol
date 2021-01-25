// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "../../utils/Context.sol";
import "./stock_IERC20.sol";
import "../../math/SafeMath.sol";

/* 1.用于遍历的mapping=>data */
struct _balances2 { uint keyIndex; address payable myaddress; uint value; }
struct KeyFlag { uint key; bool deleted; }

struct itmap {
    mapping(uint => _balances2) data;
    KeyFlag[] keys;
    uint size;
}

library IterableMapping {
    //1.add
    function insert(itmap storage self, uint key,address payable _address,uint value) internal returns (bool replaced) {
        uint keyIndex = self.data[key].keyIndex;
        self.data[key].value = value;
        self.data[key].myaddress = _address;
        if (keyIndex > 0)
            return true;
        else {
            keyIndex = self.keys.length;
            self.keys.push();
            self.data[key].keyIndex = keyIndex + 1;
            self.keys[keyIndex].key = key;
            self.size++;
            return false;
        }
    }
    //2.delete
    function remove(itmap storage self, uint key) internal returns (bool success) {
        uint keyIndex = self.data[key].keyIndex;
        if (keyIndex == 0)
            return false;
        delete self.data[key];
        self.keys[keyIndex - 1].deleted = true;
        self.size --;
    }
    //3.update
    function update(itmap storage self, uint key, uint value) internal returns (bool success) {
        self.data[key].value = value;
        success = true;
    }
    //4.search
    function iterate_get(itmap storage self, uint keyIndex) internal view returns (uint key,address payable myaddress,uint value) {
        key = self.keys[keyIndex].key;
        myaddress = self.data[key].myaddress;
        value = self.data[key].value;
    }


    function contains(itmap storage self, uint key) internal view returns (bool) {
        return self.data[key].keyIndex > 0;
    }
    function iterate_start(itmap storage self) internal view returns (uint keyIndex) {
        return iterate_next(self, uint(-1));
    }
    function iterate_valid(itmap storage self, uint keyIndex) internal view returns (bool) {
        return keyIndex < self.keys.length;
    }
    function iterate_next(itmap storage self, uint keyIndex) internal view returns (uint r_keyIndex) {
        keyIndex++;
        while (keyIndex < self.keys.length && self.keys[keyIndex].deleted)
            keyIndex++;
        return keyIndex;
    }
}


contract stock_ERC20 is Context, stock_IERC20 {
    itmap data;
    using IterableMapping for itmap;
    using SafeMath for uint256;
    
    mapping (address => uint) public _ReverseSearch;
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor () public payable{
        _name = "music";
        _symbol = "m";
        _decimals = 18;
        _mint(msg.sender, 100);
        
        data.insert(1,msg.sender, 100);
        _ReverseSearch[msg.sender] = 1;
    }
    /*************************************/

    /* ##查看转账的金额、次数##*/
    uint[] public TfArray;
    function TfArrayAll() public view returns(uint[] memory){
        return TfArray;
    }

    
    mapping(address => uint256) public price;
    /* 1.设置价格 */
    function setPrice(uint256 _Price) external returns(bool){
        price[msg.sender] = _Price;
        return true;
    }
    /* 2.购买股份 */
    function buy(address payable _from,uint256 _amount) external payable returns(bool) {
        uint256 totalmoney = price[_from]*_amount;
        
        require(msg.value == totalmoney,"请支付相应的金额购买股份");
        _transfer(_from, msg.sender, _amount);
        _from.transfer(totalmoney);
        return true;
    }
    /* 3.查询余额(ETH) */
    function ThisEthBalance() public view returns(uint256){
        return address(this).balance;
    }
    function EthBalance(address _address) public view returns(uint256){
        return _address.balance;
    }
    /* 4.收益分红 */
    function getDividends() public returns (bool _bool) {
        /* ##限制:当合约的余额>=总发行量才能分红(单位：wei)## */
        require(address(this).balance >= _totalSupply,"err:合约余额未达到分红的条件");
        uint NOW_INCOME = address(this).balance;
        for (
            uint i = data.iterate_start();
            data.iterate_valid(i);
            i = data.iterate_next(i)
        ) {
 
            (, address payable myaddress, uint value) = data.iterate_get(i);
            /* 5.根据股份占比-计算分红的金额-按倍数提出 */
            uint256 rate = NOW_INCOME/_totalSupply;
            /* ##eg:rate=330/100=3(向下取整，只能提取300)## */
            myaddress.transfer(rate*value);
            TfArray.push(rate*value); 
            _bool = true;
                         
        }
    }
    /************************************/
    
    function name() public view returns (string memory) {
        return _name;
    }
    function symbol() public view returns (string memory) {
        return _symbol;
    }
    function decimals() public view returns (uint8) {
        return _decimals;
    }
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    function transfer(address payable recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }
    /* 5.委托出售 */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    function transferFrom(address sender, address payable recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }
    /* ##增加减少出售 ## */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }
    
    
    function _transfer(address sender, address payable recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
        
        /* 1.sender */
            data.update(_ReverseSearch[sender], _balances[sender]);
        /* 2.recipient */
        if(_ReverseSearch[recipient] == 0){
            /* ##注：先insert的话size会+1## */
            _ReverseSearch[recipient] = (data.size)+1;
            data.insert((data.size)+1, recipient, _balances[recipient]);
        } else{
            data.update(_ReverseSearch[recipient], _balances[recipient]);
        }
        
        
    }
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    function _setupDecimals(uint8 decimals_) internal virtual {
        _decimals = decimals_;
    }
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}
