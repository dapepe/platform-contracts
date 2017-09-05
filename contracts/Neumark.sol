pragma solidity 0.4.15;

import './AccessControl/AccessControlled.sol';
import './AccessRoles.sol';
import './Agreement.sol';
import './SnapshotToken/SnapshotToken.sol';
import './NeumarkIssuanceCurve.sol';
import './Reclaimable.sol';


contract Neumark is
    AccessControlled,
    AccessRoles,
    Agreement,
    SnapshotToken,
    NeumarkIssuanceCurve,
    Reclaimable
{

    ////////////////////////
    // Constants
    ////////////////////////

    string private constant TOKEN_NAME = "Neumark";

    uint8  private constant TOKEN_DECIMALS = 18;

    string private constant TOKEN_SYMBOL = "NMK";

    ////////////////////////
    // Mutable state
    ////////////////////////

    bool public transferEnabled;

    uint256 public totalEuroUlps;

    ////////////////////////
    // Events
    ////////////////////////

    event NeumarksIssued(
        address indexed owner,
        uint256 euroUlp,
        uint256 neumarkUlp
    );

    event NeumarksBurned(
        address indexed owner,
        uint256 euroUlp,
        uint256 neumarkUlp
    );

    ////////////////////////
    // Constructor
    ////////////////////////

    function Neumark(
        IAccessPolicy accessPolicy,
        IEthereumForkArbiter forkArbiter,
        string agreementUrl
    )
        AccessControlled(accessPolicy)
        AccessRoles()
        Agreement(forkArbiter, agreementUrl)
        SnapshotToken(
            TOKEN_NAME,
            TOKEN_DECIMALS,
            TOKEN_SYMBOL
        )
        NeumarkIssuanceCurve()
        Reclaimable()
    {
        transferEnabled = false;
        totalEuroUlps = 0;
    }

    ////////////////////////
    // Public functions
    ////////////////////////

    function issueForEuro(uint256 euroUlps)
        public
        only(ROLE_NEUMARK_ISSUER)
        acceptAgreement(msg.sender)
        returns (uint256)
    {
        require(totalEuroUlps + euroUlps >= totalEuroUlps);
        address beneficiary = msg.sender;
        uint256 neumarkUlps = incremental(totalEuroUlps, euroUlps);

        totalEuroUlps = totalEuroUlps + euroUlps;

        assert(mGenerateTokens(beneficiary, neumarkUlps));

        NeumarksIssued(beneficiary, euroUlps, neumarkUlps);
        return neumarkUlps;
    }

    function burnNeumark(uint256 neumarkUlps)
        public
        only(ROLE_NEUMARK_BURNER)
        acceptAgreement(msg.sender)
        returns (uint256)
    {
        address owner = msg.sender;
        uint256 euroUlps = incrementalInverse(totalEuroUlps, neumarkUlps);

        totalEuroUlps -= euroUlps;

        assert(mDestroyTokens(owner, neumarkUlps));

        NeumarksBurned(owner, euroUlps, neumarkUlps);
        return euroUlps;
    }

    function enableTransfer(bool enabled)
        public
        only(ROLE_TRANSFER_ADMIN)
    {
        transferEnabled = enabled;
    }

    function createSnapshot()
        public
        only(ROLE_SNAPSHOT_CREATOR)
        returns (uint256)
    {
        return DailyAndSnapshotable.createSnapshot();
    }

    ////////////////////////
    // Internal functions
    ////////////////////////

    //
    // Implements MTokenController
    //

    /// @notice Notifies the controller about a token transfer allowing the
    ///  controller to react if desired
    /// @param from The origin of the transfer
    /// @param to The destination of the transfer
    /// @param amount The amount of the transfer
    /// @return False if the controller does not authorize the transfer
    function mOnTransfer(
        address from,
        address to,
        uint amount
    )
        internal
        acceptAgreement(from)
        acceptAgreement(to)
        returns (bool allow)
    {
        return transferEnabled;
    }

    /// @notice Notifies the controller about an approval allowing the
    ///  controller to react if desired
    /// @param owner The address that calls `approve()`
    /// @param spender The spender in the `approve()` call
    /// @param amount The amount in the `approve()` call
    /// @return False if the controller does not authorize the approval
    function mOnApprove(
        address owner,
        address spender,
        uint amount
    )
        internal
        acceptAgreement(owner)
        returns (bool allow)
    {
        return true;
    }
}
