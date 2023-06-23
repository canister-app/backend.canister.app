import Text "mo:base/Text";
import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Blob "mo:base/Blob";
import Nat64 "mo:base/Nat64";
import AccountId "mo:accountid/AccountId";

module {
    public type SubAccount = Blob;
    public type Memo = Blob;
    public type Account = { address: Text};
    // Arguments for the `transfer` call.

    //Transfer Token - DIP20
    public type TxReceipt = {
        #Ok : Nat;
        #Err : {
            #InsufficientAllowance;
            #InsufficientBalance;
            #ErrorOperationStyle;
            #Unauthorized;
            #LedgerTrap;
            #ErrorTo;
            #Other : Text;
            #BlockUsed;
            #AmountTooSmall;
        };
    };
    public type Token = actor{
        transfer : shared (Principal, Nat) -> async TxReceipt;
        transferFrom : shared (Principal, Principal, Nat) -> async TxReceipt;
        balanceOf : shared query Principal -> async Nat;
    };
     public type IcpXdrConversionRate = {
        xdr_permyriad_per_icp : Nat64;
        timestamp_seconds : Nat64;
    };
    public type IcpXdrConversionRateCertifiedResponse = {
        certificate : [Nat8];
        data : IcpXdrConversionRate;
        hash_tree : [Nat8];
    };
    public type CycleRate = actor{
        get_icp_xdr_conversion_rate : shared query () -> async IcpXdrConversionRateCertifiedResponse; 
    };

}