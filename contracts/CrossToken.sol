pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Detailed.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/**
 * @title SimpleToken
 * @dev Very simple ERC20 Token example, where all tokens are pre-assigned to the creator.
 * Note they can later distribute these tokens as they wish using `transfer` and other
 * `ERC20` functions.
 */
contract CrossToken is ERC20Detailed {
    using SafeMath for uint256;
    uint8 public constant DECIMALS = 18;
    uint256 public constant INITIAL_SUPPLY = 10000 * (10 ** uint256(DECIMALS));
    uint256 public constant STATE_CHANNEL_LOCK_TIME = 10;

    event ChannelLocked(address indexed owner, uint256 value);
    event ChannelUnlocked(address indexed owner, uint256 value);
    event ChannelOpened(address indexed from,address indexed to, uint256 value);
    event ChannelFixed(address indexed from,address indexed to);

    /**
     * @dev Constructor that gives msg.sender all of existing tokens.
     */
    constructor () public ERC20Detailed("CrossTestToken", "CTT", DECIMALS) {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    struct channel {
        uint256 volume;
        uint256 expiration;
        uint256 chargeback;
        uint256 amount;
        uint256 nonce;
        uint block;

    }

    mapping (address => uint256) private _locked;
    mapping (address =>
        mapping (address => channel)
    ) private _channels;

    function _lock(address owner, uint256 value) internal {
//        require(owner != address(0), "ERC20: lock from the zero address");
        require(value > 0, "ERC20: lock zero amount");
        require(_balances[owner] >= value, "ERC20: lock more then balance");
        _balances[owner] = _balances[owner].sub(value);
        _locked[owner] = _locked[owner].add(value);
        emit ChannelLocked(owner, value);
    }

    function _unlock(address owner, uint256 value) internal {
//        require(owner != address(0), "StateChanne;: lock from the zero address");
//        require(value > 0, "StateChannel: unlock zero amount");
        require(_locked[owner] >= value, "StateChannel: unlock more then locked");
        _locked[owner] = _locked[owner].sub(value);
        _balances[owner] = _balances[owner].add(value);
        emit ChannelUnlocked(owner, value);
    }

    function _unlock_distribute(address owner, uint256 rest, address receiver, uint256 amount ) internal {
        //        require(owner != address(0), "StateChanne;: lock from the zero address");
        //        require(value > 0, "StateChannel: unlock zero amount");
        uint256 value = rest.add(amount);
        require(_locked[owner] >= value, "StateChannel: unlock more then locked");
        _locked[owner] = _locked[owner].sub(value);
        _balances[owner] = _balances[owner].add(rest);
        _balances[receiver] = _balances[receiver].add(amount);

        emit ChannelUnlocked(owner, value);
    }

    /// the sender can extend the expiration at any time
    function extendPaymentChannel(address to, uint256 newExpiration) public {
        require(newExpiration > _channels[msg.sender][to].expiration);
        _channels[msg.sender][to].expiration = newExpiration;
    }

    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    function openChannel(address to, uint256 volume) public {
        _openChannel(msg.sender, to, volume);
    }
    function _openChannel(address from, address to, uint256 volume) internal {
        require(from != address(0), "StateChannel: from the zero address");
        require(to != address(0), "StateChannel: to the zero address");
        require(_channels[from][to].expiration == 0, "StateChannel: channel still open");
        _lock(from, volume);
        if( block.number != _channels[from][to].block) {
            _channels[from][to].block = block.number;
            _channels[from][to].nonce = 0;
        } else {
            _channels[from][to].nonce = _channels[from][to].nonce.add(1);
        }
        _channels[from][to].volume = volume;
        _channels[from][to].expiration = now + STATE_CHANNEL_LOCK_TIME;
        _channels[from][to].chargeback = 0;
        _channels[from][to].amount = 0;
        emit ChannelOpened(from, to, volume);
    }

    function fixChannel(address to) public {
        _fixChannel(msg.sender,to);
    }

    function _fixChannel(address from, address to) internal {
        require(now >= _channels[from][to].expiration, "StateChannel: channel did not expired");
        uint256 volume = _channels[from][to].volume - _channels[from][to].amount + _channels[from][to].chargeback;
        _channels[from][to].expiration = 0;
        _unlock_distribute(from, volume, to, _channels[from][to].amount - _channels[from][to].chargeback);
        emit ChannelFixed(from, to);
    }

    function sendInChannel(address from, address to, uint256 volume, uint8 v, bytes32 r, bytes32 s) public {

        bytes32 hash = prefixed(keccak256(abi.encodePacked(
                    this,
                    from,
                    to,
                    _channels[from][to].block,
                    _channels[from][to].nonce,
                    volume
            )));
        // check that the signature is from the payment sender
        address  a =  ecrecover(hash, v, r, s);
        require( a == from , "StateChannel:: invalid signature");

        _sendInChannel(from, to, volume);
    }

    function _sendInChannel(address from, address to, uint256 volume) internal {
        require(_channels[from][to].amount < volume);
        require(
            (_channels[from][to].volume + _channels[from][to].chargeback) >= volume
        );
        _channels[from][to].amount = volume;
    }

    function chargebackInChannel(address from, address to, uint256 volume , uint8 v, bytes32 r, bytes32 s) public {
        bytes32 hash = prefixed(keccak256(abi.encodePacked(
                this,
                from,
                to,
                _channels[from][to].block,
                _channels[from][to].nonce,
                volume
            )));
        // check that the signature is from the payment sender
        address  a =  ecrecover(hash, v, r, s);
        require( a == to , "StateChannel:: invalid signature");


    _chargebackInChannel(from, to, volume);
    }

    function _chargebackInChannel(address from, address to, uint256 volume) internal {
        require( _channels[from][to].chargeback < volume );
        require(_channels[from][to].amount >= volume );
        _channels[from][to].chargeback = volume;
    }

    /**
     * @dev Gets the balance of locked for the specified address.
     * @param owner The address to query the locked balance of.
     * @return A uint256 representing the amount locked by the passed address.
     */
    function lockedOf(address owner) public view returns (uint256) {
        return _locked[owner];
    }

    function getStateChannelBlock(address from, address to) public view returns (uint) {
        return _channels[from][to].block;
    }

    function getStateChannelNonce(address from, address to) public view returns (uint256) {
        return _channels[from][to].nonce;
    }










    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowed;

    uint256 private _totalSupply;

    /**
     * @dev Total number of tokens in existence
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Gets the balance of the specified address.
     * @param owner The address to query the balance of.
     * @return A uint256 representing the amount owned by the passed address.
     */
    function balanceOf(address owner) public view returns (uint256) {
        return _balances[owner];
    }

    /**
     * @dev Function to check the amount of tokens that an owner allowed to a spender.
     * @param owner address The address which owns the funds.
     * @param spender address The address which will spend the funds.
     * @return A uint256 specifying the amount of tokens still available for the spender.
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowed[owner][spender];
    }

    /**
     * @dev Transfer token to a specified address
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     */
    function transfer(address to, uint256 value) public returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
     * Beware that changing an allowance with this method brings the risk that someone may use both the old
     * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
     * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     */
    function approve(address spender, uint256 value) public returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev Transfer tokens from one address to another.
     * Note that while this function emits an Approval event, this is not required as per the specification,
     * and other compliant implementations may not emit the event.
     * @param from address The address which you want to send tokens from
     * @param to address The address which you want to transfer to
     * @param value uint256 the amount of tokens to be transferred
     */
    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        _transfer(from, to, value);
        _approve(from, msg.sender, _allowed[from][msg.sender].sub(value));
        return true;
    }

    /**
     * @dev Increase the amount of tokens that an owner allowed to a spender.
     * approve should be called when _allowed[msg.sender][spender] == 0. To increment
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * Emits an Approval event.
     * @param spender The address which will spend the funds.
     * @param addedValue The amount of tokens to increase the allowance by.
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowed[msg.sender][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Decrease the amount of tokens that an owner allowed to a spender.
     * approve should be called when _allowed[msg.sender][spender] == 0. To decrement
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * Emits an Approval event.
     * @param spender The address which will spend the funds.
     * @param subtractedValue The amount of tokens to decrease the allowance by.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowed[msg.sender][spender].sub(subtractedValue));
        return true;
    }

    /**
     * @dev Transfer token for a specified addresses
     * @param from The address to transfer from.
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     */
    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0));

        _balances[from] = _balances[from].sub(value);
        _balances[to] = _balances[to].add(value);
        emit Transfer(from, to, value);
    }

    /**
     * @dev Internal function that mints an amount of the token and assigns it to
     * an account. This encapsulates the modification of balances such that the
     * proper events are emitted.
     * @param account The account that will receive the created tokens.
     * @param value The amount that will be created.
     */
    function _mint(address account, uint256 value) internal {
        require(account != address(0));

        _totalSupply = _totalSupply.add(value);
        _balances[account] = _balances[account].add(value);
        emit Transfer(address(0), account, value);
    }

    /**
     * @dev Internal function that burns an amount of the token of a given
     * account.
     * @param account The account whose tokens will be burnt.
     * @param value The amount that will be burnt.
     */
    function _burn(address account, uint256 value) internal {
        require(account != address(0));

        _totalSupply = _totalSupply.sub(value);
        _balances[account] = _balances[account].sub(value);
        emit Transfer(account, address(0), value);
    }

    /**
     * @dev Approve an address to spend another addresses' tokens.
     * @param owner The address that owns the tokens.
     * @param spender The address that will spend the tokens.
     * @param value The number of tokens that can be spent.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        require(spender != address(0));
        require(owner != address(0));

        _allowed[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @dev Internal function that burns an amount of the token of a given
     * account, deducting from the sender's allowance for said account. Uses the
     * internal burn function.
     * Emits an Approval event (reflecting the reduced allowance).
     * @param account The account whose tokens will be burnt.
     * @param value The amount that will be burnt.
     */
    function _burnFrom(address account, uint256 value) internal {
        _burn(account, value);
        _approve(account, msg.sender, _allowed[account][msg.sender].sub(value));
    }
}

