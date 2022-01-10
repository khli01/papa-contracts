// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.7.5;

library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }
}

interface IERC20 {
    function decimals() external view returns(uint8);
    function balanceOf(address owner) external view returns(uint);
}

interface IPair is IERC20{
    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IPapaCirculation{
    function PAPACirculatingSupply() external view returns ( uint );
}
interface IBackingCalculator{
    //decimals for backing is 4
    function backing() external view returns (uint _lpBacking, uint _treasuryBacking);

    //decimals for backing is 4
    function lpBacking() external view returns(uint _lpBacking);

    //decimals for backing is 4
    function treasuryBacking() external view returns(uint _treasuryBacking);

    //decimals for backing is 4
    function backing_full() external view returns (
        uint _lpBacking, 
        uint _treasuryBacking,
        uint _totalStableReserve,
        uint _totalPapaReserve,
        uint _totalStableBal,
        uint _cirulatingPapa
    );
}
contract BackingCalculator is IBackingCalculator{
    using SafeMath for uint;
    IPair public mimlp=IPair(0xA03a99CD3d553fE9EbBcCecAbcB8c47100482F72);
    IERC20 public mim=IERC20(0x130966628846BFd36ff31a822705796e8cb8C18D);
    IERC20 public usdt=IERC20(0xc7198437980c041c805A1EDcbA50c1Ce5db95118);
    address public PAPA=0x70b33ebC5544C12691d055b49762D0F8365d99Fe;
    address public treasury=0x3C8e800B9f12771A5f150D0943De968ABc7A7bE1;
    IPapaCirculation public papaCirculation=IPapaCirculation(0x82b292C05D51D00eA0Ace831E4b62bEDCb71353A);

    function backing() external view override returns (uint _lpBacking, uint _treasuryBacking){
        (_lpBacking,_treasuryBacking,,,,)=backing_full();
    }

    function lpBacking() external view override returns(uint _lpBacking){
        (_lpBacking,,,,,)=backing_full();
    }

    function treasuryBacking() external view override returns(uint _treasuryBacking){
        (,_treasuryBacking,,,,)=backing_full();
    }

    //decimals for backing is 4
    function backing_full() public view override returns (
        uint _lpBacking, 
        uint _treasuryBacking,
        uint _totalStableReserve,
        uint _totalPapaReserve,
        uint _totalStableBal,
        uint _cirulatingPapa
    ){
        // lp
        uint stableReserve;
        uint papaReserve;
        //mimlp
        (papaReserve,stableReserve)=papaStableAmount(mimlp);
        _totalStableReserve=_totalStableReserve.add(stableReserve);
        _totalPapaReserve=_totalPapaReserve.add(papaReserve);
        _lpBacking=_totalStableReserve.div(_totalPapaReserve).div(1e5);
        //treasury
        _totalStableBal=_totalStableBal.add(toE18(mim.balanceOf(treasury),mim.decimals()));
        _totalStableBal=_totalStableBal.add(toE18(usdt.balanceOf(treasury),usdt.decimals()));
        _cirulatingPapa=papaCirculation.PAPACirculatingSupply().sub(_totalPapaReserve);
        _treasuryBacking=_totalStableBal.div(_cirulatingPapa).div(1e5);
    }
    function papaStableAmount( IPair _pair ) public view returns ( uint papaReserve,uint stableReserve){
        ( uint reserve0, uint reserve1, ) =  _pair .getReserves();
        uint8 stableDecimals;
        if ( _pair.token0() == PAPA ) {
            papaReserve=reserve0;
            stableReserve=reserve1;
            stableDecimals=IERC20(_pair.token1()).decimals();
        } else {
            papaReserve=reserve1;
            stableReserve=reserve0;
            stableDecimals=IERC20(_pair.token0()).decimals();
        }
        stableReserve=toE18(stableReserve,stableDecimals);
    }
    
    function toE18(uint amount, uint8 decimals) public pure returns (uint){
        if(decimals==18)return amount;
        else if(decimals>18) return amount.div(10**(decimals-18));
        else return amount.mul(10**(18-decimals));
    }
}