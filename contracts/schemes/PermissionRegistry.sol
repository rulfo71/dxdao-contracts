pragma solidity 0.5.17;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/**
 * @title PermissionRegistry.
 * @dev A registry of smart contracts functions and ERC20 transfers that are allowed to be called between contracts.
 * There owner of teh contract acts as admin and can set and overwrite any permission.
 * The regsitry allows setting "wildcard" permissions for recipients and functions, allowing call a specific 
 * function in any contract from address A, or any function to a specific contract.
 * The smart contracts permissions are stored  using the asset 0x0 and stores the `from` address, `to` address,
 *   `value` uint256 and `fromTime` uint256, if `fromTime` is zero it meants the function is not allowed.
 * The ERC20 transfer permissions are stored using the asset of the ERC20 and stores the `from` address, `to` address,
 *   `value` uint256 and `fromTime` uint256, if `fromTime` is zero it meants the function is not allowed.
 * It supports EIP 1157 minimal proxies, this means that the permissions to proxies has to be set to the
 * implementation address and not the proxy address
 */

contract PermissionRegistry {
  using SafeMath for uint256;
  
  uint256 public timeDelay;
  address public owner;
  address public constant ANY_ADDRESS = address(0x0000000000000000000000000000000000000001);
  bytes4 public constant ANY_SIGNATURE = bytes4(0x00000001);
  bytes4 public constant ERC20_TRANSFER_SIGNATURE = bytes4(keccak256("transfer(address,uint256)"));

  struct Permission {
    uint256 valueAllowed;
    uint256 fromTime;
  }
  
  // asset address => from address => to address => function call signature allowed => Permission
  mapping(address =>
    mapping(address =>
      mapping(address =>
        mapping(bytes4 =>
          Permission
        )
      )
    )
  )public permissions;

  /**
   * @dev Constructor
   * @param _owner The owner of the registry that can set any permissions
   * @param _timeDelay The amount of time taht has to pass after permission addition to allow execution
   */
  constructor(address _owner, uint256 _timeDelay) public {
    require(_owner != address(0), "PermissionRegistry: Invalid owner address");
    require(_timeDelay > 0, "PermissionRegistry: Invalid time delay");
    owner = _owner;
    timeDelay = _timeDelay;
    permissions[address(0)][_owner][address(this)][ANY_SIGNATURE].fromTime = now;
  }
  
  function transferOwnership(address newOwner) public {
    require(msg.sender == owner, "PermissionRegistry: Only callable by owner");
    permissions[address(0)][owner][address(this)][ANY_SIGNATURE].fromTime = 0;
    permissions[address(0)][newOwner][address(this)][ANY_SIGNATURE].fromTime = now;
    owner = newOwner;
  }
  
  function setTimeDelay(uint256 newTimeDelay) public {
    require(msg.sender == owner, "PermissionRegistry: Only callable by owner");
    timeDelay = newTimeDelay;
  }
  
  /**
   * @dev Sets the time from which the function can be executed from a contract to another a with wich value.
   * This function is meant to be used by the owner of the contract to set and overwrite any permission
   * The form address used in this setPermission function is taken form msg.sender, allowing a direct use of the registry
   * @param asset The asset to be used for the permission address(0) for ETH and other address for ERC20
   * @param from The address that will be called
   * @param to The address that will be called
   * @param functionSignature The signature of the function to be executed
   * @param valueAllowed The amount of value allowed of teh asset to be sent
   * @param allowed If the function is allowed or not.
   */
  function setAdminPermission(
    address asset, 
    address from, 
    address to, 
    bytes4 functionSignature, 
    uint256 valueAllowed, 
    bool allowed
  ) public {
    require(msg.sender == owner, "PermissionRegistry: Only callable by owner");
    require(to != address(this), "PermissionRegistry: Cant change permissions to PermissionRegistry");
    if (asset != address(0))
      functionSignature = ANY_SIGNATURE;
    if (allowed){
      permissions[asset][from][to][functionSignature].fromTime = now.add(timeDelay);
      permissions[asset][from][to][functionSignature].valueAllowed = valueAllowed;
    } else {
      permissions[asset][from][to][functionSignature].fromTime = 0;
      permissions[asset][from][to][functionSignature].valueAllowed = 0;
    }
  }
  
  /**
   * @dev Sets the time from which the function can be executed from a contract to another a with wich value.
   * In case of setting the function top not allowed it sets to zero both values
   * The form address used in this setPermission function is taken form msg.sender, allowing a direct use of the registry
   * @param asset The asset to be used for the permission address(0) for ETH and other address for ERC20
   * @param to The address that will be called
   * @param functionSignature The signature of the function to be executed
   * @param valueAllowed The amount of value allowed of teh asset to be sent
   * @param allowed If the function is allowed or not.
   */
  function setPermission(
    address asset, 
    address to, 
    bytes4 functionSignature, 
    uint256 valueAllowed, 
    bool allowed
  ) public {
    require(to == address(this) && msg.sender == owner, "PermissionRegistry: Cant change permissions to PermissionRegistry");
    if (asset != address(0))
      functionSignature = ANY_SIGNATURE;
    if (allowed){
      permissions[asset][msg.sender][to][functionSignature].fromTime = now.add(timeDelay);
      permissions[asset][msg.sender][to][functionSignature].valueAllowed = valueAllowed;
    } else {
      permissions[asset][msg.sender][to][functionSignature].fromTime = 0;
      permissions[asset][msg.sender][to][functionSignature].valueAllowed = 0;
    }
  }
  
  /**
   * @dev Gets the time from which the function can be executed from a contract to another a with wich value.
   * In case of now being allowed to do the call it returns zero in both values
   * @param asset The asset to be used for the permission address(0) for ETH and other address for ERC20
   * @param from The address from wich the call will be executed
   * @param to The address that will be called
   * @param functionSignature The signature of the function to be executed
   */
  function getPermission(
    address asset,
    address from, 
    address to, 
    bytes4 functionSignature
  ) public returns (uint256 valueAllowed, uint256 fromTime) {
    
    // If the asset is an ERC20 token check the value al;lowed to be transfered
    if (asset != address(0)) {

      if (permissions[asset][from][ANY_ADDRESS][ANY_SIGNATURE].fromTime > 0) {
        Permission memory permission = permissions[asset][from][ANY_ADDRESS][ANY_SIGNATURE];
        return (permission.valueAllowed, permission.fromTime);
      } else if (permissions[asset][from][to][ANY_SIGNATURE].fromTime > 0) {
        Permission memory permission = permissions[asset][from][to][ANY_SIGNATURE];
        return (permission.valueAllowed, permission.fromTime);
      }
    
    // If the asset is ETH check if there is an allowance to any address and function signature
    } else {
      if (permissions[asset][from][ANY_ADDRESS][ANY_SIGNATURE].fromTime > 0) {
        Permission memory permission = permissions[asset][from][ANY_ADDRESS][ANY_SIGNATURE];
        return (permission.valueAllowed, permission.fromTime);
        
      // Check if there is an allowance to any address with a specific function signature
      } else if ((permissions[asset][from][ANY_ADDRESS][functionSignature].fromTime > 0)) {
        Permission memory permission = permissions[asset][from][ANY_ADDRESS][functionSignature];
        return (permission.valueAllowed, permission.fromTime);        
        
      // Check if there is an allowance to specific address with a specific function signature
      } else {
        // bytes4(keccak256("implementation()")) == 0x5c60da1b
        (bool proxyImplementationCallSuccess, bytes memory proxyImplementationCallData) =
          address(to).staticcall(hex"5c60da1b");
        
        // If the receiver is a proxy contract check the permission against the proxy address
        if (proxyImplementationCallSuccess){
          to = abi.decode(proxyImplementationCallData, (address));
        }
        
        // Check is there an allowance to any function in the to address
        if ((permissions[asset][from][to][ANY_SIGNATURE].fromTime > 0)) {
          Permission memory permission = permissions[asset][from][to][ANY_SIGNATURE];
          return (permission.valueAllowed, permission.fromTime);
          
        // The last option is to return the allowance to a specific addres using  a specific signature
        } else {
          Permission memory permission = permissions[asset][from][to][functionSignature];
          return (permission.valueAllowed, permission.fromTime);
        }
      }
    }
  }

}
